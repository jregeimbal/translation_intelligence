import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import 'controllers/speech_controller.dart';
import 'controllers/two_way_chat_controller.dart';
import 'firebase_options.dart';
import 'models/provider_settings_selection.dart';
import 'models/playback_device.dart';
import 'models/suggested_response.dart';
import 'models/two_way_message.dart';
import 'services/backend_api_client.dart';
import 'services/app_preferences.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_ext.dart';
import 'services/deepgram_recognition_catalog.dart';
import 'services/firebase_auth_session.dart';
import 'services/runtime_config.dart';
import 'services/speech_to_text_service.dart';
import 'services/speech_output_provider.dart';
import 'services/speech_stt_provider.dart';
import 'services/speech_translation_provider.dart';
import 'theme/app_theme_resolver.dart';
import 'theme/hyper_linguist_theme.dart';
import 'theme/hyper_listen_theme.dart';
import 'widgets/chat_message.dart';
import 'widgets/first_launch_walkthrough_dialog.dart';
import 'widgets/footer.dart';
import 'widgets/group_language_bar.dart';
import 'widgets/provider_settings_dialog.dart';
import 'widgets/speech_connection_debug_dialog.dart';
import 'widgets/two_way_chat.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level =
      Level.FINER; // This will only show WARNING and SEVERE logs
  Logger.root.onRecord.listen((record) {
    // Use developer.log to send logs to the debug console
    //if (kDebugMode) {
    // Apply colorization (optional, see below)
    final message = '${record.time}: ${record.level.name}: ${record.message}';
    // Use developer.log to ensure it appears in the VS Code console
    developer.log(
      message,
      name: record.loggerName.padRight(25),
      level: record.level.value,
      time: record.time,
    );
    //}
  });

  final apiBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  final noDotenvOverride = bool.tryParse(
    const String.fromEnvironment('NO_DOTENV_OVERRIDE', defaultValue: 'false'),
  );

  Logger('Main').finest(
    'Loaded runtime configuration: API_BASE_URL=${apiBaseUrl.isEmpty ? '(not set)' : apiBaseUrl}',
  );

  await dotenv.load(
    mergeWith: {if (apiBaseUrl.isNotEmpty) "API_BASE_URL": apiBaseUrl},
    overrideWithFiles: [if (noDotenvOverride == false) '.env'],
  );
  if (noDotenvOverride == true) {
    Logger('Main').info(
      'RuntimeConfig: Skipping .env file merge in ${kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug'} mode.',
    );
  } else {
    Logger(
      'Main',
    ).info('RuntimeConfig: Merging .env file for configuration values.');
  }
  dotenv.env.forEach((key, value) {
    Logger('Main').info('RuntimeConfig: $key=$value');
  });

  runApp(MyApp());
}

typedef HomePageInitializer = Future<HomePageInitializationBundle> Function();

class HomePageInitializationBundle {
  const HomePageInitializationBundle({
    required this.backendApiClient,
    required this.controller,
    required this.twoWayController,
  });

  final BackendApiClient backendApiClient;
  final SpeechController controller;
  final TwoWayChatController twoWayController;

  void dispose() {
    controller.dispose();
    twoWayController.dispose();
    backendApiClient.close();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final String _configuredTheme;

  @override
  void initState() {
    super.initState();
    _configuredTheme = dotenv.get('APP_THEME', fallback: 'HyperListenTheme');
  }

  bool get _useHyperLinguistTheme {
    final normalized = _configuredTheme.trim().toLowerCase();
    return normalized == 'hyperlinguisttheme' || normalized == 'hyperlinguist';
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedLightTheme = _useHyperLinguistTheme
        ? HyperLinguistTheme.light()
        : HyperListenTheme.light();
    final selectedDarkTheme = _useHyperLinguistTheme
        ? HyperLinguistTheme.dark()
        : HyperListenTheme.dark();

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: selectedLightTheme,
      darkTheme: selectedDarkTheme,
      themeMode: _themeMode,
      localizationsDelegates: const [
        LocaleNamesLocalizationsDelegate(),
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyHomePage(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final HomePageInitializer? initializer;

  const MyHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.initializer,
  });

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class DebouncedMessageDispatcher {
  DebouncedMessageDispatcher({required this.delay, required this.onDispatch});

  final Duration delay;
  final void Function(String message) onDispatch;

  Timer? _timer;
  String? _pendingMessage;

  void schedule(String message) {
    _pendingMessage = message;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final pending = _pendingMessage;
      if (pending == null || pending.isEmpty) return;
      _pendingMessage = null;
      onDispatch(pending);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final AppPreferences _appPreferences = AppPreferences();
  late SpeechController _controller;
  late TwoWayChatController _twoWayController;
  late BackendApiClient _backendApiClient;
  StreamSubscription<String>? _listeningDeviceUpdateSub;
  StreamSubscription<SuggestedResponseEvent>? _suggestedResponseSub;
  late final DebouncedMessageDispatcher _listeningDeviceSnackBarDebouncer;
  bool _initializing = true;
  bool _controllersReady = false;
  bool _backendClientReady = false;
  String _initializationError = '';
  int _selectedSection = 0;
  SpeechOutputProvider _outputProvider = SpeechOutputProvider.google;
  SpeechSttProvider _sttProvider = SpeechSttProvider.deepgram;
  SpeechTranslationProvider _translationProvider =
      SpeechTranslationProvider.google;
  String _deepgramRecognitionModel =
      DeepgramRecognitionCatalog.defaultRecognitionModel;
  String _deepgramRecognitionLanguage =
      DeepgramRecognitionCatalog.defaultRecognitionLanguage;
  String _speechToTextRecognitionLocale =
      SpeechToTextService.defaultRecognitionLanguage;
  String _targetLanguage = 'en';
  Map<String, String> _speechToTextRecognitionLocales = const {
    'Multi (Auto)': SpeechToTextService.defaultRecognitionLanguage,
  };
  List<InputDevice> _listeningDevices = const [];
  List<PlaybackDevice> _playbackDevices = const [];
  String? _listeningDeviceId;
  String? _playbackDeviceId;
  AppPreferencesSnapshot? _lastPersistedPreferences;
  bool _hasCompletedFirstLaunchWalkthrough = false;
  bool _walkthroughShownThisSession = false;

  bool get _isGroupSection => _selectedSection == 0;

  void _disposeInitializedResources() {
    if (_controllersReady) {
      _controller.removeListener(_persistControllerPreferences);
    }
    _listeningDeviceUpdateSub?.cancel();
    _listeningDeviceUpdateSub = null;
    _suggestedResponseSub?.cancel();
    _suggestedResponseSub = null;
    if (_controllersReady) {
      _controller.dispose();
      _twoWayController.dispose();
      _controllersReady = false;
    }
    if (_backendClientReady) {
      _backendApiClient.close();
      _backendClientReady = false;
    }
  }

  Future<void> _loadPersistedPreferences() async {
    final snapshot = await _appPreferences.load();
    final model =
        DeepgramRecognitionCatalog.supportedRecognitionModels.contains(
          snapshot.deepgramRecognitionModel,
        )
        ? snapshot.deepgramRecognitionModel
        : DeepgramRecognitionCatalog.defaultRecognitionModel;
    final sourceLanguage =
        DeepgramRecognitionCatalog.isRecognitionLanguageSupportedForModel(
          model,
          snapshot.deepgramRecognitionLanguage,
        )
        ? snapshot.deepgramRecognitionLanguage
        : DeepgramRecognitionCatalog.defaultRecognitionLanguageForModel(model);
    final targetLanguage =
        SpeechController.supportedLanguages.contains(snapshot.targetLanguage)
        ? snapshot.targetLanguage
        : 'en';

    _deepgramRecognitionModel = model;
    _deepgramRecognitionLanguage = sourceLanguage;
    _speechToTextRecognitionLocale = snapshot.speechToTextRecognitionLocale;
    _targetLanguage = targetLanguage;
    _lastPersistedPreferences = AppPreferencesSnapshot(
      deepgramRecognitionModel: model,
      deepgramRecognitionLanguage: sourceLanguage,
      speechToTextRecognitionLocale: snapshot.speechToTextRecognitionLocale,
      targetLanguage: targetLanguage,
      hideTranslatedOriginalText: snapshot.hideTranslatedOriginalText,
      audioPlaybackEnabled: snapshot.audioPlaybackEnabled,
      hasCompletedFirstLaunchWalkthrough:
          snapshot.hasCompletedFirstLaunchWalkthrough,
    );
    _hasCompletedFirstLaunchWalkthrough =
        snapshot.hasCompletedFirstLaunchWalkthrough;
  }

  void _persistControllerPreferences() {
    if (!_controllersReady) return;

    final snapshot = AppPreferencesSnapshot(
      deepgramRecognitionModel: _controller.deepgramRecognitionModel,
      deepgramRecognitionLanguage: _controller.deepgramRecognitionLanguage,
      speechToTextRecognitionLocale: _controller.speechToTextRecognitionLocale,
      targetLanguage: _controller.targetLanguage,
      hideTranslatedOriginalText: _controller.hideTranslatedOriginalText,
      audioPlaybackEnabled: _controller.audioPlaybackEnabled,
      hasCompletedFirstLaunchWalkthrough: _hasCompletedFirstLaunchWalkthrough,
    );

    final previous = _lastPersistedPreferences;
    _lastPersistedPreferences = snapshot;

    if (previous != null &&
        previous.deepgramRecognitionModel ==
            snapshot.deepgramRecognitionModel &&
        previous.deepgramRecognitionLanguage ==
            snapshot.deepgramRecognitionLanguage &&
        previous.speechToTextRecognitionLocale ==
            snapshot.speechToTextRecognitionLocale &&
        previous.targetLanguage == snapshot.targetLanguage &&
        previous.hideTranslatedOriginalText ==
            snapshot.hideTranslatedOriginalText &&
        previous.audioPlaybackEnabled == snapshot.audioPlaybackEnabled) {
      return;
    }

    unawaited(
      _appPreferences.setDeepgramRecognitionModel(
        snapshot.deepgramRecognitionModel,
      ),
    );
    unawaited(
      _appPreferences.setDeepgramRecognitionLanguage(
        snapshot.deepgramRecognitionLanguage,
      ),
    );
    unawaited(
      _appPreferences.setSpeechToTextRecognitionLocale(
        snapshot.speechToTextRecognitionLocale,
      ),
    );
    unawaited(_appPreferences.setTargetLanguage(snapshot.targetLanguage));
    unawaited(
      _appPreferences.setHideTranslatedOriginalText(
        snapshot.hideTranslatedOriginalText,
      ),
    );
    unawaited(
      _appPreferences.setAudioPlaybackEnabled(snapshot.audioPlaybackEnabled),
    );
  }

  Future<void> _completeFirstLaunchWalkthrough() async {
    if (_hasCompletedFirstLaunchWalkthrough) return;

    _hasCompletedFirstLaunchWalkthrough = true;
    final previous = _lastPersistedPreferences;
    if (previous != null) {
      _lastPersistedPreferences = AppPreferencesSnapshot(
        deepgramRecognitionModel: previous.deepgramRecognitionModel,
        deepgramRecognitionLanguage: previous.deepgramRecognitionLanguage,
        speechToTextRecognitionLocale: previous.speechToTextRecognitionLocale,
        targetLanguage: previous.targetLanguage,
        hideTranslatedOriginalText: previous.hideTranslatedOriginalText,
        audioPlaybackEnabled: previous.audioPlaybackEnabled,
        hasCompletedFirstLaunchWalkthrough: true,
      );
    }

    await _appPreferences.setHasCompletedFirstLaunchWalkthrough(true);
  }

  Future<void> _showWalkthrough({required bool markCompleted}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const FirstLaunchWalkthroughDialog(),
    );

    if (!mounted || !markCompleted) return;
    await _completeFirstLaunchWalkthrough();
  }

  Future<void> _maybeShowFirstLaunchWalkthrough() async {
    if (!mounted ||
        _initializing ||
        _initializationError.isNotEmpty ||
        _hasCompletedFirstLaunchWalkthrough ||
        _walkthroughShownThisSession) {
      return;
    }

    _walkthroughShownThisSession = true;

    await _showWalkthrough(markCompleted: true);
  }

  Future<void> _showHelpWalkthrough() async {
    if (!mounted || _initializing || _initializationError.isNotEmpty) return;
    await _showWalkthrough(markCompleted: false);
  }

  SpeechSttProvider? get _activeSessionSttProvider => _isGroupSection
      ? _controller.activeSessionSttProvider
      : _twoWayController.activeSessionSttProvider;

  String? get _activeSessionSourceLanguage => _isGroupSection
      ? _controller.activeSessionSourceLanguage
      : _twoWayController.activeSessionSourceLanguage;

  String? get _activeSessionResolvedLanguageCode => _isGroupSection
      ? _controller.activeSessionResolvedLanguageCode
      : _twoWayController.activeSessionResolvedLanguageCode;

  int? get _activeSessionSampleRate => _isGroupSection
      ? _controller.activeSessionSampleRate
      : _twoWayController.activeSessionSampleRate;

  String? get _activeSessionListeningDeviceId => _isGroupSection
      ? _controller.activeSessionListeningDeviceId
      : _twoWayController.activeSessionListeningDeviceId;

  DateTime? get _activeSessionStartedAt => _isGroupSection
      ? _controller.activeSessionStartedAt
      : _twoWayController.activeSessionStartedAt;

  bool get _isActiveListening =>
      _isGroupSection ? _controller.isListening : _twoWayController.isListening;

  double get _activeAmplitude =>
      _isGroupSection ? _controller.amplitude : _twoWayController.amplitude;

  void _showDebugAudioDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.debugAudioStream),
          content: StreamBuilder<int>(
            stream: Stream<int>.periodic(
              const Duration(milliseconds: 250),
              (count) => count,
            ),
            initialData: 0,
            builder: (context, _) {
              final startedAt = _activeSessionStartedAt;
              final elapsed = startedAt == null
                  ? null
                  : DateTime.now().difference(startedAt);
              final elapsedLabel = elapsed == null
                  ? l10n.notAvailableShort
                  : '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

              final rows = <MapEntry<String, String>>[
                MapEntry(
                  l10n.debugSection,
                  _isGroupSection
                      ? l10n.debugSectionGroup
                      : l10n.debugSectionTwoWay,
                ),
                MapEntry(
                  l10n.debugListeningActive,
                  _isActiveListening ? l10n.yes : l10n.no,
                ),
                MapEntry(
                  l10n.debugSttProvider,
                  _activeSessionSttProvider == null
                      ? l10n.notAvailableShort
                      : localizedSttProviderLabel(
                          context,
                          _activeSessionSttProvider!,
                        ),
                ),
                MapEntry(
                  l10n.debugSourceLanguage,
                  _activeSessionSourceLanguage == null
                      ? l10n.notAvailableShort
                      : localizedRecognitionLocaleLabel(
                          context,
                          _activeSessionSourceLanguage!,
                        ),
                ),
                MapEntry(
                  l10n.debugResolvedLanguageCode,
                  _activeSessionResolvedLanguageCode ?? l10n.notAvailableShort,
                ),
                MapEntry(
                  l10n.debugActiveSampleRate,
                  _activeSessionSampleRate == null
                      ? l10n.notAvailableShort
                      : l10n.sampleRateHertz(_activeSessionSampleRate!),
                ),
                MapEntry(
                  l10n.debugListeningDeviceId,
                  _activeSessionListeningDeviceId ?? l10n.autoDefault,
                ),
                MapEntry(
                  l10n.debugAmplitude,
                  _activeAmplitude.toStringAsFixed(3),
                ),
                MapEntry(l10n.debugSessionElapsed, elapsedLabel),
                MapEntry(
                  l10n.debugSessionStartedAt,
                  startedAt?.toIso8601String() ?? l10n.notAvailableShort,
                ),
                MapEntry(
                  l10n.debugConfiguredSttProvider,
                  _isGroupSection
                      ? localizedSttProviderLabel(
                          context,
                          _controller.sttProvider,
                        )
                      : localizedSttProviderLabel(
                          context,
                          _twoWayController.sttProvider,
                        ),
                ),
                MapEntry(
                  l10n.debugConfiguredDeepgramLanguage,
                  _isGroupSection
                      ? localizedDeepgramLanguageLabel(
                          context,
                          _controller.deepgramRecognitionLanguage,
                        )
                      : localizedDeepgramLanguageLabel(
                          context,
                          _twoWayController.deepgramRecognitionLanguage,
                        ),
                ),
                MapEntry(
                  l10n.debugConfiguredGoogleLocale,
                  _isGroupSection
                      ? localizedRecognitionLocaleLabel(
                          context,
                          _controller.speechToTextRecognitionLocale,
                        )
                      : localizedRecognitionLocaleLabel(
                          context,
                          _twoWayController.speechToTextRecognitionLocale,
                        ),
                ),
                MapEntry(
                  l10n.debugConfiguredSttLocale,
                  _isGroupSection
                      ? localizedRecognitionLocaleLabel(
                          context,
                          _controller.speechToTextRecognitionLocale,
                        )
                      : localizedRecognitionLocaleLabel(
                          context,
                          _twoWayController.speechToTextRecognitionLocale,
                        ),
                ),
              ];

              return SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final row in rows) ...[
                        Text('${row.key}: ${row.value}'),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  void _showDebouncedListeningDeviceSnackBar(String message) {
    _listeningDeviceSnackBarDebouncer.schedule(
      localizedListeningDeviceUpdate(context, message),
    );
  }

  void _bindListeningDeviceNotifications() {
    _listeningDeviceUpdateSub?.cancel();
    _listeningDeviceUpdateSub = _controller.listeningDeviceUpdates.listen((
      message,
    ) {
      if (!mounted || _initializing) return;
      _showDebouncedListeningDeviceSnackBar(message);
    });
  }

  void _bindSuggestedResponseNotifications() {
    _suggestedResponseSub?.cancel();
    _suggestedResponseSub = _controller.suggestedResponses.listen((event) {
      if (!mounted || _initializing || !_isGroupSection) {
        return;
      }
      _showSuggestedResponseSnackBar(event);
    });
  }

  void _showSuggestedResponseSnackBar(SuggestedResponseEvent event) {
    final sourceLanguageLabel = localizedAppLanguageName(
      context,
      event.response.sourceLanguageCode,
    );
    final targetLanguageLabel = localizedAppLanguageName(
      context,
      event.response.targetLanguageCode,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          content: _SuggestedResponseSnackBarContent(
            title: context.l10n.suggestedResponseTitle,
            closeTooltip: context.l10n.close,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            originalLabel: context.l10n.suggestedResponseOriginalLabel(
              sourceLanguageLabel,
            ),
            translatedLabel: context.l10n.suggestedResponseTranslatedLabel(
              targetLanguageLabel,
            ),
            originalText: event.response.originalText,
            translatedText: event.response.translatedText,
          ),
        ),
      );
  }

  Future<void> _startGroupListeningWithDebugDialog() async {
    try {
      await _controller.startListening();
    } catch (error) {
      if (!mounted) return;
      final handled = await SpeechConnectionDebugDialog.showIfAvailable(
        context,
        error,
      );
      if (!handled) {
        rethrow;
      }
    }
  }

  Future<void> _startTwoWayListeningWithDebugDialog(
    TwoWaySpeaker speaker,
  ) async {
    try {
      await _twoWayController.startListening(speaker);
    } catch (error) {
      if (!mounted) return;
      final handled = await SpeechConnectionDebugDialog.showIfAvailable(
        context,
        error,
      );
      if (!handled) {
        rethrow;
      }
    }
  }

  Future<HomePageInitializationBundle> _createInitializationBundle() async {
    final runtimeConfig = RuntimeConfig.fromDotEnv(dotenv);
    final authSession = FirebaseAuthSession(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await authSession.initialize();
    final backendApiClient = BackendApiClient(
      baseUrl: runtimeConfig.apiBaseUrl,
      authTokenProvider: authSession.getIdToken,
    );

    final controller = SpeechController(backendApiClient: backendApiClient);
    controller.setSttProvider(_sttProvider);
    controller.setTranslationProvider(_translationProvider);
    controller.setDeepgramRecognitionModel(_deepgramRecognitionModel);
    controller.setDeepgramRecognitionLanguage(_deepgramRecognitionLanguage);
    controller.setSpeechToTextRecognitionLocale(_speechToTextRecognitionLocale);
    controller.setTargetLanguage(_targetLanguage);
    if (_lastPersistedPreferences != null) {
      controller.setHideTranslatedOriginalText(
        _lastPersistedPreferences!.hideTranslatedOriginalText,
      );
      controller.setAudioPlaybackEnabled(
        _lastPersistedPreferences!.audioPlaybackEnabled,
      );
    }

    final twoWayController = TwoWayChatController(
      backendApiClient: backendApiClient,
    );
    twoWayController.setSttProvider(_sttProvider);
    twoWayController.setTranslationProvider(_translationProvider);
    twoWayController.setDeepgramRecognitionModel(_deepgramRecognitionModel);
    twoWayController.setDeepgramRecognitionLanguage(
      _deepgramRecognitionLanguage,
    );
    twoWayController.setSpeechToTextRecognitionLocale(
      _speechToTextRecognitionLocale,
    );

    await controller.init();
    await twoWayController.init();

    return HomePageInitializationBundle(
      backendApiClient: backendApiClient,
      controller: controller,
      twoWayController: twoWayController,
    );
  }

  Future<void> _initializeControllers() async {
    _disposeInitializedResources();

    setState(() {
      _initializing = true;
      _initializationError = '';
    });

    HomePageInitializationBundle? bundle;

    try {
      await _loadPersistedPreferences();
      bundle = await (widget.initializer ?? _createInitializationBundle)();
    } catch (error) {
      bundle?.dispose();
      if (!mounted) return;
      setState(() {
        _initializationError = '$error';
        _initializing = false;
      });
      return;
    }

    if (!mounted) {
      bundle.dispose();
      return;
    }

    _backendApiClient = bundle.backendApiClient;
    _controller = bundle.controller;
    _twoWayController = bundle.twoWayController;
    _controller.addListener(_persistControllerPreferences);
    _backendClientReady = true;
    _controllersReady = true;
    _bindListeningDeviceNotifications();
    _bindSuggestedResponseNotifications();
    setState(() {
      _listeningDevices = _controller.listeningDevices;
      _listeningDeviceId = _controller.listeningDeviceId;
      _playbackDevices = _controller.playbackDevices;
      _playbackDeviceId = _controller.playbackDeviceId;
      _speechToTextRecognitionLocales =
          _controller.speechToTextRecognitionLocales;
      _speechToTextRecognitionLocale =
          _controller.speechToTextRecognitionLocale;
      _targetLanguage = _controller.targetLanguage;
      _initializing = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowFirstLaunchWalkthrough());
    });
  }

  void _setOutputProvider(SpeechOutputProvider provider) {
    if (_outputProvider == provider || _initializing) return;
    setState(() {
      _outputProvider = provider;
      _controller.setOutputProvider(provider);
      _twoWayController.setOutputProvider(provider);
    });
  }

  Future<void> _setSttProvider(SpeechSttProvider provider) async {
    if (_sttProvider == provider || _initializing) return;

    if (_controller.isListening) {
      await _controller.stopListening();
    }
    if (_twoWayController.isListening) {
      await _twoWayController.stopListening();
    }

    if (!mounted) return;
    setState(() {
      _sttProvider = provider;
      _controller.setSttProvider(provider);
      _twoWayController.setSttProvider(provider);
    });
  }

  void _setTranslationProvider(SpeechTranslationProvider provider) {
    if (_translationProvider == provider || _initializing) return;
    setState(() {
      _translationProvider = provider;
      _controller.setTranslationProvider(provider);
      _twoWayController.setTranslationProvider(provider);
    });
  }

  void _setDeepgramRecognitionModel(String model) {
    if (_deepgramRecognitionModel == model || _initializing) return;
    setState(() {
      _deepgramRecognitionModel = model;
      _controller.setDeepgramRecognitionModel(model);
      _twoWayController.setDeepgramRecognitionModel(model);
    });
  }

  Future<void> _setDeepgramRecognitionLanguage(String language) async {
    if (_deepgramRecognitionLanguage == language || _initializing) return;

    final restartListening = _controller.isListening;
    if (restartListening) {
      await _controller.stopListening();
    }
    if (!mounted) return;

    setState(() {
      _deepgramRecognitionLanguage = language;
      _controller.setDeepgramRecognitionLanguage(language);
      _twoWayController.setDeepgramRecognitionLanguage(language);
    });

    if (restartListening) {
      await _startGroupListeningWithDebugDialog();
    }
  }

  Future<void> _setSpeechToTextRecognitionLocale(String locale) async {
    if (_speechToTextRecognitionLocale == locale || _initializing) return;

    final restartListening = _controller.isListening;
    if (restartListening) {
      await _controller.stopListening();
    }
    if (!mounted) return;

    setState(() {
      _speechToTextRecognitionLocale = locale;
      _controller.setSpeechToTextRecognitionLocale(locale);
      _twoWayController.setSpeechToTextRecognitionLocale(locale);
    });

    if (restartListening) {
      await _startGroupListeningWithDebugDialog();
    }
  }

  void _setListeningDeviceId(String? deviceId) {
    if (_listeningDeviceId == deviceId || _initializing) return;
    setState(() {
      _listeningDeviceId = deviceId;
      _controller.setListeningDeviceId(deviceId);
      _twoWayController.setListeningDeviceId(deviceId);
    });
  }

  Future<void> _setPlaybackDeviceId(String? deviceId) async {
    if (_playbackDeviceId == deviceId || _initializing) return;

    final applied = await _controller.setPlaybackDeviceId(deviceId);
    await _twoWayController.setPlaybackDeviceId(deviceId);

    if (!mounted) return;
    setState(() {
      _playbackDevices = _controller.playbackDevices;
      _playbackDeviceId = _controller.playbackDeviceId;
    });

    if (!applied && deviceId != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.unableToSwitchPlaybackDevice),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _showProviderSettingsDialog() async {
    if (_initializing) return;

    await _controller.refreshListeningDevices();
    await _controller.refreshPlaybackDevices();
    await _controller.refreshSpeechToTextRecognitionLocales();
    if (!mounted) return;
    setState(() {
      _listeningDevices = _controller.listeningDevices;
      _listeningDeviceId = _controller.listeningDeviceId;
      _playbackDevices = _controller.playbackDevices;
      _playbackDeviceId = _controller.playbackDeviceId;
      _speechToTextRecognitionLocales =
          _controller.speechToTextRecognitionLocales;
      _speechToTextRecognitionLocale =
          _controller.speechToTextRecognitionLocale;
    });

    final selection = await Navigator.of(context)
        .push<ProviderSettingsSelection>(
          MaterialPageRoute<ProviderSettingsSelection>(
            fullscreenDialog: true,
            builder: (context) {
              return ProviderSettingsDialog(
                initialSttProvider: _sttProvider,
                initialTranslationProvider: _translationProvider,
                initialOutputProvider: _outputProvider,
                initialTargetLanguage: _targetLanguage,
                targetLanguages: SpeechController.supportedLanguages,
                initialDeepgramRecognitionModel: _deepgramRecognitionModel,
                initialDeepgramRecognitionLanguage:
                    _deepgramRecognitionLanguage,
                initialSpeechToTextRecognitionLocale:
                    _speechToTextRecognitionLocale,
                initialSpeechToTextRecognitionLocales:
                    _speechToTextRecognitionLocales,
                initialListeningDevices: _listeningDevices,
                initialListeningDeviceId: _listeningDeviceId,
                initialPlaybackDevices: _playbackDevices,
                initialPlaybackDeviceId: _playbackDeviceId,
                initialThemeMode: widget.themeMode,
              );
            },
          ),
        );

    if (selection == null) {
      return;
    }

    final restartGroupListening = _controller.isListening;
    final restartTwoWayListening = _twoWayController.isListening;
    final restartTwoWaySpeaker = _twoWayController.activeSpeaker;

    if (restartGroupListening) {
      await _controller.stopListening();
    }
    if (restartTwoWayListening) {
      await _twoWayController.stopListening();
    }
    if (!mounted) return;

    if (selection.sttProvider != _sttProvider) {
      await _setSttProvider(selection.sttProvider);
    }
    if (!mounted) return;
    if (selection.translationProvider != _translationProvider) {
      _setTranslationProvider(selection.translationProvider);
    }
    if (selection.outputProvider != _outputProvider) {
      _setOutputProvider(selection.outputProvider);
    }
    if (selection.targetLanguage != _targetLanguage) {
      setState(() {
        _targetLanguage = selection.targetLanguage;
        _controller.setTargetLanguage(selection.targetLanguage);
      });
    }
    if (selection.deepgramRecognitionModel != _deepgramRecognitionModel) {
      _setDeepgramRecognitionModel(selection.deepgramRecognitionModel);
    }
    if (selection.deepgramRecognitionLanguage != _deepgramRecognitionLanguage) {
      await _setDeepgramRecognitionLanguage(
        selection.deepgramRecognitionLanguage,
      );
    }
    if (selection.speechToTextRecognitionLocale !=
        _speechToTextRecognitionLocale) {
      await _setSpeechToTextRecognitionLocale(
        selection.speechToTextRecognitionLocale,
      );
    }
    if (selection.listeningDeviceId != _listeningDeviceId) {
      _setListeningDeviceId(selection.listeningDeviceId);
    }
    if (selection.playbackDeviceId != _playbackDeviceId) {
      await _setPlaybackDeviceId(selection.playbackDeviceId);
    }
    if (selection.themeMode != widget.themeMode) {
      widget.onThemeModeChanged(selection.themeMode);
    }

    if (restartGroupListening) {
      await _startGroupListeningWithDebugDialog();
    }
    if (restartTwoWayListening && restartTwoWaySpeaker != null) {
      await _startTwoWayListeningWithDebugDialog(restartTwoWaySpeaker);
    }
  }

  Future<void> _onSectionSelected(int index) async {
    if (_selectedSection == index) return;

    if (_selectedSection == 0 && !_initializing && _controller.isListening) {
      try {
        await _controller.stopListening();
      } catch (_) {}
    }
    if (_selectedSection == 1 &&
        !_initializing &&
        _twoWayController.isListening) {
      try {
        await _twoWayController.stopListening();
      } catch (_) {}
    }
    if (!mounted) return;
    if (index != 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    setState(() {
      _selectedSection = index;
    });
  }

  bool _canSwapGroupLanguages(Map<String, String> sourceLanguages) {
    if (_initializing || !_isGroupSection) return false;

    final source = _controller.deepgramRecognitionLanguage;
    final target = _controller.targetLanguage;

    if (source == 'multi' || target == 'multi') {
      return false;
    }

    final targetLanguages = SpeechController.supportedLanguages.toSet();
    final sourceValues = sourceLanguages.values.toSet();

    final supportsCurrentDirection =
        sourceValues.contains(source) && targetLanguages.contains(target);
    final supportsSwappedDirection =
        sourceValues.contains(target) && targetLanguages.contains(source);

    return supportsCurrentDirection && supportsSwappedDirection;
  }

  Future<void> _swapGroupLanguages(Map<String, String> sourceLanguages) async {
    if (!_canSwapGroupLanguages(sourceLanguages)) return;

    final source = _controller.deepgramRecognitionLanguage;
    final target = _controller.targetLanguage;

    if (source == target) return;

    final restartListening = _controller.isListening;
    if (restartListening) {
      await _controller.stopListening();
    }
    if (!mounted) return;

    setState(() {
      _deepgramRecognitionLanguage = target;
      _targetLanguage = source;
      _controller.setDeepgramRecognitionLanguage(target);
      _twoWayController.setDeepgramRecognitionLanguage(target);
      _controller.setTargetLanguage(source);
    });

    if (restartListening) {
      await _startGroupListeningWithDebugDialog();
    }
  }

  @override
  void initState() {
    super.initState();
    _listeningDeviceSnackBarDebouncer = DebouncedMessageDispatcher(
      delay: const Duration(milliseconds: 700),
      onDispatch: (pendingMessage) {
        if (!mounted || _initializing) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(pendingMessage),
              duration: const Duration(seconds: 2),
            ),
          );
      },
    );
    _initializeControllers();
  }

  @override
  void dispose() {
    _listeningDeviceSnackBarDebouncer.dispose();
    _disposeInitializedResources();
    super.dispose();
  }

  // NOTE: all speech state and operations are handled by the controller.
  // the widget simply passes the controller to its children; each child
  // listens for the properties it cares about.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textRoles = resolveAppThemeTextRoles(theme);
    final tokens = resolveAppThemeTokens(theme);

    if (_initializationError.isNotEmpty) {
      return Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.initializationFailed(_initializationError),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _initializeControllers,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.appGradientTop, tokens.appGradientBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'icon_omnia.png',
                    filterQuality: FilterQuality.high,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.translate_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.appTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    context.l10n.translationAssistant,
                    style: textRoles.appSubtitle,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (!_initializing)
              IconButton(
                icon: const Icon(Icons.help_outline_rounded),
                tooltip: context.l10n.walkthroughHelp,
                onPressed: _showHelpWalkthrough,
              ),
            if (kDebugMode)
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                tooltip: context.l10n.debugAudioStream,
                onPressed: _showDebugAudioDialog,
              ),
            if (!_initializing)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: context.l10n.settingsTitle,
                onPressed: _showProviderSettingsDialog,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isGroupSection
                ? (_initializing
                      ? const Center(
                          key: ValueKey('group_loading'),
                          child: CircularProgressIndicator(),
                        )
                      : ChangeNotifierProvider<SpeechController>.value(
                          value: _controller,
                          child: Padding(
                            key: const ValueKey('group_chat'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 12,
                            ),
                            child: Column(
                              children: [
                                GroupLanguageBar(
                                  sourceLanguages:
                                      _controller.deepgramRecognitionLanguages,
                                  targetLanguages:
                                      SpeechController.supportedLanguages,
                                  sourceCode:
                                      _controller.deepgramRecognitionLanguage,
                                  targetCode: _controller.targetLanguage,
                                  canSwap: _canSwapGroupLanguages(
                                    _controller.deepgramRecognitionLanguages,
                                  ),
                                  onSourceSelected:
                                      _setDeepgramRecognitionLanguage,
                                  onTargetSelected: (value) {
                                    setState(() {
                                      _targetLanguage = value;
                                      _controller.setTargetLanguage(value);
                                    });
                                  },
                                  onSwap: () => _swapGroupLanguages(
                                    _controller.deepgramRecognitionLanguages,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Expanded(child: ChatMessageList()),
                              ],
                            ),
                          ),
                        ))
                : Center(
                    key: const ValueKey('two_way_placeholder'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 12,
                      ),
                      child: _initializing
                          ? const Center(child: CircularProgressIndicator())
                          : ChangeNotifierProvider<TwoWayChatController>.value(
                              value: _twoWayController,
                              child: const TwoWayChatView(),
                            ),
                    ),
                  ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_initializing && _isGroupSection) ...[
                  ChangeNotifierProvider<SpeechController>.value(
                    value: _controller,
                    child: const SpeechFooter(),
                  ),
                  const SizedBox(height: 8),
                ],
                NavigationBar(
                  selectedIndex: _selectedSection,
                  onDestinationSelected: _onSectionSelected,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.group_rounded),
                      label: context.l10n.groupLabel,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: context.l10n.twoWayLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestedResponseSnackBarContent extends StatelessWidget {
  const _SuggestedResponseSnackBarContent({
    required this.title,
    required this.closeTooltip,
    required this.onClose,
    required this.originalLabel,
    required this.translatedLabel,
    required this.originalText,
    required this.translatedText,
  });

  final String title;
  final String closeTooltip;
  final VoidCallback onClose;
  final String originalLabel;
  final String translatedLabel;
  final String originalText;
  final String translatedText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: closeTooltip,
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onInverseSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          originalLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.82),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(originalText),
        const SizedBox(height: 8),
        Text(
          translatedLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.82),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(translatedText),
      ],
    );
  }
}

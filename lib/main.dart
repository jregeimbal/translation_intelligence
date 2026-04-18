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
import 'services/app_settings.dart';
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
import 'widgets/audio_debug_dialog.dart';
import 'widgets/debounced_message_dispatcher.dart';
import 'widgets/first_launch_walkthrough_dialog.dart';
import 'widgets/footer.dart';
import 'widgets/group_chat_body.dart';
import 'widgets/home_page_app_bar.dart';
import 'widgets/home_page_bottom_bar.dart';
import 'widgets/initialization_error_view.dart';
import 'widgets/provider_settings_dialog.dart';
import 'widgets/speech_connection_debug_dialog.dart';
import 'widgets/two_way_chat_body.dart';

const Duration _suggestedResponseSnackBarDuration = Duration(seconds: 10);

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
    mergeWith: {if (apiBaseUrl.isNotEmpty) 'API_BASE_URL': apiBaseUrl},
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
  const MyHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.initializer,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final HomePageInitializer? initializer;

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AppPreferences _appPreferences = AppPreferences();
  late SpeechController _controller;
  late TwoWayChatController _twoWayController;
  late BackendApiClient _backendApiClient;
  final AppSettings _settings = AppSettings();
  StreamSubscription<String>? _listeningDeviceUpdateSub;
  StreamSubscription<SuggestedResponseEvent>? _suggestedResponseSub;
  Timer? _suggestedResponseTimer;
  late final DebouncedMessageDispatcher _listeningDeviceSnackBarDebouncer;
  bool _initializing = true;
  bool _controllersReady = false;
  bool _backendClientReady = false;
  String _initializationError = '';
  int _selectedSection = 0;
  Map<String, String> _speechToTextRecognitionLocales = const {
    'Multi (Auto)': SpeechToTextService.defaultRecognitionLanguage,
  };
  List<InputDevice> _listeningDevices = const [];
  List<PlaybackDevice> _playbackDevices = const [];
  SuggestedResponseEvent? _activeSuggestedResponse;
  int _suggestedResponsePresentationKey = 0;
  AppPreferencesSnapshot? _lastPersistedPreferences;
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
    _clearSuggestedResponse(notify: false);
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

    _settings.setDeepgramRecognitionModel(model);
    _settings.setDeepgramRecognitionLanguage(sourceLanguage);
    _settings.setSpeechToTextRecognitionLocale(
      snapshot.speechToTextRecognitionLocale,
    );
    _settings.setTargetLanguage(targetLanguage);
    _settings.setHasSeenAudioPlaybackBluetoothNotice(
      value: snapshot.hasSeenAudioPlaybackBluetoothNotice,
    );
    _settings.setHasCompletedFirstLaunchWalkthrough(
      value: snapshot.hasCompletedFirstLaunchWalkthrough,
    );
    _lastPersistedPreferences = AppPreferencesSnapshot(
      deepgramRecognitionModel: model,
      deepgramRecognitionLanguage: sourceLanguage,
      speechToTextRecognitionLocale: snapshot.speechToTextRecognitionLocale,
      targetLanguage: targetLanguage,
      hideTranslatedOriginalText: snapshot.hideTranslatedOriginalText,
      audioPlaybackEnabled: snapshot.audioPlaybackEnabled,
      hasSeenAudioPlaybackBluetoothNotice:
          snapshot.hasSeenAudioPlaybackBluetoothNotice,
      hasCompletedFirstLaunchWalkthrough:
          snapshot.hasCompletedFirstLaunchWalkthrough,
    );
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
      hasSeenAudioPlaybackBluetoothNotice:
          _settings.hasSeenAudioPlaybackBluetoothNotice,
      hasCompletedFirstLaunchWalkthrough:
          _settings.hasCompletedFirstLaunchWalkthrough,
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
        value: snapshot.hideTranslatedOriginalText,
      ),
    );
    unawaited(
      _appPreferences.setAudioPlaybackEnabled(
        value: snapshot.audioPlaybackEnabled,
      ),
    );
  }

  Future<void> _completeFirstLaunchWalkthrough() async {
    if (_settings.hasCompletedFirstLaunchWalkthrough) return;

    _settings.setHasCompletedFirstLaunchWalkthrough(value: true);
    final previous = _lastPersistedPreferences;
    if (previous != null) {
      _lastPersistedPreferences = AppPreferencesSnapshot(
        deepgramRecognitionModel: previous.deepgramRecognitionModel,
        deepgramRecognitionLanguage: previous.deepgramRecognitionLanguage,
        speechToTextRecognitionLocale: previous.speechToTextRecognitionLocale,
        targetLanguage: previous.targetLanguage,
        hideTranslatedOriginalText: previous.hideTranslatedOriginalText,
        audioPlaybackEnabled: previous.audioPlaybackEnabled,
        hasSeenAudioPlaybackBluetoothNotice:
            previous.hasSeenAudioPlaybackBluetoothNotice,
        hasCompletedFirstLaunchWalkthrough: true,
      );
    }

    await _appPreferences.setHasCompletedFirstLaunchWalkthrough(value: true);
  }

  Future<void> _markAudioPlaybackBluetoothNoticeSeen() async {
    if (_settings.hasSeenAudioPlaybackBluetoothNotice) return;

    _settings.setHasSeenAudioPlaybackBluetoothNotice(value: true);

    final previous = _lastPersistedPreferences;
    if (previous != null) {
      _lastPersistedPreferences = AppPreferencesSnapshot(
        deepgramRecognitionModel: previous.deepgramRecognitionModel,
        deepgramRecognitionLanguage: previous.deepgramRecognitionLanguage,
        speechToTextRecognitionLocale: previous.speechToTextRecognitionLocale,
        targetLanguage: previous.targetLanguage,
        hideTranslatedOriginalText: previous.hideTranslatedOriginalText,
        audioPlaybackEnabled: previous.audioPlaybackEnabled,
        hasSeenAudioPlaybackBluetoothNotice: true,
        hasCompletedFirstLaunchWalkthrough:
            previous.hasCompletedFirstLaunchWalkthrough,
      );
    }

    await _appPreferences.setHasSeenAudioPlaybackBluetoothNotice(value: true);
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
        _settings.hasCompletedFirstLaunchWalkthrough ||
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

  void _showDebugAudioDialog() {
    AudioDebugDialog.showInDialog(
      context,
      _controller,
      _twoWayController,
      _settings.outputProvider,
      _settings.sttProvider,
      _settings.translationProvider,
      isGroupSection: _isGroupSection,
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
      _showSuggestedResponsePanel(event);
    });
  }

  void _showSuggestedResponsePanel(SuggestedResponseEvent event) {
    _suggestedResponseTimer?.cancel();
    setState(() {
      _activeSuggestedResponse = event;
      _suggestedResponsePresentationKey += 1;
    });
    _suggestedResponseTimer = Timer(_suggestedResponseSnackBarDuration, () {
      if (!mounted) {
        return;
      }
      _clearSuggestedResponse();
    });
  }

  void _clearSuggestedResponse({bool notify = true}) {
    _suggestedResponseTimer?.cancel();
    _suggestedResponseTimer = null;
    if (!notify || !mounted || _activeSuggestedResponse == null) {
      _activeSuggestedResponse = null;
      return;
    }
    setState(() {
      _activeSuggestedResponse = null;
    });
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
    controller.setSttProvider(_settings.sttProvider);
    controller.setTranslationProvider(_settings.translationProvider);
    controller.setDeepgramRecognitionModel(_settings.deepgramRecognitionModel);
    controller.setDeepgramRecognitionLanguage(
      _settings.deepgramRecognitionLanguage,
    );
    controller.setSpeechToTextRecognitionLocale(
      _settings.speechToTextRecognitionLocale,
    );
    controller.setTargetLanguage(_settings.targetLanguage);
    if (_lastPersistedPreferences != null) {
      controller.setHideTranslatedOriginalText(
        enabled: _lastPersistedPreferences!.hideTranslatedOriginalText,
      );
      controller.setAudioPlaybackEnabled(
        enabled: _lastPersistedPreferences!.audioPlaybackEnabled,
      );
    }

    final twoWayController = TwoWayChatController(
      backendApiClient: backendApiClient,
    );
    twoWayController.setSttProvider(_settings.sttProvider);
    twoWayController.setTranslationProvider(_settings.translationProvider);
    twoWayController.setDeepgramRecognitionModel(
      _settings.deepgramRecognitionModel,
    );
    twoWayController.setDeepgramRecognitionLanguage(
      _settings.deepgramRecognitionLanguage,
    );
    twoWayController.setSpeechToTextRecognitionLocale(
      _settings.speechToTextRecognitionLocale,
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
      _playbackDevices = _controller.playbackDevices;
      _speechToTextRecognitionLocales =
          _controller.speechToTextRecognitionLocales;
      _initializing = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowFirstLaunchWalkthrough());
    });
  }

  void _setOutputProvider(SpeechOutputProvider provider) {
    if (_settings.outputProvider == provider || _initializing) return;
    _settings.setOutputProvider(provider);
    _controller.setOutputProvider(provider);
    _twoWayController.setOutputProvider(provider);
  }

  Future<void> _setSttProvider(SpeechSttProvider provider) async {
    if (_settings.sttProvider == provider || _initializing) return;

    if (_controller.isListening) {
      await _controller.stopListening();
    }
    if (_twoWayController.isListening) {
      await _twoWayController.stopListening();
    }

    if (!mounted) return;
    _settings.setSttProvider(provider);
    _controller.setSttProvider(provider);
    _twoWayController.setSttProvider(provider);
  }

  void _setTranslationProvider(SpeechTranslationProvider provider) {
    if (_settings.translationProvider == provider || _initializing) return;
    _settings.setTranslationProvider(provider);
    _controller.setTranslationProvider(provider);
    _twoWayController.setTranslationProvider(provider);
  }

  void _setDeepgramRecognitionModel(String model) {
    if (_settings.deepgramRecognitionModel == model || _initializing) return;
    _settings.setDeepgramRecognitionModel(model);
    _controller.setDeepgramRecognitionModel(model);
    _twoWayController.setDeepgramRecognitionModel(model);
  }

  Future<void> _setDeepgramRecognitionLanguage(String language) async {
    if (_settings.deepgramRecognitionLanguage == language || _initializing) {
      return;
    }

    final restartListening = _controller.isListening;
    if (restartListening) {
      await _controller.stopListening();
    }
    if (!mounted) return;

    _settings.setDeepgramRecognitionLanguage(language);
    _controller.setDeepgramRecognitionLanguage(language);
    _twoWayController.setDeepgramRecognitionLanguage(language);

    if (restartListening) {
      await _startGroupListeningWithDebugDialog();
    }
  }

  Future<void> _setSpeechToTextRecognitionLocale(String locale) async {
    if (_settings.speechToTextRecognitionLocale == locale || _initializing) {
      return;
    }

    final restartListening = _controller.isListening;
    if (restartListening) {
      await _controller.stopListening();
    }
    if (!mounted) return;

    _settings.setSpeechToTextRecognitionLocale(locale);
    _controller.setSpeechToTextRecognitionLocale(locale);
    _twoWayController.setSpeechToTextRecognitionLocale(locale);

    if (restartListening) {
      await _startGroupListeningWithDebugDialog();
    }
  }

  void _setListeningDeviceId(String? deviceId) {
    if (_settings.listeningDeviceId == deviceId || _initializing) return;
    _settings.setListeningDeviceId(deviceId);
    _controller.setListeningDeviceId(deviceId);
    _twoWayController.setListeningDeviceId(deviceId);
  }

  Future<void> _setPlaybackDeviceId(String? deviceId) async {
    if (_settings.playbackDeviceId == deviceId || _initializing) return;

    final applied = await _controller.setPlaybackDeviceId(deviceId);
    await _twoWayController.setPlaybackDeviceId(deviceId);

    if (!mounted) return;
    setState(() {
      _playbackDevices = _controller.playbackDevices;
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
      _playbackDevices = _controller.playbackDevices;
      _speechToTextRecognitionLocales =
          _controller.speechToTextRecognitionLocales;
    });

    final selection = await Navigator.of(context)
        .push<ProviderSettingsSelection>(
          MaterialPageRoute<ProviderSettingsSelection>(
            fullscreenDialog: true,
            builder: (context) {
              return ProviderSettingsDialog(
                initialSttProvider: _settings.sttProvider,
                initialTranslationProvider: _settings.translationProvider,
                initialOutputProvider: _settings.outputProvider,
                initialTargetLanguage: _settings.targetLanguage,
                targetLanguages: SpeechController.supportedLanguages,
                initialDeepgramRecognitionModel:
                    _settings.deepgramRecognitionModel,
                initialDeepgramRecognitionLanguage:
                    _settings.deepgramRecognitionLanguage,
                initialSpeechToTextRecognitionLocale:
                    _settings.speechToTextRecognitionLocale,
                initialSpeechToTextRecognitionLocales:
                    _speechToTextRecognitionLocales,
                initialListeningDevices: _listeningDevices,
                initialListeningDeviceId: _settings.listeningDeviceId,
                initialPlaybackDevices: _playbackDevices,
                initialPlaybackDeviceId: _settings.playbackDeviceId,
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

    _settings.applySelection(selection);

    if (selection.sttProvider != _settings.sttProvider) {
      await _setSttProvider(selection.sttProvider);
    } else if (selection.translationProvider != _settings.translationProvider) {
      _setTranslationProvider(selection.translationProvider);
    } else if (selection.outputProvider != _settings.outputProvider) {
      _setOutputProvider(selection.outputProvider);
    } else if (selection.targetLanguage != _settings.targetLanguage) {
      _settings.setTargetLanguage(selection.targetLanguage);
      _controller.setTargetLanguage(selection.targetLanguage);
    } else if (selection.deepgramRecognitionModel !=
        _settings.deepgramRecognitionModel) {
      _setDeepgramRecognitionModel(selection.deepgramRecognitionModel);
    } else if (selection.deepgramRecognitionLanguage !=
        _settings.deepgramRecognitionLanguage) {
      await _setDeepgramRecognitionLanguage(
        selection.deepgramRecognitionLanguage,
      );
    } else if (selection.speechToTextRecognitionLocale !=
        _settings.speechToTextRecognitionLocale) {
      await _setSpeechToTextRecognitionLocale(
        selection.speechToTextRecognitionLocale,
      );
    } else if (selection.listeningDeviceId != _settings.listeningDeviceId) {
      _setListeningDeviceId(selection.listeningDeviceId);
    } else if (selection.playbackDeviceId != _settings.playbackDeviceId) {
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
      _clearSuggestedResponse();
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

    _settings.setDeepgramRecognitionLanguage(target);
    _settings.setTargetLanguage(source);
    _controller.setDeepgramRecognitionLanguage(target);
    _twoWayController.setDeepgramRecognitionLanguage(target);
    _controller.setTargetLanguage(source);

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
    final tokens = resolveAppThemeTokens(Theme.of(context));

    if (_initializationError.isNotEmpty) {
      return InitializationErrorView(
        errorMessage: _initializationError,
        onRetry: _initializeControllers,
      );
    }

    final activeSuggestedResponse = _isGroupSection
        ? _activeSuggestedResponse
        : null;

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
        appBar: HomePageAppBar(
          initializing: _initializing,
          onHelpPressed: _showHelpWalkthrough,
          onDebugPressed: _showDebugAudioDialog,
          onSettingsPressed: _showProviderSettingsDialog,
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
                      : GroupChatBody(
                          controller: _controller,
                          canSwapGroupLanguages: _canSwapGroupLanguages,
                          onSourceSelected: _setDeepgramRecognitionLanguage,
                          onTargetSelected: (value) {
                            _settings.setTargetLanguage(value);
                            _controller.setTargetLanguage(value);
                          },
                          onSwap: () => _swapGroupLanguages(
                            _controller.deepgramRecognitionLanguages,
                          ),
                        ))
                : TwoWayChatBody(
                    initializing: _initializing,
                    twoWayController: _twoWayController,
                  ),
          ),
        ),
        bottomNavigationBar: HomePageBottomBar(
          activeSuggestedResponse: activeSuggestedResponse,
          suggestedResponseKey: _suggestedResponsePresentationKey,
          onCloseSuggestedResponse: _clearSuggestedResponse,
          showFooter: !_initializing && _isGroupSection,
          footerChild: !_initializing && _isGroupSection
              ? ChangeNotifierProvider<SpeechController>.value(
                  value: _controller,
                  child: SpeechFooter(
                    hasSeenAudioPlaybackBluetoothNotice:
                        _settings.hasSeenAudioPlaybackBluetoothNotice,
                    onAudioPlaybackBluetoothNoticeSeen:
                        _markAudioPlaybackBluetoothNoticeSeen,
                  ),
                )
              : null,
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
      ),
    );
  }
}

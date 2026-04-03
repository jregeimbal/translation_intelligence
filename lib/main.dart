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
import 'models/provider_settings_selection.dart';
import 'models/playback_device.dart';
import 'models/suggested_response.dart';
import 'models/two_way_message.dart';
import 'services/app_preferences.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_ext.dart';
import 'services/deepgram_recognition_catalog.dart';
import 'services/speech_output_provider.dart';
import 'services/speech_stt_provider.dart';
import 'services/speech_translation_provider.dart';
import 'theme/app_theme_resolver.dart';
import 'theme/hyper_linguist_theme.dart';
import 'theme/hyper_listen_theme.dart';
import 'widgets/audio_debug_dialog.dart';
import 'widgets/chat_message.dart';
import 'widgets/first_launch_walkthrough_dialog.dart';
import 'widgets/footer.dart';
import 'widgets/group_language_bar.dart';
import 'widgets/provider_settings_dialog.dart';
import 'widgets/speech_connection_debug_dialog.dart';
import 'widgets/two_way_chat.dart';

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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpeechController(), lazy: false),
        ChangeNotifierProvider(
          create: (_) => TwoWayChatController(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
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
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const MyHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
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
  StreamSubscription<String>? _listeningDeviceUpdateSub;
  StreamSubscription<SuggestedResponseEvent>? _suggestedResponseSub;
  Timer? _suggestedResponseTimer;
  late final DebouncedMessageDispatcher _listeningDeviceSnackBarDebouncer;
  bool _initializing = true;
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
      DeepgramRecognitionCatalog.defaultRecognitionLanguage;
  String _targetLanguage = 'en';
  Map<String, String> _speechToTextRecognitionLocales = const {
    'Multi (Auto)': DeepgramRecognitionCatalog.defaultRecognitionLanguage,
  };
  List<InputDevice> _listeningDevices = const [];
  List<PlaybackDevice> _playbackDevices = const [];
  String? _listeningDeviceId;
  String? _playbackDeviceId;
  SuggestedResponseEvent? _activeSuggestedResponse;
  int _suggestedResponsePresentationKey = 0;
  AppPreferencesSnapshot? _lastPersistedPreferences;
  bool _hasSeenAudioPlaybackBluetoothNotice = false;
  bool _hasCompletedFirstLaunchWalkthrough = false;
  bool _walkthroughShownThisSession = false;

  bool get _isGroupSection => _selectedSection == 0;

  void _disposeInitializedResources() {
    _listeningDeviceUpdateSub?.cancel();
    _listeningDeviceUpdateSub = null;
    _suggestedResponseSub?.cancel();
    _suggestedResponseSub = null;
    _clearSuggestedResponse(notify: false);
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
      hasSeenAudioPlaybackBluetoothNotice:
          snapshot.hasSeenAudioPlaybackBluetoothNotice,
      hasCompletedFirstLaunchWalkthrough:
          snapshot.hasCompletedFirstLaunchWalkthrough,
    );
    _hasSeenAudioPlaybackBluetoothNotice =
        snapshot.hasSeenAudioPlaybackBluetoothNotice;
    _hasCompletedFirstLaunchWalkthrough =
        snapshot.hasCompletedFirstLaunchWalkthrough;
  }

  void _persistControllerPreferences() {
    final speechController = context.read<SpeechController>();

    final snapshot = AppPreferencesSnapshot(
      deepgramRecognitionModel: speechController.deepgramRecognitionModel,
      deepgramRecognitionLanguage: speechController.deepgramRecognitionLanguage,
      speechToTextRecognitionLocale:
          speechController.speechToTextRecognitionLocale,
      targetLanguage: speechController.targetLanguage,
      hideTranslatedOriginalText: speechController.hideTranslatedOriginalText,
      audioPlaybackEnabled: speechController.audioPlaybackEnabled,
      hasSeenAudioPlaybackBluetoothNotice: _hasSeenAudioPlaybackBluetoothNotice,
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
        hasSeenAudioPlaybackBluetoothNotice:
            previous.hasSeenAudioPlaybackBluetoothNotice,
        hasCompletedFirstLaunchWalkthrough: true,
      );
    }

    await _appPreferences.setHasCompletedFirstLaunchWalkthrough(true);
  }

  Future<void> _markAudioPlaybackBluetoothNoticeSeen() async {
    if (_hasSeenAudioPlaybackBluetoothNotice) return;

    setState(() {
      _hasSeenAudioPlaybackBluetoothNotice = true;
    });

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

    await _appPreferences.setHasSeenAudioPlaybackBluetoothNotice(true);
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

  void _showDebugAudioDialog() {
    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    AudioDebugDialog.showInDialog(
      context,
      speechController,
      twoWayController,
      _outputProvider,
      _sttProvider,
      _translationProvider,
      _isGroupSection,
    );
  }

  void _showDebouncedListeningDeviceSnackBar(String message) {
    _listeningDeviceSnackBarDebouncer.schedule(
      localizedListeningDeviceUpdate(context, message),
    );
  }

  void _bindListeningDeviceNotifications() {
    final speechController = context.read<SpeechController>();

    _listeningDeviceUpdateSub?.cancel();
    _listeningDeviceUpdateSub = speechController.listeningDeviceUpdates.listen((
      message,
    ) {
      if (!mounted || _initializing) return;
      _showDebouncedListeningDeviceSnackBar(message);
    });
  }

  void _bindSuggestedResponseNotifications() {
    final speechController = context.read<SpeechController>();

    _suggestedResponseSub?.cancel();
    _suggestedResponseSub = speechController.suggestedResponses.listen((event) {
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
      final speechController = context.read<SpeechController>();
      await speechController.startListening();
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
      final twoWayController = context.read<TwoWayChatController>();
      await twoWayController.startListening(speaker);
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

  Future<void> _initializeControllers() async {
    setState(() {
      _initializing = true;
      _initializationError = '';
    });

    try {
      await _loadPersistedPreferences();

      if (!mounted) return;

      // Access controllers via context
      final speechController = context.read<SpeechController>();
      final twoWayController = context.read<TwoWayChatController>();

      // Initialize with persisted values
      speechController.setDeepgramRecognitionModel(_deepgramRecognitionModel);
      speechController.setDeepgramRecognitionLanguage(
        _deepgramRecognitionLanguage,
      );
      speechController.setSpeechToTextRecognitionLocale(
        _speechToTextRecognitionLocale,
      );
      speechController.setTargetLanguage(_targetLanguage);
      if (_lastPersistedPreferences != null) {
        speechController.setHideTranslatedOriginalText(
          _lastPersistedPreferences!.hideTranslatedOriginalText,
        );
        speechController.setAudioPlaybackEnabled(
          _lastPersistedPreferences!.audioPlaybackEnabled,
        );
      }

      await speechController.init();
      await twoWayController.init();

      // Listen to controller updates
      speechController.addListener(_persistControllerPreferences);

      // Bind notifications
      _bindListeningDeviceNotifications();
      _bindSuggestedResponseNotifications();

      setState(() {
        _listeningDevices = speechController.listeningDevices;
        _listeningDeviceId = speechController.listeningDeviceId;
        _playbackDevices = speechController.playbackDevices;
        _playbackDeviceId = speechController.playbackDeviceId;
        _speechToTextRecognitionLocales =
            speechController.speechToTextRecognitionLocales;
        _speechToTextRecognitionLocale =
            speechController.speechToTextRecognitionLocale;
        _targetLanguage = speechController.targetLanguage;
        _initializing = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeShowFirstLaunchWalkthrough());
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializationError = '$error';
        _initializing = false;
      });
    }
  }

  void _setOutputProvider(SpeechOutputProvider provider) {
    if (_outputProvider == provider || _initializing) return;
    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    setState(() {
      _outputProvider = provider;
      speechController.setOutputProvider(provider);
      twoWayController.setOutputProvider(provider);
    });
  }

  Future<void> _setSttProvider(SpeechSttProvider provider) async {
    if (_sttProvider == provider || _initializing) return;

    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    if (speechController.isListening) {
      await speechController.stopListening();
    }
    if (twoWayController.isListening) {
      await twoWayController.stopListening();
    }

    if (!mounted) return;
    setState(() {
      _sttProvider = provider;
      speechController.setSttProvider(provider);
      twoWayController.setSttProvider(provider);
    });
  }

  void _setTranslationProvider(SpeechTranslationProvider provider) {
    if (_translationProvider == provider || _initializing) return;
    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    setState(() {
      _translationProvider = provider;
      speechController.setTranslationProvider(provider);
      twoWayController.setTranslationProvider(provider);
    });
  }

  void _setDeepgramRecognitionModel(String model) {
    if (_deepgramRecognitionModel == model || _initializing) return;
    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    setState(() {
      _deepgramRecognitionModel = model;
      speechController.setDeepgramRecognitionModel(model);
      twoWayController.setDeepgramRecognitionModel(model);
    });
  }

  Future<void> _setDeepgramRecognitionLanguage(String language) async {
    if (_deepgramRecognitionLanguage == language || _initializing) return;

    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    final restartListening = speechController.isListening;
    if (restartListening) {
      await speechController.stopListening();
    }
    if (!mounted) return;

    setState(() {
      _deepgramRecognitionLanguage = language;
      speechController.setDeepgramRecognitionLanguage(language);
      twoWayController.setDeepgramRecognitionLanguage(language);
    });

    if (restartListening) {
      await _startGroupListeningWithDebugDialog();
    }
  }

  Future<void> _setSpeechToTextRecognitionLocale(String locale) async {
    if (_speechToTextRecognitionLocale == locale || _initializing) return;

    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    final restartListening = speechController.isListening;
    if (restartListening) {
      await speechController.stopListening();
    }
    if (!mounted) return;

    setState(() {
      _speechToTextRecognitionLocale = locale;
      speechController.setSpeechToTextRecognitionLocale(locale);
      twoWayController.setSpeechToTextRecognitionLocale(locale);
    });

    if (restartListening) {
      await _startGroupListeningWithDebugDialog();
    }
  }

  void _setListeningDeviceId(String? deviceId) {
    if (_listeningDeviceId == deviceId || _initializing) return;
    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    setState(() {
      _listeningDeviceId = deviceId;
      speechController.setListeningDeviceId(deviceId);
      twoWayController.setListeningDeviceId(deviceId);
    });
  }

  Future<void> _setPlaybackDeviceId(String? deviceId) async {
    if (_playbackDeviceId == deviceId || _initializing) return;

    if (!mounted) return;

    final speechController = context.read<SpeechController>();
    final applied = await speechController.setPlaybackDeviceId(deviceId);
    if (!mounted) return;

    final twoWayController = context.read<TwoWayChatController>();
    await twoWayController.setPlaybackDeviceId(deviceId);

    if (!mounted) return;

    setState(() {
      _playbackDevices = speechController.playbackDevices;
      _playbackDeviceId = speechController.playbackDeviceId;
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

    final speechController = context.read<SpeechController>();
    await speechController.refreshListeningDevices();
    await speechController.refreshPlaybackDevices();
    await speechController.refreshSpeechToTextRecognitionLocales();
    if (!mounted) return;
    setState(() {
      _listeningDevices = speechController.listeningDevices;
      _listeningDeviceId = speechController.listeningDeviceId;
      _playbackDevices = speechController.playbackDevices;
      _playbackDeviceId = speechController.playbackDeviceId;
      _speechToTextRecognitionLocales =
          speechController.speechToTextRecognitionLocales;
      _speechToTextRecognitionLocale =
          speechController.speechToTextRecognitionLocale;
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

    if (!mounted) return;

    final twoWayController = context.read<TwoWayChatController>();

    final restartGroupListening = speechController.isListening;
    final restartTwoWayListening = twoWayController.isListening;
    final restartTwoWaySpeaker = twoWayController.activeSpeaker;

    if (restartGroupListening) {
      await speechController.stopListening();
    }
    if (restartTwoWayListening) {
      await twoWayController.stopListening();
    }

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
        speechController.setTargetLanguage(selection.targetLanguage);
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

    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    if (_selectedSection == 0 &&
        !_initializing &&
        speechController.isListening) {
      try {
        await speechController.stopListening();
      } catch (_) {}
    }
    if (_selectedSection == 1 &&
        !_initializing &&
        twoWayController.isListening) {
      try {
        await twoWayController.stopListening();
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

    final speechController = context.read<SpeechController>();

    final source = speechController.deepgramRecognitionLanguage;
    final target = speechController.targetLanguage;

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

    final speechController = context.read<SpeechController>();
    final twoWayController = context.read<TwoWayChatController>();

    final source = speechController.deepgramRecognitionLanguage;
    final target = speechController.targetLanguage;

    if (source == target) return;

    final restartListening = speechController.isListening;
    if (restartListening) {
      await speechController.stopListening();
    }
    if (!mounted) return;

    setState(() {
      _deepgramRecognitionLanguage = target;
      _targetLanguage = source;
      speechController.setDeepgramRecognitionLanguage(target);
      twoWayController.setDeepgramRecognitionLanguage(target);
      speechController.setTargetLanguage(source);
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

    // Clean up controller listeners
    final speechController = context.read<SpeechController>();
    speechController.removeListener(_persistControllerPreferences);

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
    final activeSuggestedResponse = _isGroupSection
        ? _activeSuggestedResponse
        : null;

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
                    'assets/icon_omnialingo.png',
                    filterQuality: FilterQuality.high,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
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
                      : Builder(
                          builder: (context) => Padding(
                            key: const ValueKey('group_chat'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 12,
                            ),
                            child: Column(
                              children: [
                                GroupLanguageBar(
                                  sourceLanguages: context
                                      .watch<SpeechController>()
                                      .deepgramRecognitionLanguages,
                                  targetLanguages:
                                      SpeechController.supportedLanguages,
                                  sourceCode: context
                                      .watch<SpeechController>()
                                      .deepgramRecognitionLanguage,
                                  targetCode: context
                                      .watch<SpeechController>()
                                      .targetLanguage,
                                  canSwap: _canSwapGroupLanguages(
                                    context
                                        .watch<SpeechController>()
                                        .deepgramRecognitionLanguages,
                                  ),
                                  onSourceSelected:
                                      _setDeepgramRecognitionLanguage,
                                  onTargetSelected: (value) {
                                    setState(() {
                                      _targetLanguage = value;
                                      context
                                          .read<SpeechController>()
                                          .setTargetLanguage(value);
                                    });
                                  },
                                  onSwap: () => _swapGroupLanguages(
                                    context
                                        .watch<SpeechController>()
                                        .deepgramRecognitionLanguages,
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
                          : const TwoWayChatView(),
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: activeSuggestedResponse == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey<int>(_suggestedResponsePresentationKey),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SuggestedResponsePanel(
                            event: activeSuggestedResponse,
                            title: context.l10n.suggestedResponseTitle,
                            closeTooltip: context.l10n.close,
                            onClose: _clearSuggestedResponse,
                            timeout: _suggestedResponseSnackBarDuration,
                          ),
                        ),
                ),
                if (!_initializing && _isGroupSection) ...[
                  SpeechFooter(
                    hasSeenAudioPlaybackBluetoothNotice:
                        _hasSeenAudioPlaybackBluetoothNotice,
                    onAudioPlaybackBluetoothNoticeSeen:
                        _markAudioPlaybackBluetoothNoticeSeen,
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

class _SuggestedResponsePanel extends StatelessWidget {
  const _SuggestedResponsePanel({
    required this.event,
    required this.title,
    required this.closeTooltip,
    required this.onClose,
    required this.timeout,
  });

  final SuggestedResponseEvent event;
  final String title;
  final String closeTooltip;
  final VoidCallback onClose;
  final Duration timeout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sourceLanguageLabel = localizedAppLanguageName(
      context,
      event.response.sourceLanguageCode,
    );
    final targetLanguageLabel = localizedAppLanguageName(
      context,
      event.response.targetLanguageCode,
    );

    return Material(
      key: const Key('suggested-response-panel'),
      color: colorScheme.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
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
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1, end: 0),
                  duration: timeout,
                  builder: (context, remaining, child) {
                    return SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              key: const Key(
                                'suggested-response-timeout-progress',
                              ),
                              value: remaining,
                              strokeWidth: 2,
                              backgroundColor: colorScheme.onInverseSurface
                                  .withValues(alpha: 0.18),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onInverseSurface.withValues(
                                  alpha: 0.82,
                                ),
                              ),
                            ),
                          ),
                          child!,
                        ],
                      ),
                    );
                  },
                  child: IconButton(
                    tooltip: closeTooltip,
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    iconSize: 20,
                    splashRadius: 16,
                    visualDensity: VisualDensity.standard,
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.onInverseSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.suggestedResponseOriginalLabel(sourceLanguageLabel),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onInverseSurface.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.response.originalText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onInverseSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.suggestedResponseTranslatedLabel(
                targetLanguageLabel,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onInverseSurface.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.response.translatedText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onInverseSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

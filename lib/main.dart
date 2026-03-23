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
import 'services/backend_api_client.dart';
import 'services/app_preferences.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_ext.dart';
import 'services/backend_stt_client.dart';
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
import 'widgets/footer.dart';
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

class ProviderSettingsDialog extends StatefulWidget {
  final SpeechSttProvider initialSttProvider;
  final SpeechTranslationProvider initialTranslationProvider;
  final SpeechOutputProvider initialOutputProvider;
  final String initialDeepgramRecognitionModel;
  final String initialDeepgramRecognitionLanguage;
  final String initialSpeechToTextRecognitionLocale;
  final Map<String, String> initialSpeechToTextRecognitionLocales;
  final List<InputDevice> initialListeningDevices;
  final String? initialListeningDeviceId;
  final List<PlaybackDevice> initialPlaybackDevices;
  final String? initialPlaybackDeviceId;
  final ThemeMode initialThemeMode;

  const ProviderSettingsDialog({
    super.key,
    required this.initialSttProvider,
    required this.initialTranslationProvider,
    required this.initialOutputProvider,
    required this.initialDeepgramRecognitionModel,
    required this.initialDeepgramRecognitionLanguage,
    required this.initialSpeechToTextRecognitionLocale,
    required this.initialSpeechToTextRecognitionLocales,
    required this.initialListeningDevices,
    required this.initialListeningDeviceId,
    required this.initialPlaybackDevices,
    required this.initialPlaybackDeviceId,
    required this.initialThemeMode,
  });

  @override
  State<ProviderSettingsDialog> createState() => _ProviderSettingsDialogState();
}

class _ProviderSettingsDialogState extends State<ProviderSettingsDialog> {
  late SpeechSttProvider _selectedSttProvider;
  late SpeechTranslationProvider _selectedTranslationProvider;
  late SpeechOutputProvider _selectedOutputProvider;
  late String _selectedDeepgramRecognitionModel;
  late String _selectedDeepgramRecognitionLanguage;
  late String _selectedSpeechToTextRecognitionLocale;
  late Map<String, String> _speechToTextRecognitionLocales;
  late String? _selectedListeningDeviceId;
  late List<InputDevice> _listeningDevices;
  late String? _selectedPlaybackDeviceId;
  late List<PlaybackDevice> _playbackDevices;
  late ThemeMode _selectedThemeMode;

  @override
  void initState() {
    super.initState();
    _selectedSttProvider = widget.initialSttProvider;
    _selectedTranslationProvider = widget.initialTranslationProvider;
    _selectedOutputProvider = widget.initialOutputProvider;
    _selectedDeepgramRecognitionModel = widget.initialDeepgramRecognitionModel;
    _selectedDeepgramRecognitionLanguage =
        widget.initialDeepgramRecognitionLanguage;
    _selectedSpeechToTextRecognitionLocale =
        widget.initialSpeechToTextRecognitionLocale;
    _speechToTextRecognitionLocales = Map<String, String>.from(
      widget.initialSpeechToTextRecognitionLocales,
    );
    _selectedListeningDeviceId = widget.initialListeningDeviceId;
    _listeningDevices = List<InputDevice>.from(widget.initialListeningDevices);
    _selectedPlaybackDeviceId = widget.initialPlaybackDeviceId;
    _playbackDevices = List<PlaybackDevice>.from(widget.initialPlaybackDevices);
    _selectedThemeMode = widget.initialThemeMode;
  }

  String _themeModeLabel(ThemeMode mode) {
    final l10n = context.l10n;
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeModeSystem;
      case ThemeMode.light:
        return l10n.themeModeLight;
      case ThemeMode.dark:
        return l10n.themeModeDark;
    }
  }

  InputDecorationThemeData _dropdownMenuTheme(
    ThemeData theme, {
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    TextStyle? labelStyle,
    TextStyle? floatingLabelStyle,
  }) {
    return InputDecorationThemeData(
      isDense: true,
      contentPadding: contentPadding,
      labelStyle: labelStyle,
      floatingLabelStyle: floatingLabelStyle,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dropdownTextStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 18);
    final deepgramLanguages =
        DeepgramRecognitionCatalog
            .supportedRecognitionLanguagesByModel[_selectedDeepgramRecognitionModel] ??
        DeepgramRecognitionCatalog
            .supportedRecognitionLanguagesByModel[DeepgramRecognitionCatalog
            .defaultRecognitionModel]!;

    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        title: Text(l10n.settingsTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                tabs: [
                  Tab(text: l10n.tabProviders),
                  Tab(text: l10n.tabAudio),
                  Tab(text: l10n.tabDisplay),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.tabProviders),
                          const SizedBox(height: 12),
                          Text(l10n.speechToTextLabel),
                          const SizedBox(height: 8),
                          DropdownMenuFormField<SpeechSttProvider>(
                            initialSelection: _selectedSttProvider,
                            expandedInsets: EdgeInsets.zero,
                            enableSearch: false,
                            requestFocusOnTap: false,
                            textStyle: dropdownTextStyle,
                            inputDecorationTheme: _dropdownMenuTheme(theme),
                            dropdownMenuEntries: SpeechSttProvider.values
                                .map(
                                  (provider) =>
                                      DropdownMenuEntry<SpeechSttProvider>(
                                        value: provider,
                                        label: localizedSttProviderLabel(
                                          context,
                                          provider,
                                        ),
                                      ),
                                )
                                .toList(),
                            onSelected: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedSttProvider = value;
                                if (value != SpeechSttProvider.deepgram) {
                                  _selectedListeningDeviceId = null;
                                }
                              });
                            },
                          ),
                          if (_selectedSttProvider ==
                              SpeechSttProvider.deepgram) ...[
                            const SizedBox(height: 16),
                            Text(l10n.deepgramModelLabel),
                            const SizedBox(height: 8),
                            DropdownMenuFormField<String>(
                              initialSelection:
                                  _selectedDeepgramRecognitionModel,
                              expandedInsets: EdgeInsets.zero,
                              enableSearch: false,
                              requestFocusOnTap: false,
                              textStyle: dropdownTextStyle,
                              inputDecorationTheme: _dropdownMenuTheme(theme),
                              dropdownMenuEntries: DeepgramRecognitionCatalog
                                  .supportedRecognitionModels
                                  .map(
                                    (model) => DropdownMenuEntry<String>(
                                      value: model,
                                      label: model,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedDeepgramRecognitionModel = value;
                                  final supportedValues =
                                      (DeepgramRecognitionCatalog
                                                  .supportedRecognitionLanguagesByModel[value] ??
                                              const <String, String>{})
                                          .values
                                          .toSet();
                                  if (!supportedValues.contains(
                                    _selectedDeepgramRecognitionLanguage,
                                  )) {
                                    _selectedDeepgramRecognitionLanguage =
                                        DeepgramRecognitionCatalog.defaultRecognitionLanguageForModel(
                                          value,
                                        );
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(l10n.deepgramLanguageLabel),
                            const SizedBox(height: 8),
                            DropdownMenuFormField<String>(
                              initialSelection:
                                  _selectedDeepgramRecognitionLanguage,
                              expandedInsets: EdgeInsets.zero,
                              enableSearch: false,
                              requestFocusOnTap: false,
                              textStyle: dropdownTextStyle,
                              inputDecorationTheme: _dropdownMenuTheme(theme),
                              dropdownMenuEntries: deepgramLanguages.entries
                                  .map(
                                    (entry) => DropdownMenuEntry<String>(
                                      value: entry.value,
                                      label: entry.key,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedDeepgramRecognitionLanguage = value;
                                });
                              },
                            ),
                          ],
                          if (_selectedSttProvider ==
                              SpeechSttProvider.google) ...[
                            const SizedBox(height: 16),
                            Text(l10n.googleLocaleLabel),
                            const SizedBox(height: 8),
                            DropdownMenuFormField<String>(
                              initialSelection:
                                  _selectedSpeechToTextRecognitionLocale,
                              expandedInsets: EdgeInsets.zero,
                              enableSearch: false,
                              requestFocusOnTap: false,
                              textStyle: dropdownTextStyle,
                              inputDecorationTheme: _dropdownMenuTheme(theme),
                              dropdownMenuEntries:
                                  _speechToTextRecognitionLocales.entries
                                      .map(
                                        (entry) => DropdownMenuEntry<String>(
                                          value: entry.value,
                                          label:
                                              localizedRecognitionLocaleLabel(
                                                context,
                                                entry.value,
                                              ),
                                        ),
                                      )
                                      .toList(),
                              onSelected: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedSpeechToTextRecognitionLocale =
                                      value;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(l10n.translationLabel),
                          const SizedBox(height: 8),
                          DropdownMenuFormField<SpeechTranslationProvider>(
                            initialSelection: _selectedTranslationProvider,
                            expandedInsets: EdgeInsets.zero,
                            enableSearch: false,
                            requestFocusOnTap: false,
                            textStyle: dropdownTextStyle,
                            inputDecorationTheme: _dropdownMenuTheme(theme),
                            dropdownMenuEntries: SpeechTranslationProvider
                                .values
                                .map(
                                  (provider) =>
                                      DropdownMenuEntry<
                                        SpeechTranslationProvider
                                      >(
                                        value: provider,
                                        label:
                                            localizedTranslationProviderLabel(
                                              context,
                                              provider,
                                            ),
                                      ),
                                )
                                .toList(),
                            onSelected: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedTranslationProvider = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.textToSpeechLabel),
                          const SizedBox(height: 8),
                          DropdownMenuFormField<SpeechOutputProvider>(
                            initialSelection: _selectedOutputProvider,
                            expandedInsets: EdgeInsets.zero,
                            enableSearch: false,
                            requestFocusOnTap: false,
                            textStyle: dropdownTextStyle,
                            inputDecorationTheme: _dropdownMenuTheme(theme),
                            dropdownMenuEntries: SpeechOutputProvider.values
                                .map(
                                  (provider) =>
                                      DropdownMenuEntry<SpeechOutputProvider>(
                                        value: provider,
                                        label: localizedOutputProviderLabel(
                                          context,
                                          provider,
                                        ),
                                      ),
                                )
                                .toList(),
                            onSelected: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedOutputProvider = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.tabAudio),
                          const SizedBox(height: 12),
                          Text(l10n.listeningDeviceLabel),
                          const SizedBox(height: 8),
                          if (_selectedSttProvider !=
                              SpeechSttProvider.deepgram)
                            Text(l10n.audioInputSelectionHint)
                          else if (_listeningDevices.isEmpty)
                            Text(l10n.noInputDevicesDetected)
                          else ...[
                            Builder(
                              builder: (context) {
                                final selected = _listeningDevices
                                    .where(
                                      (device) =>
                                          device.id ==
                                          _selectedListeningDeviceId,
                                    )
                                    .cast<InputDevice?>()
                                    .firstWhere(
                                      (_) => true,
                                      orElse: () => null,
                                    );
                                final details = selected == null
                                    ? l10n.autoWithDetails(
                                        _listeningDevices.first.label.isNotEmpty
                                            ? _listeningDevices.first.label
                                            : _listeningDevices.first.id,
                                      )
                                    : selected.label.isNotEmpty
                                    ? selected.label
                                    : selected.id;

                                return Text(l10n.currentDetails(details));
                              },
                            ),
                            if (_listeningDevices.length > 1) ...[
                              const SizedBox(height: 8),
                              DropdownMenuFormField<String?>(
                                initialSelection: _selectedListeningDeviceId,
                                expandedInsets: EdgeInsets.zero,
                                enableSearch: false,
                                requestFocusOnTap: false,
                                textStyle: dropdownTextStyle,
                                inputDecorationTheme: _dropdownMenuTheme(theme),
                                dropdownMenuEntries: [
                                  DropdownMenuEntry<String?>(
                                    value: null,
                                    label: l10n.autoLabel,
                                  ),
                                  ..._listeningDevices.map(
                                    (device) => DropdownMenuEntry<String?>(
                                      value: device.id,
                                      label: device.label.isNotEmpty
                                          ? device.label
                                          : device.id,
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  setState(() {
                                    _selectedListeningDeviceId = value;
                                  });
                                },
                              ),
                            ],
                          ],
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(l10n.playbackDeviceLabel),
                          const SizedBox(height: 8),
                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(l10n.iosPlaybackRoutesHint),
                            ),
                          if (_playbackDevices.isEmpty)
                            Text(l10n.playbackUnavailableHint)
                          else ...[
                            Builder(
                              builder: (context) {
                                final selected = _playbackDevices
                                    .where(
                                      (device) =>
                                          device.id ==
                                          _selectedPlaybackDeviceId,
                                    )
                                    .cast<PlaybackDevice?>()
                                    .firstWhere(
                                      (_) => true,
                                      orElse: () => null,
                                    );
                                final details =
                                    selected?.details ??
                                    _playbackDevices.first.details;

                                return Text(l10n.currentDetails(details));
                              },
                            ),
                            if (_playbackDevices.length > 1) ...[
                              const SizedBox(height: 8),
                              DropdownMenuFormField<String?>(
                                initialSelection: _selectedPlaybackDeviceId,
                                expandedInsets: EdgeInsets.zero,
                                enableSearch: false,
                                requestFocusOnTap: false,
                                textStyle: dropdownTextStyle,
                                inputDecorationTheme: _dropdownMenuTheme(theme),
                                dropdownMenuEntries: [
                                  DropdownMenuEntry<String?>(
                                    value: null,
                                    label: l10n.autoLabel,
                                  ),
                                  ..._playbackDevices.map(
                                    (device) => DropdownMenuEntry<String?>(
                                      value: device.id,
                                      label: device.details,
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  setState(() {
                                    _selectedPlaybackDeviceId = value;
                                  });
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.displayLabel),
                          const SizedBox(height: 12),
                          Text(l10n.themeModeLabel),
                          const SizedBox(height: 8),
                          DropdownMenuFormField<ThemeMode>(
                            initialSelection: _selectedThemeMode,
                            expandedInsets: EdgeInsets.zero,
                            enableSearch: false,
                            requestFocusOnTap: false,
                            textStyle: dropdownTextStyle,
                            inputDecorationTheme: _dropdownMenuTheme(theme),
                            dropdownMenuEntries: ThemeMode.values
                                .map(
                                  (mode) => DropdownMenuEntry<ThemeMode>(
                                    value: mode,
                                    label: _themeModeLabel(mode),
                                  ),
                                )
                                .toList(),
                            onSelected: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedThemeMode = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(
                ProviderSettingsSelection(
                  sttProvider: _selectedSttProvider,
                  translationProvider: _selectedTranslationProvider,
                  outputProvider: _selectedOutputProvider,
                  deepgramRecognitionModel: _selectedDeepgramRecognitionModel,
                  deepgramRecognitionLanguage:
                      _selectedDeepgramRecognitionLanguage,
                  speechToTextRecognitionLocale:
                      _selectedSpeechToTextRecognitionLocale,
                  speechToTextRecognitionLocales:
                      _speechToTextRecognitionLocales,
                  listeningDeviceId: _selectedListeningDeviceId,
                  playbackDeviceId: _selectedPlaybackDeviceId,
                  themeMode: _selectedThemeMode,
                ),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final AppPreferences _appPreferences = AppPreferences();
  late SpeechController _controller;
  late TwoWayChatController _twoWayController;
  late BackendApiClient _backendApiClient;
  StreamSubscription<String>? _listeningDeviceUpdateSub;
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

  bool get _isGroupSection => _selectedSection == 0;

  void _disposeInitializedResources() {
    if (_controllersReady) {
      _controller.removeListener(_persistControllerPreferences);
    }
    _listeningDeviceUpdateSub?.cancel();
    _listeningDeviceUpdateSub = null;
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
    final backendSttClient = BackendSttClient(
      baseUrl: runtimeConfig.apiBaseUrl,
      authTokenProvider: authSession.getIdToken,
    );

    final controller = SpeechController(
      backendApiClient: backendApiClient,
      backendSttClient: backendSttClient,
    );
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
      backendSttClient: backendSttClient,
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

    await Future.wait([controller.init(), twoWayController.init()]);

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
      await _controller.startListening();
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
      await _controller.startListening();
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

    final selection = await showDialog<ProviderSettingsSelection>(
      context: context,
      builder: (context) {
        return ProviderSettingsDialog(
          initialSttProvider: _sttProvider,
          initialTranslationProvider: _translationProvider,
          initialOutputProvider: _outputProvider,
          initialDeepgramRecognitionModel: _deepgramRecognitionModel,
          initialDeepgramRecognitionLanguage: _deepgramRecognitionLanguage,
          initialSpeechToTextRecognitionLocale: _speechToTextRecognitionLocale,
          initialSpeechToTextRecognitionLocales:
              _speechToTextRecognitionLocales,
          initialListeningDevices: _listeningDevices,
          initialListeningDeviceId: _listeningDeviceId,
          initialPlaybackDevices: _playbackDevices,
          initialPlaybackDeviceId: _playbackDeviceId,
          initialThemeMode: widget.themeMode,
        );
      },
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
      await _controller.startListening();
    }
    if (restartTwoWayListening && restartTwoWaySpeaker != null) {
      await _twoWayController.startListening(restartTwoWaySpeaker);
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
      await _controller.startListening();
    }
  }

  Widget _buildGroupLanguageBar(ThemeData theme) {
    final tokens = resolveAppThemeTokens(theme);
    final sourceLanguages = _controller.deepgramRecognitionLanguages;
    final targetLanguages = SpeechController.supportedLanguages;
    final canSwap = _canSwapGroupLanguages(sourceLanguages);

    final sourceCode = _controller.deepgramRecognitionLanguage;
    final targetCode = _controller.targetLanguage;
    final fieldTheme = InputDecorationThemeData(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: const TextStyle(fontSize: 12),
      floatingLabelStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.glassSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownMenuFormField<String>(
              initialSelection: sourceCode,
              expandedInsets: EdgeInsets.zero,
              enableSearch: false,
              requestFocusOnTap: false,
              textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 18),
              label: Text(context.l10n.sourceLabel),
              inputDecorationTheme: fieldTheme,
              dropdownMenuEntries: sourceLanguages.entries
                  .map(
                    (entry) => DropdownMenuEntry<String>(
                      value: entry.value,
                      label: localizedDeepgramLanguageLabel(
                        context,
                        entry.value,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onSelected: (value) async {
                if (value == null || value == sourceCode) return;
                await _setDeepgramRecognitionLanguage(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: canSwap
                ? context.l10n.swapLanguagesTooltip
                : (sourceCode == 'multi' || targetCode == 'multi'
                      ? context.l10n.swapUnavailableMultiTooltip
                      : context.l10n.swapUnavailablePairTooltip),
            onPressed: canSwap
                ? () async => _swapGroupLanguages(sourceLanguages)
                : null,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownMenuFormField<String>(
              initialSelection: targetCode,
              expandedInsets: EdgeInsets.zero,
              enableSearch: false,
              requestFocusOnTap: false,
              textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 18),
              label: Text(context.l10n.targetLabel),
              inputDecorationTheme: fieldTheme,
              dropdownMenuEntries: targetLanguages
                  .map(
                    (languageCode) => DropdownMenuEntry<String>(
                      value: languageCode,
                      label: localizedAppLanguageName(context, languageCode),
                    ),
                  )
                  .toList(growable: false),
              onSelected: (value) {
                if (value == null || value == targetCode) return;
                setState(() {
                  _targetLanguage = value;
                  _controller.setTargetLanguage(value);
                });
              },
            ),
          ),
        ],
      ),
    );
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
                    'assets/icon_omnialingo.png',
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
                                _buildGroupLanguageBar(theme),
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

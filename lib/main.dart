import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import 'controllers/speech_controller.dart';
import 'controllers/two_way_chat_controller.dart';
import 'models/playback_device.dart';
import 'services/deepgram_service.dart';
import 'services/stts_service.dart';
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
  await dotenv.load();

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

    return MaterialApp(
      title: 'Translation Intelligence',
      theme: selectedLightTheme,
      darkTheme: selectedDarkTheme,
      themeMode: _themeMode,
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

class ProviderSettingsSelection {
  final SpeechSttProvider sttProvider;
  final SpeechTranslationProvider translationProvider;
  final SpeechOutputProvider outputProvider;
  final String deepgramRecognitionModel;
  final String deepgramRecognitionLanguage;
  final String sttsRecognitionLocale;
  final Map<String, String> sttsRecognitionLocales;
  final String? listeningDeviceId;
  final String? playbackDeviceId;
  final ThemeMode themeMode;

  const ProviderSettingsSelection({
    required this.sttProvider,
    required this.translationProvider,
    required this.outputProvider,
    required this.deepgramRecognitionModel,
    required this.deepgramRecognitionLanguage,
    required this.sttsRecognitionLocale,
    required this.sttsRecognitionLocales,
    required this.listeningDeviceId,
    required this.playbackDeviceId,
    required this.themeMode,
  });
}

class ProviderSettingsDialog extends StatefulWidget {
  final SpeechSttProvider initialSttProvider;
  final SpeechTranslationProvider initialTranslationProvider;
  final SpeechOutputProvider initialOutputProvider;
  final String initialDeepgramRecognitionModel;
  final String initialDeepgramRecognitionLanguage;
  final String initialSttsRecognitionLocale;
  final Map<String, String> initialSttsRecognitionLocales;
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
    required this.initialSttsRecognitionLocale,
    required this.initialSttsRecognitionLocales,
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
  late String _selectedSttsRecognitionLocale;
  late Map<String, String> _sttsRecognitionLocales;
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
    _selectedSttsRecognitionLocale = widget.initialSttsRecognitionLocale;
    _sttsRecognitionLocales = Map<String, String>.from(
      widget.initialSttsRecognitionLocales,
    );
    _selectedListeningDeviceId = widget.initialListeningDeviceId;
    _listeningDevices = List<InputDevice>.from(widget.initialListeningDevices);
    _selectedPlaybackDeviceId = widget.initialPlaybackDeviceId;
    _playbackDevices = List<PlaybackDevice>.from(widget.initialPlaybackDevices);
    _selectedThemeMode = widget.initialThemeMode;
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deepgramLanguages =
        DeepgramService
            .supportedRecognitionLanguagesByModel[_selectedDeepgramRecognitionModel] ??
        DeepgramService.supportedRecognitionLanguagesByModel[DeepgramService
            .defaultRecognitionModel]!;

    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        title: const Text('Settings'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Providers'),
                  Tab(text: 'Audio'),
                  Tab(text: 'Display'),
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
                          const Text('Providers'),
                          const SizedBox(height: 12),
                          const Text('Speech to Text'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<SpeechSttProvider>(
                            initialValue: _selectedSttProvider,
                            isExpanded: true,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedSttProvider = value;
                                if (value != SpeechSttProvider.deepgram) {
                                  _selectedListeningDeviceId = null;
                                }
                              });
                            },
                            items: SpeechSttProvider.values
                                .map(
                                  (provider) =>
                                      DropdownMenuItem<SpeechSttProvider>(
                                        value: provider,
                                        child: Text(provider.label),
                                      ),
                                )
                                .toList(),
                          ),
                          if (_selectedSttProvider ==
                              SpeechSttProvider.deepgram) ...[
                            const SizedBox(height: 16),
                            const Text('Deepgram Model'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDeepgramRecognitionModel,
                              isExpanded: true,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedDeepgramRecognitionModel = value;
                                  final supportedValues =
                                      (DeepgramService
                                                  .supportedRecognitionLanguagesByModel[value] ??
                                              const <String, String>{})
                                          .values
                                          .toSet();
                                  if (!supportedValues.contains(
                                    _selectedDeepgramRecognitionLanguage,
                                  )) {
                                    _selectedDeepgramRecognitionLanguage =
                                        DeepgramService.defaultRecognitionLanguageForModel(
                                          value,
                                        );
                                  }
                                });
                              },
                              items: DeepgramService.supportedRecognitionModels
                                  .map(
                                    (model) => DropdownMenuItem<String>(
                                      value: model,
                                      child: Text(model),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            const Text('Deepgram Language'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  _selectedDeepgramRecognitionLanguage,
                              isExpanded: true,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedDeepgramRecognitionLanguage = value;
                                });
                              },
                              items: deepgramLanguages.entries
                                  .map(
                                    (entry) => DropdownMenuItem<String>(
                                      value: entry.value,
                                      child: Text(entry.key),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (_selectedSttProvider ==
                              SpeechSttProvider.stts) ...[
                            const SizedBox(height: 16),
                            const Text('STTS Locale'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSttsRecognitionLocale,
                              isExpanded: true,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedSttsRecognitionLocale = value;
                                });
                              },
                              items: _sttsRecognitionLocales.entries
                                  .map(
                                    (entry) => DropdownMenuItem<String>(
                                      value: entry.value,
                                      child: Text(entry.key),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text('Translation'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<SpeechTranslationProvider>(
                            initialValue: _selectedTranslationProvider,
                            isExpanded: true,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedTranslationProvider = value;
                              });
                            },
                            items: SpeechTranslationProvider.values
                                .map(
                                  (provider) =>
                                      DropdownMenuItem<
                                        SpeechTranslationProvider
                                      >(
                                        value: provider,
                                        child: Text(provider.label),
                                      ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text('Text to Speech'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<SpeechOutputProvider>(
                            initialValue: _selectedOutputProvider,
                            isExpanded: true,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedOutputProvider = value;
                              });
                            },
                            items: SpeechOutputProvider.values
                                .map(
                                  (provider) =>
                                      DropdownMenuItem<SpeechOutputProvider>(
                                        value: provider,
                                        child: Text(provider.label),
                                      ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Audio'),
                          const SizedBox(height: 12),
                          const Text('Listening Device'),
                          const SizedBox(height: 8),
                          if (_selectedSttProvider !=
                              SpeechSttProvider.deepgram)
                            const Text(
                              'Audio input selection is available when Speech to Text is set to Deepgram.',
                            )
                          else if (_listeningDevices.isEmpty)
                            const Text('No input devices detected')
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
                                    ? 'Auto (${_listeningDevices.first.label.isNotEmpty ? _listeningDevices.first.label : _listeningDevices.first.id})'
                                    : selected.label.isNotEmpty
                                    ? selected.label
                                    : selected.id;

                                return Text('Current: $details');
                              },
                            ),
                            if (_listeningDevices.length > 1) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedListeningDeviceId,
                                isExpanded: true,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedListeningDeviceId = value;
                                  });
                                },
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Auto'),
                                  ),
                                  ..._listeningDevices.map(
                                    (device) => DropdownMenuItem<String>(
                                      value: device.id,
                                      child: Text(
                                        device.label.isNotEmpty
                                            ? device.label
                                            : device.id,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text('Playback Device'),
                          const SizedBox(height: 8),
                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Some iOS playback routes are managed by the system and may not always switch programmatically.',
                              ),
                            ),
                          if (_playbackDevices.isEmpty)
                            const Text(
                              'Playback device details unavailable on this platform.',
                            )
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

                                return Text('Current: $details');
                              },
                            ),
                            if (_playbackDevices.length > 1) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedPlaybackDeviceId,
                                isExpanded: true,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPlaybackDeviceId = value;
                                  });
                                },
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Auto'),
                                  ),
                                  ..._playbackDevices.map(
                                    (device) => DropdownMenuItem<String>(
                                      value: device.id,
                                      child: Text(device.details),
                                    ),
                                  ),
                                ],
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
                          const Text('Display'),
                          const SizedBox(height: 12),
                          const Text('Theme Mode'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ThemeMode>(
                            initialValue: _selectedThemeMode,
                            isExpanded: true,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedThemeMode = value;
                              });
                            },
                            items: ThemeMode.values
                                .map(
                                  (mode) => DropdownMenuItem<ThemeMode>(
                                    value: mode,
                                    child: Text(_themeModeLabel(mode)),
                                  ),
                                )
                                .toList(),
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
            child: const Text('Cancel'),
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
                  sttsRecognitionLocale: _selectedSttsRecognitionLocale,
                  sttsRecognitionLocales: _sttsRecognitionLocales,
                  listeningDeviceId: _selectedListeningDeviceId,
                  playbackDeviceId: _selectedPlaybackDeviceId,
                  themeMode: _selectedThemeMode,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late SpeechController _controller;
  late TwoWayChatController _twoWayController;
  StreamSubscription<String>? _listeningDeviceUpdateSub;
  late final DebouncedMessageDispatcher _listeningDeviceSnackBarDebouncer;
  bool _missingKeys = false;
  bool _initializing = true;
  String _deepgramApiKey = '';
  String _googleApiKey = '';
  int _selectedSection = 0;
  SpeechOutputProvider _outputProvider = SpeechOutputProvider.google;
  SpeechSttProvider _sttProvider = SpeechSttProvider.deepgram;
  SpeechTranslationProvider _translationProvider =
      SpeechTranslationProvider.google;
  String _deepgramRecognitionModel = DeepgramService.defaultRecognitionModel;
  String _deepgramRecognitionLanguage =
      DeepgramService.defaultRecognitionLanguage;
  String _sttsRecognitionLocale = SttsService.defaultRecognitionLanguage;
  Map<String, String> _sttsRecognitionLocales = const {
    'Multi (Auto)': SttsService.defaultRecognitionLanguage,
  };
  List<InputDevice> _listeningDevices = const [];
  List<PlaybackDevice> _playbackDevices = const [];
  String? _listeningDeviceId;
  String? _playbackDeviceId;

  bool get _isGroupSection => _selectedSection == 0;

  void _showDebouncedListeningDeviceSnackBar(String message) {
    _listeningDeviceSnackBarDebouncer.schedule(message);
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

  void _setDeepgramRecognitionLanguage(String language) {
    if (_deepgramRecognitionLanguage == language || _initializing) return;
    setState(() {
      _deepgramRecognitionLanguage = language;
      _controller.setDeepgramRecognitionLanguage(language);
      _twoWayController.setDeepgramRecognitionLanguage(language);
    });
  }

  void _setSttsRecognitionLocale(String locale) {
    if (_sttsRecognitionLocale == locale || _initializing) return;
    setState(() {
      _sttsRecognitionLocale = locale;
      _controller.setSttsRecognitionLocale(locale);
      _twoWayController.setSttsRecognitionLocale(locale);
    });
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
          const SnackBar(
            content: Text('Unable to switch playback device on this platform.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _showProviderSettingsDialog() async {
    if (_initializing) return;

    await _controller.refreshListeningDevices();
    await _controller.refreshPlaybackDevices();
    await _controller.refreshSttsRecognitionLocales();
    if (!mounted) return;
    setState(() {
      _listeningDevices = _controller.listeningDevices;
      _listeningDeviceId = _controller.listeningDeviceId;
      _playbackDevices = _controller.playbackDevices;
      _playbackDeviceId = _controller.playbackDeviceId;
      _sttsRecognitionLocales = _controller.sttsRecognitionLocales;
      _sttsRecognitionLocale = _controller.sttsRecognitionLocale;
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
          initialSttsRecognitionLocale: _sttsRecognitionLocale,
          initialSttsRecognitionLocales: _sttsRecognitionLocales,
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
      _setDeepgramRecognitionLanguage(selection.deepgramRecognitionLanguage);
    }
    if (selection.sttsRecognitionLocale != _sttsRecognitionLocale) {
      _setSttsRecognitionLocale(selection.sttsRecognitionLocale);
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

    final targetLanguages = SpeechController.supportedLanguages.values.toSet();
    final sourceValues = sourceLanguages.values.toSet();

    final supportsCurrentDirection =
        sourceValues.contains(source) && targetLanguages.contains(target);
    final supportsSwappedDirection =
        sourceValues.contains(target) && targetLanguages.contains(source);

    return supportsCurrentDirection && supportsSwappedDirection;
  }

  void _swapGroupLanguages(Map<String, String> sourceLanguages) {
    if (!_canSwapGroupLanguages(sourceLanguages)) return;

    final source = _controller.deepgramRecognitionLanguage;
    final target = _controller.targetLanguage;

    if (source == target) return;

    setState(() {
      _deepgramRecognitionLanguage = target;
      _controller.setDeepgramRecognitionLanguage(target);
      _twoWayController.setDeepgramRecognitionLanguage(target);
      _controller.setTargetLanguage(source);
    });
  }

  Widget _buildGroupLanguageBar(ThemeData theme) {
    final tokens = resolveAppThemeTokens(theme);
    final sourceLanguages = _controller.deepgramRecognitionLanguages;
    final targetLanguages = SpeechController.supportedLanguages;
    final canSwap = _canSwapGroupLanguages(sourceLanguages);

    final sourceCode = _controller.deepgramRecognitionLanguage;
    final targetCode = _controller.targetLanguage;

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
            child: DropdownButtonFormField<String>(
              initialValue: sourceCode,
              icon: const SizedBox.shrink(),
              decoration: InputDecoration(
                labelText: 'Source',
                labelStyle: const TextStyle(fontSize: 12),
                floatingLabelStyle: const TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
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
              ),
              items: sourceLanguages.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.value,
                      child: Text(entry.key),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null || value == sourceCode) return;
                _setDeepgramRecognitionLanguage(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: canSwap
                ? 'Swap source and target language'
                : (sourceCode == 'multi' || targetCode == 'multi'
                      ? 'Swap unavailable when source or target is multi'
                      : 'Swap unavailable for selected language pair'),
            onPressed: canSwap
                ? () => _swapGroupLanguages(sourceLanguages)
                : null,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: targetCode,
              icon: const SizedBox.shrink(),
              decoration: InputDecoration(
                labelText: 'Target',
                labelStyle: const TextStyle(fontSize: 12),
                floatingLabelStyle: const TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
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
              ),
              items: targetLanguages.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.value,
                      child: Text(entry.key),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null || value == targetCode) return;
                setState(() {
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
    // supply your Google Cloud API key and a Deepgram API key via
    // environment variables.  For example:
    //   flutter run \
    //     --dart-define=GOOGLE_API_KEY=your_key \
    //     --dart-define=DEEPGRAM_API_KEY=your_key
    _deepgramApiKey = dotenv.get("DEEPGRAM_API_KEY", fallback: "");
    _googleApiKey = dotenv.get("GOOGLE_API_KEY", fallback: "");

    if (_deepgramApiKey.isEmpty || _googleApiKey.isEmpty) {
      _missingKeys = true;
    }

    void createController() {
      setState(() {
        _initializing = true;
      });
      _controller = SpeechController(
        googleApiKey: _googleApiKey,
        deepgramApiKey: _deepgramApiKey,
      );
      _bindListeningDeviceNotifications();
      _controller.setSttProvider(_sttProvider);
      _controller.setTranslationProvider(_translationProvider);
      _controller.setDeepgramRecognitionModel(_deepgramRecognitionModel);
      _controller.setDeepgramRecognitionLanguage(_deepgramRecognitionLanguage);
      _controller.setSttsRecognitionLocale(_sttsRecognitionLocale);
      _twoWayController = TwoWayChatController(
        googleApiKey: _googleApiKey,
        deepgramApiKey: _deepgramApiKey,
      );
      _twoWayController.setSttProvider(_sttProvider);
      _twoWayController.setTranslationProvider(_translationProvider);
      _twoWayController.setDeepgramRecognitionModel(_deepgramRecognitionModel);
      _twoWayController.setDeepgramRecognitionLanguage(
        _deepgramRecognitionLanguage,
      );
      _twoWayController.setSttsRecognitionLocale(_sttsRecognitionLocale);
      Future.wait([_controller.init(), _twoWayController.init()]).then((_) {
        if (!mounted) return;
        setState(() {
          _listeningDevices = _controller.listeningDevices;
          _listeningDeviceId = _controller.listeningDeviceId;
          _playbackDevices = _controller.playbackDevices;
          _playbackDeviceId = _controller.playbackDeviceId;
          _sttsRecognitionLocales = _controller.sttsRecognitionLocales;
          _sttsRecognitionLocale = _controller.sttsRecognitionLocale;
          _initializing = false;
        });
      });
    }

    if (_missingKeys) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) {
            final deepgramField = TextEditingController(text: _deepgramApiKey);
            final googleField = TextEditingController(text: _googleApiKey);
            return AlertDialog(
              title: Text('Missing API Keys'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Please provide both Deepgram and Google API keys to continue.',
                  ),
                  TextField(
                    controller: deepgramField,
                    decoration: InputDecoration(labelText: 'Deepgram API Key'),
                  ),
                  TextField(
                    controller: googleField,
                    decoration: InputDecoration(labelText: 'Google API Key'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _deepgramApiKey = deepgramField.text.trim();
                      _googleApiKey = googleField.text.trim();
                      _missingKeys = false;
                    });
                    createController();
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      });
    } else {
      createController();
    }
  }

  @override
  void dispose() {
    _listeningDeviceUpdateSub?.cancel();
    _listeningDeviceSnackBarDebouncer.dispose();
    _controller.dispose();
    _twoWayController.dispose();
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
                child: Icon(
                  Icons.translate_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Translation Studio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text('Real-time assistant', style: textRoles.appSubtitle),
                ],
              ),
            ],
          ),
          actions: [
            if (!_initializing)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
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
                              horizontal: 16.0,
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
                        horizontal: 16.0,
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
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.group_rounded),
                      label: 'Group',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.compare_arrows_rounded),
                      label: '2-way',
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

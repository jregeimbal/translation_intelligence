import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'controllers/speech_controller.dart';
import 'controllers/two_way_chat_controller.dart';
import 'services/speech_output_provider.dart';
import 'services/speech_stt_provider.dart';
import 'services/speech_translation_provider.dart';
import 'theme/app_theme_resolver.dart';
import 'theme/hyper_linguist_theme.dart';
import 'theme/hyper_listen_theme.dart';
import 'widgets/chat_control_bar.dart';
import 'widgets/chat_message.dart';
import 'widgets/footer.dart';
import 'widgets/two_way_chat.dart';

void main() async {
  await dotenv.load();

  Logger.root.level = Level.ALL; // This will only show WARNING and SEVERE logs
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
  ThemeMode _themeMode = ThemeMode.dark;
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

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
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
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MyHomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late SpeechController _controller;
  late TwoWayChatController _twoWayController;
  bool _missingKeys = false;
  bool _initializing = true;
  String _deepgramApiKey = '';
  String _googleApiKey = '';
  int _selectedSection = 0;
  SpeechOutputProvider _outputProvider = SpeechOutputProvider.google;
  SpeechSttProvider _sttProvider = SpeechSttProvider.deepgram;
  SpeechTranslationProvider _translationProvider =
      SpeechTranslationProvider.google;

  bool get _isGroupSection => _selectedSection == 0;

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

  Future<void> _onSectionSelected(int index) async {
    if (_selectedSection == index) return;

    if (_selectedSection == 0 && !_initializing && _controller.isListening) {
      try {
        await _controller.stopListening();
      } catch (_) {}
    }
    if (_selectedSection == 1 && !_initializing && _twoWayController.isListening) {
      try {
        await _twoWayController.stopListening();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _selectedSection = index;
    });
  }

  @override
  void initState() {
    super.initState();
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
      _controller.setSttProvider(_sttProvider);
      _controller.setTranslationProvider(_translationProvider);
      _twoWayController = TwoWayChatController(
        googleApiKey: _googleApiKey,
        deepgramApiKey: _deepgramApiKey,
      );
      _twoWayController.setSttProvider(_sttProvider);
      _twoWayController.setTranslationProvider(_translationProvider);
      Future.wait([_controller.init(), _twoWayController.init()]).whenComplete(() {
        setState(() {
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
                  const Text('Translation Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('Real-time assistant', style: textRoles.appSubtitle),
                ],
              ),
            ],
          ),
          actions: [
            if (_isGroupSection && !_initializing)
              PopupMenuButton<String>(
                icon: const Icon(Icons.language_outlined),
                tooltip: 'Translation language',
                onSelected: (code) {
                  setState(() {
                    _controller.setTargetLanguage(code);
                  });
                },
                itemBuilder: (context) {
                  return SpeechController.supportedLanguages.entries
                      .map(
                        (entry) => PopupMenuItem<String>(
                          value: entry.value,
                          child: Text(entry.key),
                        ),
                      )
                      .toList();
                },
              ),
            if (!_initializing)
              PopupMenuButton<SpeechTranslationProvider>(
                icon: const Icon(Icons.g_translate_rounded),
                tooltip: 'Translation provider',
                initialValue: _translationProvider,
                onSelected: _setTranslationProvider,
                itemBuilder: (context) {
                  return SpeechTranslationProvider.values
                      .map(
                        (provider) => PopupMenuItem<SpeechTranslationProvider>(
                          value: provider,
                          child: Text(provider.label),
                        ),
                      )
                      .toList();
                },
              ),
            if (!_initializing)
              PopupMenuButton<SpeechSttProvider>(
                icon: const Icon(Icons.mic_external_on_outlined),
                tooltip: 'STT provider',
                initialValue: _sttProvider,
                onSelected: (provider) {
                  _setSttProvider(provider);
                },
                itemBuilder: (context) {
                  return SpeechSttProvider.values
                      .map(
                        (provider) => PopupMenuItem<SpeechSttProvider>(
                          value: provider,
                          child: Text(provider.label),
                        ),
                      )
                      .toList();
                },
              ),
            if (!_initializing)
              PopupMenuButton<SpeechOutputProvider>(
                icon: const Icon(Icons.record_voice_over_outlined),
                tooltip: 'TTS provider',
                initialValue: _outputProvider,
                onSelected: _setOutputProvider,
                itemBuilder: (context) {
                  return SpeechOutputProvider.values
                      .map(
                        (provider) => PopupMenuItem<SpeechOutputProvider>(
                          value: provider,
                          child: Text(provider.label),
                        ),
                      )
                      .toList();
                },
              ),
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              tooltip: 'Toggle theme',
              onPressed: widget.onToggleTheme,
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
                          child: const Column(
                            children: [
                              Expanded(
                                child: ChatMessageList(),
                              ),
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
                    child: const ChatControlBar(),
                  ),
                  const SizedBox(height: 8),
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

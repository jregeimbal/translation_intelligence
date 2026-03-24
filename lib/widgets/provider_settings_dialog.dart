import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../l10n/app_localizations_ext.dart';
import '../models/playback_device.dart';
import '../models/provider_settings_selection.dart';
import '../services/deepgram_recognition_catalog.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

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
                              padding: const EdgeInsets.only(bottom: 8),
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

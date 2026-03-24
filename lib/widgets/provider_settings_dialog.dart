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
  final String initialTargetLanguage;
  final List<String> targetLanguages;
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
    required this.initialTargetLanguage,
    required this.targetLanguages,
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
  late String _selectedTargetLanguage;
  late String _selectedDeepgramRecognitionModel;
  late String _selectedDeepgramRecognitionLanguage;
  late String _selectedSpeechToTextRecognitionLocale;
  late Map<String, String> _speechToTextRecognitionLocales;
  late String? _selectedListeningDeviceId;
  late List<InputDevice> _listeningDevices;
  late String? _selectedPlaybackDeviceId;
  late List<PlaybackDevice> _playbackDevices;
  late ThemeMode _selectedThemeMode;
  late bool _showAdvancedOptions;
  String? _modelAdjustmentNotice;

  @override
  void initState() {
    super.initState();
    _selectedSttProvider = widget.initialSttProvider;
    _selectedTranslationProvider = widget.initialTranslationProvider;
    _selectedOutputProvider = widget.initialOutputProvider;
    _selectedTargetLanguage = widget.initialTargetLanguage;
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
    _showAdvancedOptions =
      widget.initialSttProvider != SpeechSttProvider.deepgram ||
      widget.initialTranslationProvider != SpeechTranslationProvider.google ||
      widget.initialOutputProvider != SpeechOutputProvider.google ||
      widget.initialDeepgramRecognitionModel !=
        DeepgramRecognitionCatalog.defaultRecognitionModel;
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

  Map<String, String> get _deepgramLanguages =>
      DeepgramRecognitionCatalog
          .supportedRecognitionLanguagesByModel[_selectedDeepgramRecognitionModel] ??
      DeepgramRecognitionCatalog.supportedRecognitionLanguagesByModel[
          DeepgramRecognitionCatalog.defaultRecognitionModel]!;

  List<DropdownMenuEntry<String>> _sourceLanguageEntries() {
    if (_selectedSttProvider == SpeechSttProvider.google) {
      return _speechToTextRecognitionLocales.entries
          .map(
            (entry) => DropdownMenuEntry<String>(
              value: entry.value,
              label: localizedRecognitionLocaleLabel(context, entry.value),
            ),
          )
          .toList(growable: false);
    }

    return _deepgramLanguages.entries
        .map(
          (entry) => DropdownMenuEntry<String>(
            value: entry.value,
            label: localizedDeepgramLanguageLabel(context, entry.value),
          ),
        )
        .toList(growable: false);
  }

  String get _selectedSourceLanguage =>
      _selectedSttProvider == SpeechSttProvider.google
      ? _selectedSpeechToTextRecognitionLocale
      : _selectedDeepgramRecognitionLanguage;

  void _setSelectedSourceLanguage(String value) {
    setState(() {
      if (_selectedSttProvider == SpeechSttProvider.google) {
        _selectedSpeechToTextRecognitionLocale = value;
      } else {
        _selectedDeepgramRecognitionLanguage = value;
      }
    });
  }

  void _handleDeepgramModelSelection(String value) {
    final supportedValues =
      (DeepgramRecognitionCatalog.supportedRecognitionLanguagesByModel[value] ??
          const <String, String>{})
        .values
        .toSet();
    var nextLanguage = _selectedDeepgramRecognitionLanguage;
    String? adjustmentNotice;

    if (!supportedValues.contains(_selectedDeepgramRecognitionLanguage)) {
      nextLanguage =
          DeepgramRecognitionCatalog.defaultRecognitionLanguageForModel(value);
      adjustmentNotice = context.l10n.settingsModelAdjustedLanguage(
        localizedDeepgramLanguageLabel(context, nextLanguage),
      );
    }

    setState(() {
      _selectedDeepgramRecognitionModel = value;
      _selectedDeepgramRecognitionLanguage = nextLanguage;
      _modelAdjustmentNotice = adjustmentNotice;
    });
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(ThemeData theme, String label, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildSpacing() => const SizedBox(height: 18);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dropdownTextStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 18);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(
                ProviderSettingsSelection(
                  sttProvider: _selectedSttProvider,
                  translationProvider: _selectedTranslationProvider,
                  outputProvider: _selectedOutputProvider,
                  targetLanguage: _selectedTargetLanguage,
                  deepgramRecognitionModel: _selectedDeepgramRecognitionModel,
                  deepgramRecognitionLanguage:
                      _selectedDeepgramRecognitionLanguage,
                  speechToTextRecognitionLocale:
                      _selectedSpeechToTextRecognitionLocale,
                  speechToTextRecognitionLocales:
                      _speechToTextRecognitionLocales,
                  listeningDeviceId:
                      _selectedSttProvider == SpeechSttProvider.deepgram
                      ? _selectedListeningDeviceId
                      : null,
                  playbackDeviceId: _selectedPlaybackDeviceId,
                  themeMode: _selectedThemeMode,
                ),
              );
            },
            child: Text(l10n.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildSectionCard(
              theme: theme,
              title: l10n.settingsQuickSettingsTitle,
              subtitle: l10n.settingsQuickSettingsDescription,
              children: [
                _buildFieldLabel(
                  theme,
                  l10n.sourceLabel,
                  hint: l10n.sourceLanguageHint,
                ),
                DropdownMenuFormField<String>(
                  key: ValueKey<String>(
                    'source-${_selectedSttProvider.name}-${_selectedDeepgramRecognitionModel}',
                  ),
                  initialSelection: _selectedSourceLanguage,
                  expandedInsets: EdgeInsets.zero,
                  enableSearch: false,
                  requestFocusOnTap: false,
                  textStyle: dropdownTextStyle,
                  inputDecorationTheme: _dropdownMenuTheme(theme),
                  dropdownMenuEntries: _sourceLanguageEntries(),
                  onSelected: (value) {
                    if (value == null) return;
                    _setSelectedSourceLanguage(value);
                  },
                ),
                _buildSpacing(),
                _buildFieldLabel(
                  theme,
                  l10n.targetLabel,
                  hint: l10n.targetLanguageHint,
                ),
                DropdownMenuFormField<String>(
                  initialSelection: _selectedTargetLanguage,
                  expandedInsets: EdgeInsets.zero,
                  enableSearch: false,
                  requestFocusOnTap: false,
                  textStyle: dropdownTextStyle,
                  inputDecorationTheme: _dropdownMenuTheme(theme),
                  dropdownMenuEntries: widget.targetLanguages
                      .map(
                        (languageCode) => DropdownMenuEntry<String>(
                          value: languageCode,
                          label: localizedAppLanguageName(
                            context,
                            languageCode,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedTargetLanguage = value;
                    });
                  },
                ),
                _buildSpacing(),
                _buildFieldLabel(
                  theme,
                  l10n.listeningDeviceLabel,
                  hint: _selectedSttProvider == SpeechSttProvider.deepgram
                      ? l10n.listeningDeviceHint
                      : l10n.audioInputSelectionHint,
                ),
                if (_selectedSttProvider != SpeechSttProvider.deepgram)
                  Text(l10n.audioInputSelectionHint)
                else if (_listeningDevices.isEmpty)
                  Text(l10n.noInputDevicesDetected)
                else ...[
                  Builder(
                    builder: (context) {
                      final selected = _listeningDevices
                          .where(
                            (device) => device.id == _selectedListeningDeviceId,
                          )
                          .cast<InputDevice?>()
                          .firstWhere((_) => true, orElse: () => null);
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
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              theme: theme,
              title: l10n.tabProviders,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsAdvancedToggle),
                  subtitle: Text(l10n.settingsAdvancedDescription),
                  value: _showAdvancedOptions,
                  onChanged: (value) {
                    setState(() {
                      _showAdvancedOptions = value;
                    });
                  },
                ),
                if (_showAdvancedOptions) ...[
                  _buildSpacing(),
                  _buildFieldLabel(theme, l10n.speechToTextLabel),
                  DropdownMenuFormField<SpeechSttProvider>(
                    initialSelection: _selectedSttProvider,
                    expandedInsets: EdgeInsets.zero,
                    enableSearch: false,
                    requestFocusOnTap: false,
                    textStyle: dropdownTextStyle,
                    inputDecorationTheme: _dropdownMenuTheme(theme),
                    dropdownMenuEntries: SpeechSttProvider.values
                        .map(
                          (provider) => DropdownMenuEntry<SpeechSttProvider>(
                            value: provider,
                            label: localizedSttProviderLabel(
                              context,
                              provider,
                            ),
                          ),
                        )
                        .toList(growable: false),
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
                  if (_selectedSttProvider == SpeechSttProvider.deepgram) ...[
                    _buildSpacing(),
                    _buildFieldLabel(
                      theme,
                      l10n.deepgramModelLabel,
                      hint: l10n.deepgramModelHint,
                    ),
                    DropdownMenuFormField<String>(
                      initialSelection: _selectedDeepgramRecognitionModel,
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
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        _handleDeepgramModelSelection(value);
                      },
                    ),
                    if (_modelAdjustmentNotice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _modelAdjustmentNotice!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                  if (_selectedSttProvider == SpeechSttProvider.google) ...[
                    _buildSpacing(),
                    _buildFieldLabel(theme, l10n.googleLocaleLabel),
                    DropdownMenuFormField<String>(
                      key: const ValueKey<String>('google-locale-settings'),
                      initialSelection: _selectedSpeechToTextRecognitionLocale,
                      expandedInsets: EdgeInsets.zero,
                      enableSearch: false,
                      requestFocusOnTap: false,
                      textStyle: dropdownTextStyle,
                      inputDecorationTheme: _dropdownMenuTheme(theme),
                      dropdownMenuEntries: _speechToTextRecognitionLocales.entries
                          .map(
                            (entry) => DropdownMenuEntry<String>(
                              value: entry.value,
                              label: localizedRecognitionLocaleLabel(
                                context,
                                entry.value,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedSpeechToTextRecognitionLocale = value;
                        });
                      },
                    ),
                  ],
                  _buildSpacing(),
                  _buildFieldLabel(theme, l10n.translationLabel),
                  DropdownMenuFormField<SpeechTranslationProvider>(
                    initialSelection: _selectedTranslationProvider,
                    expandedInsets: EdgeInsets.zero,
                    enableSearch: false,
                    requestFocusOnTap: false,
                    textStyle: dropdownTextStyle,
                    inputDecorationTheme: _dropdownMenuTheme(theme),
                    dropdownMenuEntries: SpeechTranslationProvider.values
                        .map(
                          (provider) => DropdownMenuEntry<SpeechTranslationProvider>(
                            value: provider,
                            label: localizedTranslationProviderLabel(
                              context,
                              provider,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onSelected: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedTranslationProvider = value;
                      });
                    },
                  ),
                  _buildSpacing(),
                  _buildFieldLabel(theme, l10n.textToSpeechLabel),
                  DropdownMenuFormField<SpeechOutputProvider>(
                    initialSelection: _selectedOutputProvider,
                    expandedInsets: EdgeInsets.zero,
                    enableSearch: false,
                    requestFocusOnTap: false,
                    textStyle: dropdownTextStyle,
                    inputDecorationTheme: _dropdownMenuTheme(theme),
                    dropdownMenuEntries: SpeechOutputProvider.values
                        .map(
                          (provider) => DropdownMenuEntry<SpeechOutputProvider>(
                            value: provider,
                            label: localizedOutputProviderLabel(
                              context,
                              provider,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onSelected: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedOutputProvider = value;
                      });
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              theme: theme,
              title: l10n.tabAudio,
              children: [
                _buildFieldLabel(theme, l10n.playbackDeviceLabel),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
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
                            (device) => device.id == _selectedPlaybackDeviceId,
                          )
                          .cast<PlaybackDevice?>()
                          .firstWhere((_) => true, orElse: () => null);
                      final details =
                          selected?.details ?? _playbackDevices.first.details;
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
            const SizedBox(height: 12),
            _buildSectionCard(
              theme: theme,
              title: l10n.tabDisplay,
              children: [
                _buildFieldLabel(theme, l10n.themeModeLabel),
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
                      .toList(growable: false),
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedThemeMode = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

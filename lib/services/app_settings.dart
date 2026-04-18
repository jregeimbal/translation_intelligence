import 'package:flutter/material.dart';

import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

/// Centralized application settings that serve as the single source of truth
/// for provider selections, language preferences, and device IDs.
///
/// The home page creates one instance, passes it to controllers for
/// initialization, and the UI reads from it via `context.watch<AppSettings>()`.
class AppSettings extends ChangeNotifier {
  SpeechSttProvider _sttProvider = SpeechSttProvider.deepgram;
  SpeechTranslationProvider _translationProvider =
      SpeechTranslationProvider.google;
  SpeechOutputProvider _outputProvider = SpeechOutputProvider.google;
  String _deepgramRecognitionModel = '';
  String _deepgramRecognitionLanguage = 'en';
  String _speechToTextRecognitionLocale = 'en';
  String _targetLanguage = 'en';
  String? _listeningDeviceId;
  String? _playbackDeviceId;

  bool _hasSeenAudioPlaybackBluetoothNotice = false;
  bool _hasCompletedFirstLaunchWalkthrough = false;

  // Getters
  SpeechSttProvider get sttProvider => _sttProvider;
  SpeechTranslationProvider get translationProvider => _translationProvider;
  SpeechOutputProvider get outputProvider => _outputProvider;
  String get deepgramRecognitionModel => _deepgramRecognitionModel;
  String get deepgramRecognitionLanguage => _deepgramRecognitionLanguage;
  String get speechToTextRecognitionLocale => _speechToTextRecognitionLocale;
  String get targetLanguage => _targetLanguage;
  String? get listeningDeviceId => _listeningDeviceId;
  String? get playbackDeviceId => _playbackDeviceId;

  bool get hasSeenAudioPlaybackBluetoothNotice =>
      _hasSeenAudioPlaybackBluetoothNotice;
  bool get hasCompletedFirstLaunchWalkthrough =>
      _hasCompletedFirstLaunchWalkthrough;

  /// Apply a persisted preferences snapshot to restore settings.
  void applySnapshot(dynamic snapshot) {
    // Dynamic type because AppPreferences is not imported here to avoid
    // circular dependencies. The home page casts before passing in.
    final deepgramModel = snapshot?.deepgramRecognitionModel ?? '';
    final deepgramLang = snapshot?.deepgramRecognitionLanguage ?? 'en';
    final sttLocale = snapshot?.speechToTextRecognitionLocale ?? 'en';
    final targetLang = snapshot?.targetLanguage ?? 'en';

    if (_deepgramRecognitionModel != deepgramModel) {
      _deepgramRecognitionModel = deepgramModel;
    }
    if (_deepgramRecognitionLanguage != deepgramLang) {
      _deepgramRecognitionLanguage = deepgramLang;
    }
    if (_speechToTextRecognitionLocale != sttLocale) {
      _speechToTextRecognitionLocale = sttLocale;
    }
    if (_targetLanguage != targetLang) {
      _targetLanguage = targetLang;
    }

    final wasSeen = _hasSeenAudioPlaybackBluetoothNotice;
    final wasCompleted = _hasCompletedFirstLaunchWalkthrough;

    if (snapshot != null) {
      _hasSeenAudioPlaybackBluetoothNotice =
          snapshot.hasSeenAudioPlaybackBluetoothNotice;
      _hasCompletedFirstLaunchWalkthrough =
          snapshot.hasCompletedFirstLaunchWalkthrough;
    }

    if (wasSeen != _hasSeenAudioPlaybackBluetoothNotice ||
        wasCompleted != _hasCompletedFirstLaunchWalkthrough) {
      notifyListeners();
    }
  }

  // Provider setters
  void setSttProvider(SpeechSttProvider provider) {
    if (_sttProvider != provider) {
      _sttProvider = provider;
      notifyListeners();
    }
  }

  void setTranslationProvider(SpeechTranslationProvider provider) {
    if (_translationProvider != provider) {
      _translationProvider = provider;
      notifyListeners();
    }
  }

  void setOutputProvider(SpeechOutputProvider provider) {
    if (_outputProvider != provider) {
      _outputProvider = provider;
      notifyListeners();
    }
  }

  // Language setters
  void setDeepgramRecognitionModel(String model) {
    if (_deepgramRecognitionModel != model) {
      _deepgramRecognitionModel = model;
      notifyListeners();
    }
  }

  void setDeepgramRecognitionLanguage(String language) {
    if (_deepgramRecognitionLanguage != language) {
      _deepgramRecognitionLanguage = language;
      notifyListeners();
    }
  }

  void setSpeechToTextRecognitionLocale(String locale) {
    if (_speechToTextRecognitionLocale != locale) {
      _speechToTextRecognitionLocale = locale;
      notifyListeners();
    }
  }

  void setTargetLanguage(String language) {
    if (_targetLanguage != language) {
      _targetLanguage = language;
      notifyListeners();
    }
  }

  // Device setters
  void setListeningDeviceId(String? deviceId) {
    if (_listeningDeviceId != deviceId) {
      _listeningDeviceId = deviceId;
      notifyListeners();
    }
  }

  void setPlaybackDeviceId(String? deviceId) {
    if (_playbackDeviceId != deviceId) {
      _playbackDeviceId = deviceId;
      notifyListeners();
    }
  }

  // UI flags
  void setHasSeenAudioPlaybackBluetoothNotice({required bool value}) {
    if (_hasSeenAudioPlaybackBluetoothNotice != value) {
      _hasSeenAudioPlaybackBluetoothNotice = value;
      notifyListeners();
    }
  }

  void setHasCompletedFirstLaunchWalkthrough({required bool value}) {
    if (_hasCompletedFirstLaunchWalkthrough != value) {
      _hasCompletedFirstLaunchWalkthrough = value;
      notifyListeners();
    }
  }

  /// Apply settings from a [ProviderSettingsSelection] returned by the
  /// provider settings dialog. Returns true if any setting changed.
  bool applySelection(dynamic selection) {
    // Dynamic type to avoid importing ProviderSettingsSelection here.
    if (selection == null) return false;

    var changed = false;

    final newStt = selection.sttProvider;
    if (_sttProvider != newStt) {
      _sttProvider = newStt;
      changed = true;
    }

    final newTranslation = selection.translationProvider;
    if (_translationProvider != newTranslation) {
      _translationProvider = newTranslation;
      changed = true;
    }

    final newOutput = selection.outputProvider;
    if (_outputProvider != newOutput) {
      _outputProvider = newOutput;
      changed = true;
    }

    final newTarget = selection.targetLanguage;
    if (_targetLanguage != newTarget) {
      _targetLanguage = newTarget;
      changed = true;
    }

    final newModel = selection.deepgramRecognitionModel;
    if (_deepgramRecognitionModel != newModel) {
      _deepgramRecognitionModel = newModel;
      changed = true;
    }

    final newLang = selection.deepgramRecognitionLanguage;
    if (_deepgramRecognitionLanguage != newLang) {
      _deepgramRecognitionLanguage = newLang;
      changed = true;
    }

    final newLocale = selection.speechToTextRecognitionLocale;
    if (_speechToTextRecognitionLocale != newLocale) {
      _speechToTextRecognitionLocale = newLocale;
      changed = true;
    }

    final newListeningDevice = selection.listeningDeviceId;
    if (_listeningDeviceId != newListeningDevice) {
      _listeningDeviceId = newListeningDevice;
      changed = true;
    }

    final newPlaybackDevice = selection.playbackDeviceId;
    if (_playbackDeviceId != newPlaybackDevice) {
      _playbackDeviceId = newPlaybackDevice;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }

    return changed;
  }
}

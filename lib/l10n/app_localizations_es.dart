// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'OmniaLingo';

  @override
  String get themeModeSystem => 'Sistema';

  @override
  String get themeModeLight => 'Claro';

  @override
  String get themeModeDark => 'Oscuro';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get tabProviders => 'Proveedores';

  @override
  String get tabAudio => 'Audio';

  @override
  String get tabDisplay => 'Pantalla';

  @override
  String get speechToTextLabel => 'Voz a texto';

  @override
  String get deepgramModelLabel => 'Modelo Deepgram';

  @override
  String get deepgramLanguageLabel => 'Idioma Deepgram';

  @override
  String get googleLocaleLabel => 'Configuración regional de Google';

  @override
  String get translationLabel => 'Traducción';

  @override
  String get textToSpeechLabel => 'Texto a voz';

  @override
  String get listeningDeviceLabel => 'Dispositivo de escucha';

  @override
  String get audioInputSelectionHint => 'La selección de entrada de audio está disponible cuando Voz a texto está configurado en Deepgram.';

  @override
  String get noInputDevicesDetected => 'No se detectaron dispositivos de entrada';

  @override
  String get autoLabel => 'Auto';

  @override
  String currentDetails(Object details) {
    return 'Actual: $details';
  }

  @override
  String autoWithDetails(Object details) {
    return 'Auto ($details)';
  }

  @override
  String get playbackDeviceLabel => 'Dispositivo de reproducción';

  @override
  String get iosPlaybackRoutesHint => 'Algunas rutas de reproducción de iOS son gestionadas por el sistema y pueden no cambiarse siempre de forma programática.';

  @override
  String get playbackUnavailableHint => 'Los detalles del dispositivo de reproducción no están disponibles en esta plataforma.';

  @override
  String get displayLabel => 'Pantalla';

  @override
  String get themeModeLabel => 'Modo de tema';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get multiAuto => 'Multi (Auto)';

  @override
  String get debugAudioStream => 'Depurar flujo de audio';

  @override
  String get debugSection => 'Sección';

  @override
  String get debugSectionGroup => 'Grupo';

  @override
  String get debugSectionTwoWay => 'Bidireccional';

  @override
  String get debugListeningActive => 'Escucha activa';

  @override
  String get yes => 'sí';

  @override
  String get no => 'no';

  @override
  String get notAvailableShort => 'n/d';

  @override
  String get debugSttProvider => 'Proveedor STT';

  @override
  String get debugSourceLanguage => 'Idioma de origen';

  @override
  String get debugResolvedLanguageCode => 'Código de idioma resuelto';

  @override
  String get debugActiveSampleRate => 'Frecuencia de muestreo activa';

  @override
  String sampleRateHertz(Object sampleRate) {
    return '$sampleRate Hz';
  }

  @override
  String get debugListeningDeviceId => 'ID del dispositivo de escucha';

  @override
  String get autoDefault => 'auto/predeterminado';

  @override
  String get debugAmplitude => 'Amplitud (0-1)';

  @override
  String get debugSessionElapsed => 'Sesión transcurrida';

  @override
  String get debugSessionStartedAt => 'Sesión iniciada en';

  @override
  String get debugConfiguredSttProvider => 'Proveedor STT configurado';

  @override
  String get debugConfiguredDeepgramLanguage => 'Idioma Deepgram configurado';

  @override
  String get debugConfiguredGoogleLocale => 'Configuración regional de Google configurada';

  @override
  String get debugConfiguredSttLocale => 'Configuración regional STT configurada';

  @override
  String get close => 'Cerrar';

  @override
  String get unableToSwitchPlaybackDevice => 'No se puede cambiar el dispositivo de reproducción en esta plataforma.';

  @override
  String get sourceLabel => 'Fuente';

  @override
  String get swapLanguagesTooltip => 'Intercambiar idioma de origen y destino';

  @override
  String get swapUnavailableMultiTooltip => 'Intercambio no disponible cuando el origen o destino es múltiple';

  @override
  String get swapUnavailablePairTooltip => 'Intercambio no disponible para el par de idiomas seleccionado';

  @override
  String get targetLabel => 'Destino';

  @override
  String initializationFailed(Object error) {
    return 'Fallo de inicialización: $error';
  }

  @override
  String get retry => 'Reintentar';

  @override
  String get translationAssistant => 'Asistente de traducción';

  @override
  String get groupLabel => 'Grupo';

  @override
  String get twoWayLabel => 'Bidireccional';

  @override
  String get listeningStatus => 'Escuchando...';

  @override
  String get tapMicToStartListening => 'Toca el micrófono para empezar a escuchar...';

  @override
  String get speechNotAvailable => 'Voz no disponible';

  @override
  String speakerLabel(Object number) {
    return 'Altavoz $number';
  }

  @override
  String get hideOriginal => 'Ocultar original';

  @override
  String get showOriginal => 'Mostrar original';

  @override
  String get jumpToLatest => 'Ir al último';

  @override
  String get guestLabel => 'Invitado';

  @override
  String get primaryLabel => 'Principal';

  @override
  String get clearChat => 'Borrar chat';

  @override
  String speakerPanelTitle(Object title) {
    return '$title Altavoz';
  }

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get stopListening => 'Dejar de escuchar';

  @override
  String get listen => 'Escuchar';

  @override
  String get primarySpeakerLabel => 'Altavoz principal';

  @override
  String get noneLabel => 'Ninguno';

  @override
  String get hideTranslationOriginalText => 'Ocultar texto original de la traducción';

  @override
  String get disableAudioPlayback => 'Desactivar reproducción de audio';

  @override
  String get enableAudioPlayback => 'Activar reproducción de audio';

  @override
  String get primarySpeakerInline => 'Altavoz principal';

  @override
  String get noAlignment => 'Sin alineación';

  @override
  String get speechUnavailable => 'Voz no disponible';

  @override
  String get microphoneConnected => 'Micrófono conectado';

  @override
  String get microphoneDisconnected => 'Micrófono desconectado';

  @override
  String get audioRouteChanged => 'Ruta de audio cambiada';

  @override
  String get listeningDeviceListUpdated => 'Lista de dispositivos de escucha actualizada';

  @override
  String messageWithDetails(Object message, Object details) {
    return '$message: $details';
  }

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languageChineseSimplified => 'Chino (Simplificado)';

  @override
  String get languageJapanese => 'Japonés';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languagePortuguese => 'Portugués';

  @override
  String get languageRussian => 'Ruso';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get microphonePermissionDenied => 'Permiso de micrófono denegado';

  @override
  String get invalidSpeechApiKey => 'Clave de API de voz no válida';

  @override
  String get sttProviderDeepgram => 'Deepgram';

  @override
  String get sttProviderGoogle => 'Voz a texto';

  @override
  String get translationProviderGoogle => 'Google Cloud (Backend)';

  @override
  String get translationProviderGoogleMlKit => 'Google ML Kit (heredado)';

  @override
  String get outputProviderGoogle => 'Google';

  @override
  String get outputProviderDeepgram => 'Deepgram';
}

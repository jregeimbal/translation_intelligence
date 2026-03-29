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
  String get settingsQuickSettingsTitle => 'Opciones principales';

  @override
  String get settingsQuickSettingsDescription => 'Elige el idioma que OmniaLingo debe escuchar, el idioma al que debe traducir y el micrófono que debe usar.';

  @override
  String get settingsAdvancedToggle => 'Mostrar opciones avanzadas';

  @override
  String get settingsAdvancedDescription => 'Cambia motores de reconocimiento, traducción o voz solo si necesitas ajustar el comportamiento o resolver un problema.';

  @override
  String get sourceLanguageHint => 'Este es el idioma que OmniaLingo debe escuchar.';

  @override
  String get targetLanguageHint => 'Este es el idioma al que OmniaLingo traduce en el modo Grupo.';

  @override
  String get listeningDeviceHint => 'Déjalo en Auto a menos que quieras forzar un micrófono específico.';

  @override
  String get deepgramModelHint => 'Los distintos modelos de Deepgram admiten distintos idiomas de origen.';

  @override
  String settingsModelAdjustedLanguage(Object language) {
    return 'Este modelo no admite tu idioma de origen anterior, así que OmniaLingo cambió a $language.';
  }

  @override
  String get tabProviders => 'Reconocimiento de voz';

  @override
  String get tabAudio => 'Dispositivos de audio';

  @override
  String get tabDisplay => 'Apariencia';

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
  String get languageSearchHint => 'Buscar idiomas';

  @override
  String get noMatchingLanguages => 'No hay idiomas coincidentes';

  @override
  String get save => 'Guardar';

  @override
  String get multiAuto => 'Multilingual';

  @override
  String get multiAutoDetails => 'English, Spanish, French, German, Hindi, Russian, Portuguese, Japanese, Italian, and Dutch';

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
  String get walkthroughWelcomeTitle => 'Bienvenido a OmniaLingo';

  @override
  String get walkthroughWelcomeBody => 'Aquí tienes un recorrido rápido por lo esencial antes de tu primera conversación.';

  @override
  String get walkthroughDismiss => 'Cerrar recorrido';

  @override
  String get walkthroughHelp => 'Ayuda';

  @override
  String get walkthroughSkip => 'Omitir';

  @override
  String get walkthroughBack => 'Atrás';

  @override
  String get walkthroughNext => 'Siguiente';

  @override
  String get walkthroughGetStarted => 'Comenzar';

  @override
  String get walkthroughModesTitle => 'Elige el modo correcto';

  @override
  String get walkthroughModesBody => 'Usa Grupo cuando una persona o un grupo habla a un micrófono compartido y todos quieren subtítulos traducidos en tiempo real. Usa Bidireccional cuando dos personas se pasan el dispositivo durante una conversación.';

  @override
  String get walkthroughLanguagesTitle => 'Idiomas de origen y destino';

  @override
  String get walkthroughLanguagesBody => 'Origen es el idioma que OmniaLingo escucha. Destino es el idioma al que traduce. En modo bidireccional, cada lado elige su propio idioma para que cada persona siga la conversación en el idioma que prefiera.';

  @override
  String get walkthroughMicrophoneTitle => 'Micrófono y permisos';

  @override
  String get walkthroughMicrophoneBody => 'Toca el botón del micrófono para iniciar o detener la escucha. La primera vez, permite el acceso al micrófono cuando el dispositivo lo solicite. Si antes denegaste el acceso, vuelve a habilitar el micrófono para OmniaLingo en la configuración del dispositivo.';

  @override
  String get walkthroughPrimarySpeakerTitle => 'Qué significa Altavoz principal';

  @override
  String get walkthroughPrimarySpeakerBody => 'En modo Grupo, Altavoz principal resalta los mensajes de una persona y los alinea para que ese lado sea más fácil de seguir. Úsalo cuando quieras que el texto traducido de un participante destaque.';

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
  String get replayTranslation => 'Repetir traduccion';

  @override
  String get jumpToLatest => 'Ir al último';

  @override
  String get suggestedResponseTitle => 'Respuesta sugerida';

  @override
  String suggestedResponseOriginalLabel(Object language) {
    return 'En $language';
  }

  @override
  String suggestedResponseTranslatedLabel(Object language) {
    return 'Traducido para ti ($language)';
  }

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
  String get audioPlaybackBluetoothNotice => 'Para la mejor experiencia, usa la reproducción de audio con un dispositivo bluetooth.';

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
  String get outputProviderGoogle => 'Google';

  @override
  String get outputProviderDeepgram => 'Deepgram';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'OmniaLingo';

  @override
  String get themeModeSystem => 'Système';

  @override
  String get themeModeLight => 'Clair';

  @override
  String get themeModeDark => 'Sombre';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsQuickSettingsTitle => 'Essentiels';

  @override
  String get settingsQuickSettingsDescription => 'Choisissez la langue qu\'OmniaLingo écoute, la langue dans laquelle il traduit et le microphone qu\'il doit utiliser.';

  @override
  String get settingsAdvancedToggle => 'Afficher les options avancées';

  @override
  String get settingsAdvancedDescription => 'Modifiez les moteurs de reconnaissance, de traduction ou de voix uniquement si vous devez dépanner ou affiner le comportement.';

  @override
  String get sourceLanguageHint => 'C\'est la langue qu\'OmniaLingo écoute.';

  @override
  String get targetLanguageHint => 'C\'est la langue dans laquelle OmniaLingo traduit en mode Groupe.';

  @override
  String get listeningDeviceHint => 'Laissez ce réglage sur Auto sauf si vous voulez forcer un microphone précis.';

  @override
  String get deepgramModelHint => 'Différents modèles Deepgram prennent en charge différentes langues source.';

  @override
  String settingsModelAdjustedLanguage(Object language) {
    return 'Ce modèle ne prend pas en charge votre précédente langue source, donc OmniaLingo est passé à $language.';
  }

  @override
  String get tabProviders => 'Reconnaissance vocale';

  @override
  String get tabAudio => 'Appareils audio';

  @override
  String get tabDisplay => 'Apparence';

  @override
  String get speechToTextLabel => 'Reconnaissance vocale';

  @override
  String get deepgramModelLabel => 'Modèle Deepgram';

  @override
  String get deepgramLanguageLabel => 'Langue Deepgram';

  @override
  String get googleLocaleLabel => 'Paramètres régionaux Google';

  @override
  String get translationLabel => 'Traduction';

  @override
  String get textToSpeechLabel => 'Synthèse vocale';

  @override
  String get listeningDeviceLabel => 'Appareil d\'écoute';

  @override
  String get audioInputSelectionHint => 'La sélection de l\'entrée audio est disponible lorsque la reconnaissance vocale est définie sur Deepgram.';

  @override
  String get noInputDevicesDetected => 'Aucun appareil d\'entrée détecté';

  @override
  String get autoLabel => 'Auto';

  @override
  String currentDetails(Object details) {
    return 'Actuel : $details';
  }

  @override
  String autoWithDetails(Object details) {
    return 'Auto ($details)';
  }

  @override
  String get playbackDeviceLabel => 'Appareil de lecture';

  @override
  String get iosPlaybackRoutesHint => 'Certaines routes de lecture iOS sont gérées par le système et peuvent ne pas toujours être modifiées par programmation.';

  @override
  String get playbackUnavailableHint => 'Les détails de l\'appareil de lecture ne sont pas disponibles sur cette plateforme.';

  @override
  String get displayLabel => 'Affichage';

  @override
  String get themeModeLabel => 'Mode du thème';

  @override
  String get cancel => 'Annuler';

  @override
  String get languageSearchHint => 'Rechercher des langues';

  @override
  String get noMatchingLanguages => 'Aucune langue correspondante';

  @override
  String get save => 'Enregistrer';

  @override
  String get multiAuto => 'Multilingual';

  @override
  String get multiAutoDetails => 'English, Spanish, French, German, Hindi, Russian, Portuguese, Japanese, Italian, and Dutch';

  @override
  String get debugAudioStream => 'Déboguer le flux audio';

  @override
  String get debugSection => 'Section';

  @override
  String get debugSectionGroup => 'Groupe';

  @override
  String get debugSectionTwoWay => 'Bidirectionnel';

  @override
  String get debugListeningActive => 'Écoute active';

  @override
  String get yes => 'oui';

  @override
  String get no => 'non';

  @override
  String get notAvailableShort => 'n/d';

  @override
  String get debugSttProvider => 'Fournisseur STT';

  @override
  String get debugSourceLanguage => 'Langue source';

  @override
  String get debugResolvedLanguageCode => 'Code de langue résolu';

  @override
  String get debugActiveSampleRate => 'Taux d\'échantillonnage actif';

  @override
  String sampleRateHertz(Object sampleRate) {
    return '$sampleRate Hz';
  }

  @override
  String get debugListeningDeviceId => 'ID de l\'appareil d\'écoute';

  @override
  String get autoDefault => 'auto/par défaut';

  @override
  String get debugAmplitude => 'Amplitude (0-1)';

  @override
  String get debugSessionElapsed => 'Session écoulée';

  @override
  String get debugSessionStartedAt => 'Session commencée à';

  @override
  String get debugConfiguredSttProvider => 'Fournisseur STT configuré';

  @override
  String get debugConfiguredDeepgramLanguage => 'Langue Deepgram configurée';

  @override
  String get debugConfiguredGoogleLocale => 'Paramètres régionaux Google configurés';

  @override
  String get debugConfiguredSttLocale => 'Paramètres régionaux STT configurés';

  @override
  String get close => 'Fermer';

  @override
  String get unableToSwitchPlaybackDevice => 'Impossible de changer l\'appareil de lecture sur cette plateforme.';

  @override
  String get sourceLabel => 'Source';

  @override
  String get swapLanguagesTooltip => 'Échanger la langue source et cible';

  @override
  String get swapUnavailableMultiTooltip => 'Échange indisponible lorsque la source ou la cible est multiple';

  @override
  String get swapUnavailablePairTooltip => 'Échange indisponible pour la paire de langues sélectionnée';

  @override
  String get targetLabel => 'Cible';

  @override
  String initializationFailed(Object error) {
    return 'Échec de l\'initialisation : $error';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get walkthroughWelcomeTitle => 'Bienvenue dans OmniaLingo';

  @override
  String get walkthroughWelcomeBody => 'Voici une présentation rapide de l\'essentiel avant votre première conversation.';

  @override
  String get walkthroughDismiss => 'Fermer la présentation';

  @override
  String get walkthroughHelp => 'Aide';

  @override
  String get walkthroughSkip => 'Ignorer';

  @override
  String get walkthroughBack => 'Retour';

  @override
  String get walkthroughNext => 'Suivant';

  @override
  String get walkthroughGetStarted => 'Commencer';

  @override
  String get walkthroughModesTitle => 'Choisissez le bon mode';

  @override
  String get walkthroughModesBody => 'Utilisez Groupe lorsqu\'une personne ou un groupe parle dans un microphone partagé et que tout le monde veut des sous-titres traduits en direct. Utilisez Bidirectionnel lorsque deux personnes se passent l\'appareil pendant une conversation.';

  @override
  String get walkthroughLanguagesTitle => 'Langues source et cible';

  @override
  String get walkthroughLanguagesBody => 'La source est la langue qu\'OmniaLingo écoute. La cible est la langue dans laquelle il traduit. En mode bidirectionnel, chaque côté choisit sa propre langue afin que chacun puisse suivre la conversation dans la langue qu\'il préfère.';

  @override
  String get walkthroughMicrophoneTitle => 'Microphone et autorisations';

  @override
  String get walkthroughMicrophoneBody => 'Appuyez sur le bouton du microphone pour démarrer ou arrêter l\'écoute. La première fois, autorisez l\'accès au microphone lorsque l\'appareil le demande. Si l\'accès a déjà été refusé, réactivez le microphone pour OmniaLingo dans les réglages de l\'appareil.';

  @override
  String get walkthroughPrimarySpeakerTitle => 'Que signifie Interlocuteur principal';

  @override
  String get walkthroughPrimarySpeakerBody => 'En mode Groupe, Interlocuteur principal met en évidence les messages d\'une personne et les aligne pour rendre ce côté plus facile à suivre. Choisissez-le lorsque vous souhaitez faire ressortir le texte traduit d\'un participant.';

  @override
  String get translationAssistant => 'Assistant de traduction';

  @override
  String get groupLabel => 'Groupe';

  @override
  String get twoWayLabel => 'Bidirectionnel';

  @override
  String get listeningStatus => 'Écoute...';

  @override
  String get tapMicToStartListening => 'Appuyez sur le micro pour commencer à écouter...';

  @override
  String get speechNotAvailable => 'Reconnaissance vocale non disponible';

  @override
  String speakerLabel(Object number) {
    return 'Haut-parleur $number';
  }

  @override
  String get hideOriginal => 'Masquer l\'original';

  @override
  String get showOriginal => 'Afficher l\'original';

  @override
  String get replayTranslation => 'Relire la traduction';

  @override
  String get jumpToLatest => 'Aller au dernier';

  @override
  String get guestLabel => 'Invité';

  @override
  String get primaryLabel => 'Principal';

  @override
  String get clearChat => 'Effacer la discussion';

  @override
  String speakerPanelTitle(Object title) {
    return '$title Haut-parleur';
  }

  @override
  String get noMessagesYet => 'Aucun message pour le moment';

  @override
  String get stopListening => 'Arrêter d\'écouter';

  @override
  String get listen => 'Écouter';

  @override
  String get primarySpeakerLabel => 'Haut-parleur principal';

  @override
  String get noneLabel => 'Aucun';

  @override
  String get hideTranslationOriginalText => 'Masquer le texte original de la traduction';

  @override
  String get disableAudioPlayback => 'Désactiver la lecture audio';

  @override
  String get enableAudioPlayback => 'Activer la lecture audio';

  @override
  String get primarySpeakerInline => 'Haut-parleur principal';

  @override
  String get noAlignment => 'Aucun alignement';

  @override
  String get speechUnavailable => 'Reconnaissance vocale non disponible';

  @override
  String get microphoneConnected => 'Microphone connecté';

  @override
  String get microphoneDisconnected => 'Microphone déconnecté';

  @override
  String get audioRouteChanged => 'Itinéraire audio modifié';

  @override
  String get listeningDeviceListUpdated => 'Liste des appareils d\'écoute mise à jour';

  @override
  String messageWithDetails(Object message, Object details) {
    return '$message : $details';
  }

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get languageChineseSimplified => 'Chinois (simplifié)';

  @override
  String get languageJapanese => 'Japonais';

  @override
  String get languageKorean => 'Coréen';

  @override
  String get languagePortuguese => 'Portugais';

  @override
  String get languageRussian => 'Russe';

  @override
  String get languageArabic => 'Arabe';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get microphonePermissionDenied => 'Permission du microphone refusée';

  @override
  String get invalidSpeechApiKey => 'Clé API vocale invalide';

  @override
  String get sttProviderDeepgram => 'Deepgram';

  @override
  String get sttProviderGoogle => 'Reconnaissance vocale';

  @override
  String get translationProviderGoogle => 'Google Cloud (Backend)';

  @override
  String get translationProviderGoogleMlKit => 'Google ML Kit (hérité)';

  @override
  String get outputProviderGoogle => 'Google';

  @override
  String get outputProviderDeepgram => 'Deepgram';
}

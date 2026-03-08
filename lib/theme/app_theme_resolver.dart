import 'package:flutter/material.dart';

import 'hyper_linguist_theme.dart';
import 'hyper_listen_theme.dart';

class AppThemeTokens {
  final Color appGradientTop;
  final Color appGradientBottom;
  final Color glassSurface;
  final Color footerSurface;
  final Color bubbleShadow;
  final List<Color> speakerColors;

  const AppThemeTokens({
    required this.appGradientTop,
    required this.appGradientBottom,
    required this.glassSurface,
    required this.footerSurface,
    required this.bubbleShadow,
    required this.speakerColors,
  });
}

class AppThemeTextRoles {
  final TextStyle appSubtitle;
  final TextStyle statusMessage;
  final TextStyle helperText;
  final TextStyle speakerChip;
  final TextStyle timestamp;
  final TextStyle bubbleBody;
  final TextStyle bubbleTranslation;
  final TextStyle errorText;

  const AppThemeTextRoles({
    required this.appSubtitle,
    required this.statusMessage,
    required this.helperText,
    required this.speakerChip,
    required this.timestamp,
    required this.bubbleBody,
    required this.bubbleTranslation,
    required this.errorText,
  });
}

AppThemeTokens resolveAppThemeTokens(ThemeData theme) {
  final linguist = theme.extension<HyperLinguistTokens>();
  if (linguist != null) {
    return AppThemeTokens(
      appGradientTop: linguist.appGradientTop,
      appGradientBottom: linguist.appGradientBottom,
      glassSurface: linguist.glassSurface,
      footerSurface: linguist.footerSurface,
      bubbleShadow: linguist.bubbleShadow,
      speakerColors: linguist.speakerColors,
    );
  }

  final listen =
      theme.extension<HyperListenTokens>() ??
      HyperListenTokens.fromColorScheme(theme.colorScheme);
  return AppThemeTokens(
    appGradientTop: listen.appGradientTop,
    appGradientBottom: listen.appGradientBottom,
    glassSurface: listen.glassSurface,
    footerSurface: listen.footerSurface,
    bubbleShadow: listen.bubbleShadow,
    speakerColors: listen.speakerColors,
  );
}

AppThemeTextRoles resolveAppThemeTextRoles(ThemeData theme) {
  final linguist = theme.extension<HyperLinguistTextRoles>();
  if (linguist != null) {
    return AppThemeTextRoles(
      appSubtitle: linguist.appSubtitle,
      statusMessage: linguist.statusMessage,
      helperText: linguist.helperText,
      speakerChip: linguist.speakerChip,
      timestamp: linguist.timestamp,
      bubbleBody: linguist.bubbleBody,
      bubbleTranslation: linguist.bubbleTranslation,
      errorText: linguist.errorText,
    );
  }

  final listen =
      theme.extension<HyperListenTextRoles>() ??
      HyperListenTextRoles.fromTheme(
        textTheme: theme.textTheme,
        colorScheme: theme.colorScheme,
      );
  return AppThemeTextRoles(
    appSubtitle: listen.appSubtitle,
    statusMessage: listen.statusMessage,
    helperText: listen.helperText,
    speakerChip: listen.speakerChip,
    timestamp: listen.timestamp,
    bubbleBody: listen.bubbleBody,
    bubbleTranslation: listen.bubbleTranslation,
    errorText: listen.errorText,
  );
}

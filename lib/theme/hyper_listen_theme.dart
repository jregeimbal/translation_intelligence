import 'package:flutter/material.dart';

class HyperListenTheme {
  static const Color _seedColor = Color(0xFF00E5FF);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final textTheme = _buildTextTheme(brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: [
        HyperListenTokens.fromColorScheme(colorScheme),
        HyperListenTextRoles.fromTheme(
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 22,
        height: 1.35,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w400,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

@immutable
class HyperListenTextRoles extends ThemeExtension<HyperListenTextRoles> {
  final TextStyle appSubtitle;
  final TextStyle statusMessage;
  final TextStyle helperText;
  final TextStyle speakerChip;
  final TextStyle timestamp;
  final TextStyle bubbleBody;
  final TextStyle bubbleTranslation;
  final TextStyle errorText;

  const HyperListenTextRoles({
    required this.appSubtitle,
    required this.statusMessage,
    required this.helperText,
    required this.speakerChip,
    required this.timestamp,
    required this.bubbleBody,
    required this.bubbleTranslation,
    required this.errorText,
  });

  factory HyperListenTextRoles.fromTheme({
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return HyperListenTextRoles(
      appSubtitle: textTheme.labelMedium!.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      statusMessage: textTheme.bodyLarge!.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontSize: 18,
      ),
      helperText: textTheme.bodyMedium!.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      speakerChip: textTheme.labelMedium!,
      timestamp: textTheme.labelSmall!,
      bubbleBody: textTheme.bodyLarge!,
      bubbleTranslation: textTheme.bodyLarge!.copyWith(
        fontStyle: FontStyle.italic,
      ),
      errorText: textTheme.bodyMedium!.copyWith(color: colorScheme.error),
    );
  }

  @override
  HyperListenTextRoles copyWith({
    TextStyle? appSubtitle,
    TextStyle? statusMessage,
    TextStyle? helperText,
    TextStyle? speakerChip,
    TextStyle? timestamp,
    TextStyle? bubbleBody,
    TextStyle? bubbleTranslation,
    TextStyle? errorText,
  }) {
    return HyperListenTextRoles(
      appSubtitle: appSubtitle ?? this.appSubtitle,
      statusMessage: statusMessage ?? this.statusMessage,
      helperText: helperText ?? this.helperText,
      speakerChip: speakerChip ?? this.speakerChip,
      timestamp: timestamp ?? this.timestamp,
      bubbleBody: bubbleBody ?? this.bubbleBody,
      bubbleTranslation: bubbleTranslation ?? this.bubbleTranslation,
      errorText: errorText ?? this.errorText,
    );
  }

  @override
  HyperListenTextRoles lerp(
    ThemeExtension<HyperListenTextRoles>? other,
    double t,
  ) {
    if (other is! HyperListenTextRoles) {
      return this;
    }
    return HyperListenTextRoles(
      appSubtitle: TextStyle.lerp(appSubtitle, other.appSubtitle, t)!,
      statusMessage: TextStyle.lerp(statusMessage, other.statusMessage, t)!,
      helperText: TextStyle.lerp(helperText, other.helperText, t)!,
      speakerChip: TextStyle.lerp(speakerChip, other.speakerChip, t)!,
      timestamp: TextStyle.lerp(timestamp, other.timestamp, t)!,
      bubbleBody: TextStyle.lerp(bubbleBody, other.bubbleBody, t)!,
      bubbleTranslation: TextStyle.lerp(
        bubbleTranslation,
        other.bubbleTranslation,
        t,
      )!,
      errorText: TextStyle.lerp(errorText, other.errorText, t)!,
    );
  }
}

@immutable
class HyperListenTokens extends ThemeExtension<HyperListenTokens> {
  final Color appGradientTop;
  final Color appGradientBottom;
  final Color glassSurface;
  final Color footerSurface;
  final Color bubbleShadow;
  final List<Color> speakerColors;

  const HyperListenTokens({
    required this.appGradientTop,
    required this.appGradientBottom,
    required this.glassSurface,
    required this.footerSurface,
    required this.bubbleShadow,
    required this.speakerColors,
  });

  factory HyperListenTokens.fromColorScheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return HyperListenTokens(
      appGradientTop: isDark
          ? const Color(0xFF05121F)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
      appGradientBottom: isDark ? const Color(0xFF03070F) : colorScheme.surface,
      glassSurface: isDark
          ? colorScheme.surfaceContainer.withValues(alpha: 0.72)
          : colorScheme.surface.withValues(alpha: 0.9),
      footerSurface: isDark
          ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.94)
          : colorScheme.surfaceContainerLow.withValues(alpha: 0.94),
      bubbleShadow: isDark
          ? colorScheme.primary.withValues(alpha: 0.22)
          : colorScheme.shadow.withValues(alpha: 0.12),
      speakerColors: const [
        Color(0xFF0052CC),
        Color(0xFF7A1FA2),
        Color(0xFF00875A),
        Color(0xFFB54708),
        Color(0xFFC62828),
        Color(0xFF006064),
      ],
    );
  }

  @override
  HyperListenTokens copyWith({
    Color? appGradientTop,
    Color? appGradientBottom,
    Color? glassSurface,
    Color? footerSurface,
    Color? bubbleShadow,
    List<Color>? speakerColors,
  }) {
    return HyperListenTokens(
      appGradientTop: appGradientTop ?? this.appGradientTop,
      appGradientBottom: appGradientBottom ?? this.appGradientBottom,
      glassSurface: glassSurface ?? this.glassSurface,
      footerSurface: footerSurface ?? this.footerSurface,
      bubbleShadow: bubbleShadow ?? this.bubbleShadow,
      speakerColors: speakerColors ?? this.speakerColors,
    );
  }

  @override
  HyperListenTokens lerp(ThemeExtension<HyperListenTokens>? other, double t) {
    if (other is! HyperListenTokens) {
      return this;
    }
    return HyperListenTokens(
      appGradientTop: Color.lerp(appGradientTop, other.appGradientTop, t)!,
      appGradientBottom: Color.lerp(
        appGradientBottom,
        other.appGradientBottom,
        t,
      )!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      footerSurface: Color.lerp(footerSurface, other.footerSurface, t)!,
      bubbleShadow: Color.lerp(bubbleShadow, other.bubbleShadow, t)!,
      speakerColors: List<Color>.generate(
        speakerColors.length,
        (index) => Color.lerp(
          speakerColors[index],
          other.speakerColors[index % other.speakerColors.length],
          t,
        )!,
      ),
    );
  }
}

import 'package:flutter/material.dart';

class HyperLinguistTheme {
  static const Color _seedColor = Color(0xFF4F46E5);

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
          letterSpacing: 0.1,
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
        HyperLinguistTokens.fromColorScheme(colorScheme),
        HyperLinguistTextRoles.fromTheme(
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
class HyperLinguistTextRoles extends ThemeExtension<HyperLinguistTextRoles> {

  const HyperLinguistTextRoles({
    required this.appSubtitle,
    required this.statusMessage,
    required this.helperText,
    required this.speakerChip,
    required this.timestamp,
    required this.bubbleBody,
    required this.bubbleTranslation,
    required this.errorText,
  });

  factory HyperLinguistTextRoles.fromTheme({
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return HyperLinguistTextRoles(
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
  final TextStyle appSubtitle;
  final TextStyle statusMessage;
  final TextStyle helperText;
  final TextStyle speakerChip;
  final TextStyle timestamp;
  final TextStyle bubbleBody;
  final TextStyle bubbleTranslation;
  final TextStyle errorText;

  @override
  HyperLinguistTextRoles copyWith({
    TextStyle? appSubtitle,
    TextStyle? statusMessage,
    TextStyle? helperText,
    TextStyle? speakerChip,
    TextStyle? timestamp,
    TextStyle? bubbleBody,
    TextStyle? bubbleTranslation,
    TextStyle? errorText,
  }) {
    return HyperLinguistTextRoles(
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
  HyperLinguistTextRoles lerp(
    ThemeExtension<HyperLinguistTextRoles>? other,
    double t,
  ) {
    if (other is! HyperLinguistTextRoles) {
      return this;
    }
    return HyperLinguistTextRoles(
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
class HyperLinguistTokens extends ThemeExtension<HyperLinguistTokens> {

  const HyperLinguistTokens({
    required this.appGradientTop,
    required this.appGradientBottom,
    required this.glassSurface,
    required this.footerSurface,
    required this.bubbleShadow,
    required this.speakerColors,
  });

  factory HyperLinguistTokens.fromColorScheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return HyperLinguistTokens(
      appGradientTop: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      ),
      appGradientBottom: colorScheme.surface,
      glassSurface: colorScheme.surface.withValues(alpha: 0.84),
      footerSurface: isDark
          ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.92)
          : colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
      bubbleShadow: colorScheme.shadow.withValues(alpha: 0.12),
      speakerColors: const [
        Color(0xFF0B57D0),
        Color(0xFF6A1B9A),
        Color(0xFF00796B),
        Color(0xFFAD1457),
        Color(0xFF2E7D32),
        Color(0xFF8D6E63),
      ],
    );
  }
  final Color appGradientTop;
  final Color appGradientBottom;
  final Color glassSurface;
  final Color footerSurface;
  final Color bubbleShadow;
  final List<Color> speakerColors;

  @override
  HyperLinguistTokens copyWith({
    Color? appGradientTop,
    Color? appGradientBottom,
    Color? glassSurface,
    Color? footerSurface,
    Color? bubbleShadow,
    List<Color>? speakerColors,
  }) {
    return HyperLinguistTokens(
      appGradientTop: appGradientTop ?? this.appGradientTop,
      appGradientBottom: appGradientBottom ?? this.appGradientBottom,
      glassSurface: glassSurface ?? this.glassSurface,
      footerSurface: footerSurface ?? this.footerSurface,
      bubbleShadow: bubbleShadow ?? this.bubbleShadow,
      speakerColors: speakerColors ?? this.speakerColors,
    );
  }

  @override
  HyperLinguistTokens lerp(
    ThemeExtension<HyperLinguistTokens>? other,
    double t,
  ) {
    if (other is! HyperLinguistTokens) {
      return this;
    }
    return HyperLinguistTokens(
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

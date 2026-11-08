import 'package:flutter/material.dart';

/// The app's one typeface: Geologica, bundled in assets/fonts.
///
/// Chosen because it covers every script we ship in Latin and Cyrillic
/// (Azerbaijani ə and Ə, Turkish ğ ı İ, Ukrainian ґ є ї, the manat sign),
/// has tabular figures for clocks and ratings, and is compact enough for long
/// German and Russian labels. Hindi, Urdu and Chinese fall back to the
/// system font, as they did before.
///
/// [ui] mirrors the old `GoogleFonts.inter(...)` signature so every call
/// site moved over unchanged. Two house rules live here rather than at each
/// call site:
///   • no tracked text: positive letter-spacing is capped at 0.2, so the
///     old all-caps "label" styling cannot creep back in;
///   • the system fallback is always attached.
class AppFonts {
  AppFonts._();

  static const family = 'Geologica';
  static const fallback = <String>['Roboto', 'sans-serif'];

  static double? _tracking(double? v) =>
      v == null ? null : (v > 0.2 ? 0.2 : v);

  static TextStyle ui({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final base = textStyle ?? const TextStyle();
    return base.copyWith(
      fontFamily: family,
      fontFamilyFallback: fallback,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: _tracking(letterSpacing ?? base.letterSpacing),
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Applies the family to a whole Material text theme.
  static TextTheme textTheme(TextTheme base) => base.apply(
        fontFamily: family,
        fontFamilyFallback: fallback,
      );
}

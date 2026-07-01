import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography stack:
///   Display / Headline  →  Fraunces (italic serif)
///   Body / Label / UI   →  Inter (geometric sans)
///   Numbers / Moves     →  JetBrains Mono
class AppTextStyles {
  AppTextStyles._();

  // ─── Base font getters ────────────────────────────────────────────────────

  static TextStyle get _fraunces => GoogleFonts.fraunces().copyWith(
        fontFamilyFallback: const ['Georgia', 'serif'],
      );

  static TextStyle get _inter => GoogleFonts.inter().copyWith(
        fontFamilyFallback: const ['Roboto', 'sans-serif'],
      );

  static TextStyle get _mono => GoogleFonts.jetBrainsMono().copyWith(
        fontFamilyFallback: const ['Courier New', 'monospace'],
      );

  // ─── Display  (Fraunces italic) ───────────────────────────────────────────

  static TextStyle get displayLarge => _fraunces.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
        letterSpacing: -0.5,
        height: 1.15,
      );

  static TextStyle get displayMedium => _fraunces.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
        letterSpacing: -0.3,
        height: 1.2,
      );

  // ─── Headline  (Fraunces italic) ─────────────────────────────────────────

  static TextStyle get headlineLarge => _fraunces.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
      );

  static TextStyle get headlineMedium => _fraunces.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
      );

  static TextStyle get headlineSmall => _fraunces.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
      );

  // ─── Title  (Inter semi-bold) ─────────────────────────────────────────────

  static TextStyle get titleLarge => _inter.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get titleMedium => _inter.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get titleSmall => _inter.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.1,
      );

  // ─── Body  (Inter regular) ────────────────────────────────────────────────

  static TextStyle get bodyLarge => _inter.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      );

  static TextStyle get bodyMedium => _inter.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      );

  static TextStyle get bodySmall => _inter.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.inkDim,
      );

  // ─── Label  (Inter medium, uppercase-ready) ───────────────────────────────

  static TextStyle get labelLarge => _inter.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        letterSpacing: 0.5,
      );

  static TextStyle get labelMedium => _inter.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.inkDim,
        letterSpacing: 0.4,
      );

  static TextStyle get labelSmall => _inter.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.inkMute,
        letterSpacing: 0.6,
      );

  // ─── Mono  (JetBrains Mono) ───────────────────────────────────────────────

  /// Big rating number — e.g. "1 847"
  static TextStyle get ratingLarge => _mono.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -1,
      );

  static TextStyle get ratingMedium => _mono.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.5,
      );

  static TextStyle get ratingSmall => _mono.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  /// Move list item — "e4", "Nf3", etc.
  static TextStyle get monoMove => _mono.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        letterSpacing: 0.2,
      );

  /// Smaller mono text — ELO badges, chip labels
  static TextStyle get monoSmall => _mono.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.inkDim,
        letterSpacing: 0.3,
      );

  // ─── Buttons  (Inter semi-bold) ───────────────────────────────────────────

  static TextStyle get buttonLarge => _inter.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.3,
      );

  static TextStyle get buttonMedium => _inter.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.2,
      );

  // ─── Legacy aliases (keep old callers compiling) ─────────────────────────

  /// Equivalent of old chapterTitle
  static TextStyle get chapterTitle => _fraunces.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
      );
}

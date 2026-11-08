import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

/// Typography: one family, Geologica (see app_fonts.dart), sentence case,
/// no tracking on small text.
///
///   Display / Headline  →  Bold–ExtraBold, slightly tightened
///   Title / Body / Label →  Regular–SemiBold
///   Numbers             →  tabular figures, so clocks and ratings never jitter
class AppTextStyles {
  AppTextStyles._();

  /// Fixed-width digits so ratings, clocks and counters do not jitter.
  static const tabularFigures = [FontFeature.tabularFigures()];

  // ─── Base font getters ────────────────────────────────────────────────────

  static TextStyle get _base => AppFonts.ui().copyWith(
        fontFamilyFallback: const ['Roboto', 'sans-serif'],
      );

  static TextStyle get _numeric => _base.copyWith(
        fontFeatures: tabularFigures,
      );

  // ─── Display ──────────────────────────────────────────────────────────────

  static TextStyle get displayLarge => _base.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.6,
        height: 1.2,
      );

  static TextStyle get displayMedium => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.4,
        height: 1.25,
      );

  // ─── Headline ─────────────────────────────────────────────────────────────

  static TextStyle get headlineLarge => _base.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get headlineMedium => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.2,
      );

  static TextStyle get headlineSmall => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  // ─── Title ────────────────────────────────────────────────────────────────

  static TextStyle get titleLarge => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get titleMedium => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get titleSmall => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.1,
      );

  // ─── Body ─────────────────────────────────────────────────────────────────

  static TextStyle get bodyLarge => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      );

  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      );

  static TextStyle get bodySmall => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.inkDim,
      );

  // ─── Label ────────────────────────────────────────────────────────────────

  static TextStyle get labelLarge => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        letterSpacing: 0.2,
      );

  static TextStyle get labelMedium => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.inkDim,
        letterSpacing: 0.2,
      );

  static TextStyle get labelSmall => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.inkMute,
        letterSpacing: 0.1,
      );

  // ─── Numbers ──────────────────────────────────────────────────────────────

  /// Big rating number — e.g. "1847"
  static TextStyle get ratingLarge => _numeric.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.8,
      );

  static TextStyle get ratingMedium => _numeric.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.4,
      );

  static TextStyle get ratingSmall => _numeric.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  /// Move list item — "e4", "Nf3", etc.
  static TextStyle get monoMove => _numeric.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      );

  /// Small numeric text — ELO badges, chip labels
  static TextStyle get monoSmall => _numeric.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.inkDim,
      );

  // ─── Buttons ──────────────────────────────────────────────────────────────

  static TextStyle get buttonLarge => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.1,
      );

  static TextStyle get buttonMedium => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.1,
      );

  // ─── Legacy aliases (keep old callers compiling) ─────────────────────────

  /// Equivalent of old chapterTitle
  static TextStyle get chapterTitle => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );
}

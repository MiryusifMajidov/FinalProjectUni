import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography: one family, Inter, for everything.
///
/// The app used to mix three: Fraunces italic serif for every heading,
/// JetBrains Mono for labels and numbers, Inter for the rest — a look that
/// read as a template rather than a product. Inter covers every language we
/// ship in the Latin and Cyrillic scripts (ə, ğ, ı, İ, ş, ₼, ё…), is bundled
/// in assets/google_fonts so first launch never falls back to a system font,
/// and has tabular figures for ratings, clocks and scores.
///
///   Display / Headline  →  Inter SemiBold–Bold, slightly tightened
///   Title / Body / Label →  Inter Regular–SemiBold
///   Numbers             →  Inter with tabular figures (columns line up)
class AppTextStyles {
  AppTextStyles._();

  /// Fixed-width digits so ratings, clocks and counters do not jitter.
  static const tabularFigures = [FontFeature.tabularFigures()];

  // ─── Base font getters ────────────────────────────────────────────────────

  static TextStyle get _inter => GoogleFonts.inter().copyWith(
        fontFamilyFallback: const ['Roboto', 'sans-serif'],
      );

  static TextStyle get _numeric => _inter.copyWith(
        fontFeatures: tabularFigures,
      );

  // ─── Display ──────────────────────────────────────────────────────────────

  static TextStyle get displayLarge => _inter.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.6,
        height: 1.2,
      );

  static TextStyle get displayMedium => _inter.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.4,
        height: 1.25,
      );

  // ─── Headline ─────────────────────────────────────────────────────────────

  static TextStyle get headlineLarge => _inter.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get headlineMedium => _inter.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.2,
      );

  static TextStyle get headlineSmall => _inter.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  // ─── Title ────────────────────────────────────────────────────────────────

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

  // ─── Body ─────────────────────────────────────────────────────────────────

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

  // ─── Label ────────────────────────────────────────────────────────────────

  static TextStyle get labelLarge => _inter.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        letterSpacing: 0.2,
      );

  static TextStyle get labelMedium => _inter.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.inkDim,
        letterSpacing: 0.2,
      );

  static TextStyle get labelSmall => _inter.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.inkMute,
        letterSpacing: 0.4,
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

  static TextStyle get buttonLarge => _inter.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.1,
      );

  static TextStyle get buttonMedium => _inter.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.1,
      );

  // ─── Legacy aliases (keep old callers compiling) ─────────────────────────

  /// Equivalent of old chapterTitle
  static TextStyle get chapterTitle => _inter.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );
}

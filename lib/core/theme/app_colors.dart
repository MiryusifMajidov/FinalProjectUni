import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Dark Theme Surfaces ───────────────────────────────────────────────────
  static const background    = Color(0xFF0A0A0B);
  static const surface       = Color(0xFF131316);
  static const card          = Color(0xFF1A1A1E);
  static const cardElevated  = Color(0xFF202026);

  // ─── Border / Divider ─────────────────────────────────────────────────────
  static const border        = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const borderStrong  = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const divider       = Color(0x0FFFFFFF);

  // ─── Amber Accent (primary) ───────────────────────────────────────────────
  static const amber         = Color(0xFFE8B960);
  static const amberSoft     = Color(0xFFFFD98B);
  static const amberDeep     = Color(0xFFB88A3A);
  static const amberGlow     = Color(0x24E8B960); // rgba(232,185,96,0.14)

  // ─── Checkers Accent (blue) ─────────────────────────────────────────────
  static const checkers      = Color(0xFF6FB4E0);
  static const checkersSoft  = Color(0x246FB4E0);

  // ─── Domino Accent (green) ────────────────────────────────────────────
  static const domino        = Color(0xFF5FD4A3);
  static const dominoSoft    = Color(0x245FD4A3);

  // Keep legacy alias for code that still references `primary`
  static const primary       = amber;
  static const primaryLight  = amberSoft;
  static const primaryDark   = amberDeep;

  // Secondary kept for any remaining references — neutral brown
  static const secondary     = Color(0xFFB8A888);
  static const secondaryLight = Color(0xFFD4C5A9);

  // ─── Result colours ───────────────────────────────────────────────────────
  static const win           = Color(0xFF5FD4A3);
  static const winSoft       = Color(0x1F5FD4A3);  // rgba(95,212,163,0.12)
  static const loss          = Color(0xFFF07079);
  static const lossSoft      = Color(0x1FF07079);  // rgba(240,112,121,0.12)
  static const draw          = Color(0xFFB8A888);
  static const drawSoft      = Color(0x24B8A888);  // rgba(184,168,136,0.14)
  static const live          = Color(0xFFFF6B6B);

  // ─── Semantic (keep old names as aliases) ─────────────────────────────────
  static const success       = win;
  static const warning       = amber;
  static const error         = loss;
  static const info          = Color(0xFF63B3ED);

  // ─── Text / Ink ───────────────────────────────────────────────────────────
  static const ink           = Color(0xFFF5F3EF);
  static const inkDim        = Color(0xFFA8A39A);
  static const inkMute       = Color(0xFF706B62);
  static const inkFaint      = Color(0xFF4A4740);

  // Legacy aliases
  static const textPrimary   = ink;
  static const textSecondary = inkDim;
  static const textHint      = inkMute;
  static const textDisabled  = inkFaint;

  // ─── Board themes ─────────────────────────────────────────────────────────
  // Classic brown (Lichess style)
  static const boardBrown1   = Color(0xFFF0D9B5);
  static const boardBrown2   = Color(0xFFB58863);
  // Green felt
  static const boardGreen1   = Color(0xFFEEEED2);
  static const boardGreen2   = Color(0xFF769656);
  // Dark marble
  static const boardMarble1  = Color(0xFF2C2C3E);
  static const boardMarble2  = Color(0xFF1A1A28);
  // Blue ice
  static const boardBlue1    = Color(0xFFDEE3E6);
  static const boardBlue2    = Color(0xFF8CA2AD);
  // Cream parchment
  static const boardCream1   = Color(0xFFF5F0E8);
  static const boardCream2   = Color(0xFFD4C5A9);
  // Calm / rosewood (used by InGame calm mode)
  static const boardRosewood1 = Color(0xFFE8D8B6); // parchment light sq
  static const boardRosewood2 = Color(0xFF8E5E33); // rosewood dark sq

  // ─── Board highlights ─────────────────────────────────────────────────────
  static const moveHighlight  = Color(0x4AE8B960); // amber tinted
  static const legalMoveDot   = Color(0x4A000000);
  static const checkGlow      = Color(0xAAF07079);
  static const selectedSquare = Color(0x6AE8B960);

  // ─── Light Theme ──────────────────────────────────────────────────────────
  static const lightBackground   = Color(0xFFF5F3EF);
  static const lightSurface      = Color(0xFFFFFFFF);
  static const lightCard         = Color(0xFFF0EDE8);
  static const lightCardElevated = Color(0xFFE8E4DC);
  static const lightDivider      = Color(0xFFE0DBD0);
  static const lightTextPrimary  = Color(0xFF1A1712);
  static const lightTextSecondary = Color(0xFF6B6660);
  static const lightTextHint     = Color(0xFF9A9590);

  // ─── Utility ──────────────────────────────────────────────────────────────
  static const glassOverlay = Color(0x1AFFFFFF);
  static const glassBorder  = Color(0x1AFFFFFF);
  static const overlay      = Color(0xCC0A0A0B);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber, amberDeep],
  );

  static const darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, background],
  );
}

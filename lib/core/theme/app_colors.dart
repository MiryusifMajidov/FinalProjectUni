import 'package:flutter/material.dart';

/// CheckMate's palette: a club table.
///
/// The ground is dark felt green rather than neutral black, the surfaces step
/// up in tone instead of being outlined, and the colours that carry meaning
/// are the colours of moulded catalin game pieces: butterscotch (chess and
/// every primary action), cherry (draughts) and jade (dominoes). There are no
/// gradients and no glows in this palette; the gradient constants below are
/// kept flat so old call sites render as solid fills.
///
/// Names are kept from the previous palette (`amber`, `ink`, `card`…) so the
/// whole app moved over without touching its call sites.
class AppColors {
  AppColors._();

  // ─── Felt ground and surfaces ─────────────────────────────────────────────
  static const background    = Color(0xFF111915);
  static const surface       = Color(0xFF17211C);
  static const card          = Color(0xFF1D2923);
  static const cardElevated  = Color(0xFF26352D);

  // ─── Lines (used sparingly — tone steps do the separating) ────────────────
  static const border        = Color(0x14FFFFFF); // 8 %
  static const borderStrong  = Color(0x24FFFFFF); // 14 %
  static const divider       = Color(0x14FFFFFF);

  // ─── Butterscotch: chess and every primary action ─────────────────────────
  static const amber         = Color(0xFFF0A93B);
  static const amberSoft     = Color(0xFFF7C873);
  static const amberDeep     = Color(0xFFB9761A); // the moulded lip
  static const amberGlow     = Color(0x26F0A93B); // selected-state tint
  /// Text and icons on a butterscotch fill.
  static const onAmber       = Color(0xFF241703);

  // ─── The selected game's colour ───────────────────────────────────────────
  /// The colour of the game the player has selected: butterscotch for
  /// chess, cherry for draughts, jade for dominoes. The app root sets it
  /// whenever the selection changes; the screens around the games
  /// (settings, profile, friends, chat, map, arenas…) take their accent
  /// from it, so they wear the colour of the game you are in. [onAmber]
  /// reads on all three.
  static Color accent = amber;
  static Color get accentGlow => accent.withValues(alpha: 0.15);
  static Color get accentSoft => Color.lerp(accent, const Color(0xFFFFFFFF), 0.3)!;
  static Color get accentDeep => Color.lerp(accent, const Color(0xFF000000), 0.25)!;

  // ─── Cherry: draughts ─────────────────────────────────────────────────────
  static const checkers      = Color(0xFFE2565E);
  static const checkersSoft  = Color(0x26E2565E);

  // ─── Jade: dominoes ───────────────────────────────────────────────────────
  static const domino        = Color(0xFF4CBF95);
  static const dominoSoft    = Color(0x264CBF95);

  // Legacy aliases
  static const primary       = amber;
  static const primaryLight  = amberSoft;
  static const primaryDark   = amberDeep;

  static const secondary     = Color(0xFFB9B4A6);
  static const secondaryLight = Color(0xFFD6D1C4);

  // ─── Results ──────────────────────────────────────────────────────────────
  static const win           = Color(0xFF7FCC8C);
  static const winSoft       = Color(0x247FCC8C);
  static const loss          = Color(0xFFF07A6E);
  static const lossSoft      = Color(0x24F07A6E);
  static const draw          = Color(0xFFB9B4A6);
  static const drawSoft      = Color(0x24B9B4A6);
  static const live          = Color(0xFFFF6F61);

  // ─── Time-control categories — one colour each, on every screen ─────────
  static const bullet        = Color(0xFFF28B4C);
  static const blitz         = Color(0xFF72B6EA);
  static const rapid         = win;

  // ─── Semantic aliases ─────────────────────────────────────────────────────
  static const success       = win;
  static const warning       = amber;
  static const error         = loss;
  static const info          = Color(0xFF72B6EA);
  /// Engine suggestions on a board (the Hint arrow): a colour no game owns.
  static const hint          = Color(0xFF9D8CF2); // violet: no game, no time control

  // ─── Ink ──────────────────────────────────────────────────────────────────
  static const ink           = Color(0xFFEEF1EC); // 15.9:1 on background
  static const inkDim        = Color(0xFFB4BEB8); //  9.4:1
  static const inkMute       = Color(0xFF8D9993); //  5.9:1 (4.9:1 on card)
  static const inkFaint      = Color(0xFF55615B);

  // Legacy aliases
  static const textPrimary   = ink;
  static const textSecondary = inkDim;
  static const textHint      = inkMute;
  static const textDisabled  = inkFaint;

  // ─── Board themes ─────────────────────────────────────────────────────────
  static const boardBrown1   = Color(0xFFF0D9B5);
  static const boardBrown2   = Color(0xFFB58863);
  static const boardGreen1   = Color(0xFFEEEED2);
  static const boardGreen2   = Color(0xFF769656);
  static const boardMarble1  = Color(0xFF2C2C3E);
  static const boardMarble2  = Color(0xFF1A1A28);
  static const boardBlue1    = Color(0xFFDEE3E6);
  static const boardBlue2    = Color(0xFF8CA2AD);
  static const boardCream1   = Color(0xFFF5F0E8);
  static const boardCream2   = Color(0xFFD4C5A9);

  // ─── Board highlights ─────────────────────────────────────────────────────
  static const moveHighlight  = Color(0x52F0A93B);
  static const legalMoveDot   = Color(0x4A000000);
  static const checkGlow      = Color(0xAAF07A6E);
  static const selectedSquare = Color(0x70F0A93B);

  // ─── Light theme (not used: the app ships one dark scheme) ───────────────
  static const lightBackground   = Color(0xFFF3F1EA);
  static const lightSurface      = Color(0xFFFFFFFF);
  static const lightCard         = Color(0xFFECE9E0);
  static const lightCardElevated = Color(0xFFE3DFD4);
  static const lightDivider      = Color(0xFFDAD5C9);
  static const lightTextPrimary  = Color(0xFF17201B);
  static const lightTextSecondary = Color(0xFF5E6862);
  static const lightTextHint     = Color(0xFF8C958F);

  // ─── Utility ──────────────────────────────────────────────────────────────
  static const glassOverlay = Color(0x14FFFFFF);
  static const glassBorder  = Color(0x14FFFFFF);
  static const overlay      = Color(0xCC0B110E);

  // ─── "Gradients" — flat on purpose ────────────────────────────────────────
  static const primaryGradient = LinearGradient(colors: [amber, amber]);
  static const darkGradient = LinearGradient(colors: [background, background]);
}

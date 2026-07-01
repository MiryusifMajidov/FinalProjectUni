import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin SharedPreferences wrapper for local settings and one-time flags.
/// Extends [ChangeNotifier] so that Riverpod watchers rebuild automatically
/// when appearance/motion settings change.
class CacheService extends ChangeNotifier {
  // ── Preference keys ───────────────────────────────────────────────────────
  static const _kBoardTheme = 'pref_board_theme';
  static const _kPieceSet = 'pref_piece_set';
  static const _kSoundEnabled = 'pref_sound';
  static const _kHapticEnabled = 'pref_haptic';
  static const _kNotificationsEnabled = 'pref_notifications';
  static const _kPhotoOnboardingShown = 'flag_photo_onboarding';
  static const _kShowOnMap = 'pref_show_on_map';
  static const _kThemeMode = 'pref_theme_mode';

  final SharedPreferences _p;
  CacheService._(this._p);

  /// Creates an instance, loading the SharedPreferences store.
  static Future<CacheService> create() async {
    return CacheService._(await SharedPreferences.getInstance());
  }

  // ── Board / piece settings ────────────────────────────────────────────────

  String get boardTheme => _p.getString(_kBoardTheme) ?? 'brownWood';
  Future<void> setBoardTheme(String v) => _p.setString(_kBoardTheme, v);

  String get pieceSet => _p.getString(_kPieceSet) ?? 'cburnett';
  Future<void> setPieceSet(String v) => _p.setString(_kPieceSet, v);

  // ── Toggles ───────────────────────────────────────────────────────────────

  bool get soundEnabled => _p.getBool(_kSoundEnabled) ?? true;
  Future<void> setSoundEnabled(bool v) => _p.setBool(_kSoundEnabled, v);

  bool get hapticEnabled => _p.getBool(_kHapticEnabled) ?? true;
  Future<void> setHapticEnabled(bool v) => _p.setBool(_kHapticEnabled, v);

  bool get notificationsEnabled =>
      _p.getBool(_kNotificationsEnabled) ?? true;
  Future<void> setNotificationsEnabled(bool v) =>
      _p.setBool(_kNotificationsEnabled, v);

  // ── One-time flags ────────────────────────────────────────────────────────

  bool get photoOnboardingShown =>
      _p.getBool(_kPhotoOnboardingShown) ?? false;
  Future<void> markPhotoOnboardingShown() =>
      _p.setBool(_kPhotoOnboardingShown, true);

  // ── Map privacy ───────────────────────────────────────────────────────────

  bool get showOnMap => _p.getBool(_kShowOnMap) ?? false;
  Future<void> setShowOnMap(bool v) => _p.setBool(_kShowOnMap, v);

  String get themeMode => _p.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String v) => _p.setString(_kThemeMode, v);

  // ── Map recent searches ────────────────────────────────────────────────────

  static const _kMapRecentSearches = 'pref_map_recent_searches';
  List<String> get mapRecentSearches =>
      _p.getStringList(_kMapRecentSearches) ?? [];
  Future<void> setMapRecentSearches(List<String> v) =>
      _p.setStringList(_kMapRecentSearches, v);

  // ── Message privacy ───────────────────────────────────────────────────────

  static const _kMessagePrivacy = 'pref_message_privacy';
  String get messagePrivacy => _p.getString(_kMessagePrivacy) ?? 'everyone';
  Future<void> setMessagePrivacy(String v) => _p.setString(_kMessagePrivacy, v);

  // ── Profile visibility / online status / invisible mode ───────────────────

  static const _kProfileVisibility = 'pref_profile_visibility';
  String get profileVisibility => _p.getString(_kProfileVisibility) ?? 'Public';
  Future<void> setProfileVisibility(String v) =>
      _p.setString(_kProfileVisibility, v);

  static const _kOnlineStatus = 'pref_online_status';
  bool get onlineStatus => _p.getBool(_kOnlineStatus) ?? true;
  Future<void> setOnlineStatus(bool v) => _p.setBool(_kOnlineStatus, v);

  static const _kInvisibleMode = 'pref_invisible_mode';
  bool get invisibleMode => _p.getBool(_kInvisibleMode) ?? false;
  Future<void> setInvisibleMode(bool v) => _p.setBool(_kInvisibleMode, v);

  // ── Notification channel prefs ────────────────────────────────────────────

  static const _kNotifGameInvites = 'pref_notif_game_invites';
  bool get notifGameInvites => _p.getBool(_kNotifGameInvites) ?? true;
  Future<void> setNotifGameInvites(bool v) => _p.setBool(_kNotifGameInvites, v);

  static const _kNotifYourTurn = 'pref_notif_your_turn';
  bool get notifYourTurn => _p.getBool(_kNotifYourTurn) ?? true;
  Future<void> setNotifYourTurn(bool v) => _p.setBool(_kNotifYourTurn, v);

  static const _kNotifClockWarnings = 'pref_notif_clock_warnings';
  bool get notifClockWarnings => _p.getBool(_kNotifClockWarnings) ?? false;
  Future<void> setNotifClockWarnings(bool v) => _p.setBool(_kNotifClockWarnings, v);

  static const _kNotifTournaments = 'pref_notif_tournaments';
  bool get notifTournaments => _p.getBool(_kNotifTournaments) ?? true;
  Future<void> setNotifTournaments(bool v) => _p.setBool(_kNotifTournaments, v);

  static const _kNotifMessages = 'pref_notif_messages';
  bool get notifMessages => _p.getBool(_kNotifMessages) ?? true;
  Future<void> setNotifMessages(bool v) => _p.setBool(_kNotifMessages, v);

  static const _kNotifFriendRequests = 'pref_notif_friend_requests';
  bool get notifFriendRequests => _p.getBool(_kNotifFriendRequests) ?? true;
  Future<void> setNotifFriendRequests(bool v) => _p.setBool(_kNotifFriendRequests, v);

  static const _kNotifDoNotDisturb = 'pref_notif_dnd';
  bool get notifDoNotDisturb => _p.getBool(_kNotifDoNotDisturb) ?? false;
  Future<void> setNotifDoNotDisturb(bool v) => _p.setBool(_kNotifDoNotDisturb, v);

  static const _kNotifDndStart = 'pref_notif_dnd_start';
  String get notifDndStart => _p.getString(_kNotifDndStart) ?? '22:00';
  Future<void> setNotifDndStart(String v) => _p.setString(_kNotifDndStart, v);

  static const _kNotifDndEnd = 'pref_notif_dnd_end';
  String get notifDndEnd => _p.getString(_kNotifDndEnd) ?? '08:00';
  Future<void> setNotifDndEnd(String v) => _p.setString(_kNotifDndEnd, v);

  // ── Sound effect prefs ────────────────────────────────────────────────────

  static const _kSoundPieceMoves = 'pref_sound_piece_moves';
  bool get soundPieceMoves => _p.getBool(_kSoundPieceMoves) ?? true;
  Future<void> setSoundPieceMoves(bool v) => _p.setBool(_kSoundPieceMoves, v);

  static const _kSoundCaptures = 'pref_sound_captures';
  bool get soundCaptures => _p.getBool(_kSoundCaptures) ?? true;
  Future<void> setSoundCaptures(bool v) => _p.setBool(_kSoundCaptures, v);

  static const _kSoundCheckMate = 'pref_sound_checkmate';
  bool get soundCheckMate => _p.getBool(_kSoundCheckMate) ?? true;
  Future<void> setSoundCheckMate(bool v) => _p.setBool(_kSoundCheckMate, v);

  static const _kSoundLowTimeTick = 'pref_sound_low_time_tick';
  bool get soundLowTimeTick => _p.getBool(_kSoundLowTimeTick) ?? false;
  Future<void> setSoundLowTimeTick(bool v) => _p.setBool(_kSoundLowTimeTick, v);

  static const _kSoundVictoryFanfare = 'pref_sound_victory_fanfare';
  bool get soundVictoryFanfare => _p.getBool(_kSoundVictoryFanfare) ?? true;
  Future<void> setSoundVictoryFanfare(bool v) => _p.setBool(_kSoundVictoryFanfare, v);

  static const _kSoundPack = 'pref_sound_pack';
  String get soundPack => _p.getString(_kSoundPack) ?? 'classic';
  Future<void> setSoundPack(String v) => _p.setString(_kSoundPack, v);

  // ── Gameplay prefs ────────────────────────────────────────────────────────

  static const _kAutoQueen = 'pref_auto_queen';
  bool get autoQueen => _p.getBool(_kAutoQueen) ?? false;
  Future<void> setAutoQueen(bool v) => _p.setBool(_kAutoQueen, v);

  static const _kHighlightLastMove = 'pref_highlight_last_move';
  bool get highlightLastMove => _p.getBool(_kHighlightLastMove) ?? true;
  Future<void> setHighlightLastMove(bool v) async {
    await _p.setBool(_kHighlightLastMove, v);
    notifyListeners();
  }

  static const _kShowLegalMoves = 'pref_show_legal_moves';
  bool get showLegalMoves => _p.getBool(_kShowLegalMoves) ?? true;
  Future<void> setShowLegalMoves(bool v) async {
    await _p.setBool(_kShowLegalMoves, v);
    notifyListeners();
  }

  static const _kConfirmMoves = 'pref_confirm_moves';
  bool get confirmMoves => _p.getBool(_kConfirmMoves) ?? false;
  Future<void> setConfirmMoves(bool v) async {
    await _p.setBool(_kConfirmMoves, v);
    notifyListeners();
  }

  static const _kPremove = 'pref_premove';
  bool get premove => _p.getBool(_kPremove) ?? true;
  Future<void> setPremove(bool v) async {
    await _p.setBool(_kPremove, v);
    notifyListeners();
  }

  static const _kMoveNotation = 'pref_move_notation';
  String get moveNotation => _p.getString(_kMoveNotation) ?? 'san';
  Future<void> setMoveNotation(String v) async {
    await _p.setString(_kMoveNotation, v);
    notifyListeners();
  }

  // ── Appearance / motion prefs ─────────────────────────────────────────────

  static const _kShowCoordinates = 'pref_show_coordinates';
  bool get showCoordinates => _p.getBool(_kShowCoordinates) ?? true;
  Future<void> setShowCoordinates(bool v) async {
    await _p.setBool(_kShowCoordinates, v);
    notifyListeners();
  }

  /// One of 'slow' | 'med' | 'fast'
  static const _kAnimSpeed = 'pref_anim_speed';
  String get animSpeed => _p.getString(_kAnimSpeed) ?? 'med';
  Future<void> setAnimSpeed(String v) async {
    await _p.setString(_kAnimSpeed, v);
    notifyListeners();
  }

  bool get reduceMotion => _p.getBool(_kReduceMotion) ?? false;
  static const _kReduceMotion = 'pref_reduce_motion';
  Future<void> setReduceMotion(bool v) async {
    await _p.setBool(_kReduceMotion, v);
    notifyListeners();
  }

  /// Resolves [animSpeed] + [reduceMotion] → a concrete [Duration] for
  /// piece-move animations on the chess board.
  Duration get pieceMoveAnimationDuration {
    if (reduceMotion) return Duration.zero;
    return switch (animSpeed) {
      'slow' => const Duration(milliseconds: 600),
      'fast' => const Duration(milliseconds: 150),
      _      => const Duration(milliseconds: 300),
    };
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

/// Must be overridden in [main()] with `cacheServiceProvider.overrideWithValue(...)`.
/// Using [ChangeNotifierProvider] so that [ref.watch] rebuilds automatically
/// whenever [notifyListeners] is called (e.g. after changing appearance settings).
final cacheServiceProvider = ChangeNotifierProvider<CacheService>((_) {
  throw UnimplementedError(
    'cacheServiceProvider has not been initialised. '
    'Call CacheService.create() in main() and pass the result via overrideWithValue().',
  );
});

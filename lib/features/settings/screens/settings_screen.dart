import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../game/engine/chess_engine.dart';
import '../../game/widgets/chess_board_widget.dart';

const _settingsCountries = [
  ('AF', 'Afghanistan'), ('AL', 'Albania'), ('DZ', 'Algeria'), ('AR', 'Argentina'),
  ('AU', 'Australia'), ('AT', 'Austria'), ('AZ', 'Azerbaijan'), ('BE', 'Belgium'),
  ('BR', 'Brazil'), ('CA', 'Canada'), ('CN', 'China'), ('CO', 'Colombia'),
  ('HR', 'Croatia'), ('CZ', 'Czech Republic'), ('DK', 'Denmark'), ('EG', 'Egypt'),
  ('FI', 'Finland'), ('FR', 'France'), ('DE', 'Germany'), ('GR', 'Greece'),
  ('HU', 'Hungary'), ('IN', 'India'), ('ID', 'Indonesia'), ('IR', 'Iran'),
  ('IQ', 'Iraq'), ('IE', 'Ireland'), ('IL', 'Israel'), ('IT', 'Italy'),
  ('JP', 'Japan'), ('JO', 'Jordan'), ('KZ', 'Kazakhstan'), ('KE', 'Kenya'),
  ('KR', 'South Korea'), ('KW', 'Kuwait'), ('LB', 'Lebanon'), ('MY', 'Malaysia'),
  ('MX', 'Mexico'), ('MA', 'Morocco'), ('NL', 'Netherlands'), ('NZ', 'New Zealand'),
  ('NG', 'Nigeria'), ('NO', 'Norway'), ('PK', 'Pakistan'), ('PE', 'Peru'),
  ('PH', 'Philippines'), ('PL', 'Poland'), ('PT', 'Portugal'), ('QA', 'Qatar'),
  ('RO', 'Romania'), ('RU', 'Russia'), ('SA', 'Saudi Arabia'), ('RS', 'Serbia'),
  ('ZA', 'South Africa'), ('ES', 'Spain'), ('SE', 'Sweden'), ('CH', 'Switzerland'),
  ('SY', 'Syria'), ('TW', 'Taiwan'), ('TH', 'Thailand'), ('TN', 'Tunisia'),
  ('TR', 'Turkey'), ('UA', 'Ukraine'), ('AE', 'UAE'), ('GB', 'United Kingdom'),
  ('US', 'United States'), ('UZ', 'Uzbekistan'), ('VE', 'Venezuela'), ('VN', 'Vietnam'),
  ('YE', 'Yemen'),
];

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref.read(cacheServiceProvider));
});

class SettingsState {
  final BoardTheme boardTheme;
  final PieceSet pieceSet;
  final bool soundEnabled;
  final bool notificationsEnabled;
  final bool hapticEnabled;
  final ThemeMode themeMode;
  final bool showOnMap;
  final String messagePrivacy;

  const SettingsState({
    this.boardTheme = BoardTheme.brownWood,
    this.pieceSet = PieceSet.cburnett,
    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.hapticEnabled = true,
    this.themeMode = ThemeMode.system,
    this.showOnMap = false,
    this.messagePrivacy = 'everyone',
  });

  SettingsState copyWith({
    BoardTheme? boardTheme,
    PieceSet? pieceSet,
    bool? soundEnabled,
    bool? notificationsEnabled,
    bool? hapticEnabled,
    ThemeMode? themeMode,
    bool? showOnMap,
    String? messagePrivacy,
  }) =>
      SettingsState(
        boardTheme: boardTheme ?? this.boardTheme,
        pieceSet: pieceSet ?? this.pieceSet,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
        themeMode: themeMode ?? this.themeMode,
        showOnMap: showOnMap ?? this.showOnMap,
        messagePrivacy: messagePrivacy ?? this.messagePrivacy,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final CacheService _cache;

  SettingsNotifier(this._cache)
      : super(SettingsState(
          boardTheme: _parseBoardTheme(_cache.boardTheme),
          pieceSet: _parsePieceSet(_cache.pieceSet),
          soundEnabled: _cache.soundEnabled,
          hapticEnabled: _cache.hapticEnabled,
          notificationsEnabled: _cache.notificationsEnabled,
          themeMode: _parseThemeMode(_cache.themeMode),
          showOnMap: _cache.showOnMap,
          messagePrivacy: _cache.messagePrivacy,
        ));

  void setBoardTheme(BoardTheme t) {
    state = state.copyWith(boardTheme: t);
    _cache.setBoardTheme(t.name);
  }

  void setPieceSet(PieceSet p) {
    state = state.copyWith(pieceSet: p);
    _cache.setPieceSet(p.name);
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
    _cache.setSoundEnabled(state.soundEnabled);
  }

  void toggleNotifications() {
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
    _cache.setNotificationsEnabled(state.notificationsEnabled);
  }

  void toggleHaptic() {
    state = state.copyWith(hapticEnabled: !state.hapticEnabled);
    _cache.setHapticEnabled(state.hapticEnabled);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _cache.setThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  void setShowOnMap(bool v) {
    state = state.copyWith(showOnMap: v);
    _cache.setShowOnMap(v);
  }

  Future<void> setMessagePrivacy(String value) async {
    await _cache.setMessagePrivacy(value);
    state = state.copyWith(messagePrivacy: value);
  }

  static BoardTheme _parseBoardTheme(String s) {
    try {
      return BoardTheme.values.byName(s);
    } catch (_) {
      return BoardTheme.brownWood;
    }
  }

  static PieceSet _parsePieceSet(String s) {
    try {
      return PieceSet.values.byName(s);
    } catch (_) {
      return PieceSet.cburnett;
    }
  }

  static ThemeMode _parseThemeMode(String s) => switch (s) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kBg            = Color(0xFF0A0A0B);
const _kSurface       = Color(0xFF131316);
const _kCard          = Color(0xFF1A1A1E);
const _kCardElevated  = Color(0xFF202026);
const _kAmber         = Color(0xFFE8B960);
const _kAmberDeep     = Color(0xFFB88A3A);
const _kAmberGlow     = Color(0x24E8B960);
const _kWin           = Color(0xFF5FD4A3);
const _kLoss          = Color(0xFFF07079);
const _kInk           = Color(0xFFF5F3EF);
const _kInkDim        = Color(0xFFA8A39A);
const _kInkMute       = Color(0xFF706B62);
const _kInkFaint      = Color(0xFF4A4740);
const _kBorder        = Color(0x0FFFFFFF);  // rgba(255,255,255,0.06)
const _kBorderStrong  = Color(0x1AFFFFFF);  // rgba(255,255,255,0.10)
const _kLossBorder    = Color(0x38F07079);  // rgba(240,112,121,0.22)

// ── Main Screen ───────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final userAsync = ref.watch(currentUserProvider);

    // Resolve current language name
    final currentLocale = context.locale.languageCode;
    const _langNames = {
      'en': 'English',
      'az': 'Azərbaycan',
      'tr': 'Türkçe',
      'ru': 'Русский',
      'de': 'Deutsch',
      'es': 'Español',
      'fr': 'Français',
      'hi': 'हिन्दी',
      'ur': 'اردو',
      'zh': '中文',
    };
    final langName = _langNames[currentLocale] ?? currentLocale.toUpperCase();

    final isTablet = context.isTablet;
    final isLargeTablet = context.isLargeTablet;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLargeTablet ? 900 : (isTablet ? 680 : double.infinity),
            ),
            child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, 12, isTablet ? 24 : 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: _kInkDim, size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'settings'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
          // ── User card ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: userAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (user) => user == null
                  ? const SizedBox.shrink()
                  : _UserCard(
                      user: user,
                      onTap: () => context.push('/home/profile/${user.uid}'),
                    ).animate().fadeIn(),
            ),
          ),

          const SizedBox(height: 24),

          // ── Group: Preferences ────────────────────────────────────────────
          _SettingsGroup(
            title: 'settings_preferences'.tr(),
            children: [
              _SettingsRow(
                icon: PhosphorIcons.user(PhosphorIconsStyle.regular),
                label: 'account'.tr(),
                sub: 'account_subtitle'.tr(),
                onTap: () => context.push('/home/settings/account'),
              ),
              _SettingsRow(
                icon: PhosphorIcons.globe(PhosphorIconsStyle.regular),
                label: 'language'.tr(),
                sub: langName,
                onTap: () => context.push('/home/settings/language'),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Group: Gameplay ───────────────────────────────────────────────
          _SettingsGroup(
            title: 'settings_gameplay'.tr(),
            children: [
              _SettingsRow(
                icon: PhosphorIcons.gameController(PhosphorIconsStyle.regular),
                label: 'game_settings'.tr(),
                sub: 'game_settings_subtitle'.tr(),
                onTap: () => context.push('/home/settings/game'),
              ),
              _SettingsRow(
                icon: PhosphorIcons.speakerHigh(PhosphorIconsStyle.regular),
                label: 'sound'.tr(),
                sub: settings.soundEnabled ? 'on'.tr() : 'off'.tr(),
                onTap: () => context.push('/home/settings/sound'),
              ),
              _SettingsRow(
                icon: PhosphorIcons.vibrate(PhosphorIconsStyle.regular),
                label: 'haptics'.tr(),
                right: _DesignToggle(
                  on: settings.hapticEnabled,
                  onToggle: () {
                    // Vibrate once so the user can feel the toggle land
                    HapticFeedback.mediumImpact();
                    notifier.toggleHaptic();
                  },
                ),
              ),
              _SettingsRow(
                icon: PhosphorIcons.bell(PhosphorIconsStyle.regular),
                label: 'notifications'.tr(),
                sub: 'notifications_subtitle'.tr(),
                onTap: () => context.push('/home/settings/notifications'),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Group: Privacy & Support ──────────────────────────────────────
          _SettingsGroup(
            title: 'settings_privacy_support'.tr(),
            children: [
              _SettingsRow(
                icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.regular),
                label: 'privacy'.tr(),
                sub: 'privacy_subtitle'.tr(),
                onTap: () => context.push('/home/settings/privacy'),
              ),
              _SettingsRow(
                icon: PhosphorIcons.question(PhosphorIconsStyle.regular),
                label: 'help_feedback'.tr(),
                onTap: () => context.push('/home/settings/feedback'),
              ),
              _SettingsRow(
                icon: PhosphorIcons.info(PhosphorIconsStyle.regular),
                label: 'about'.tr(),
                sub: 'v2.4.0',
                onTap: () => context.push('/home/settings/about'),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Log out button ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: GestureDetector(
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kLossBorder, width: 1),
                ),
                child: Center(
                  child: Text(
                    'log_out'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kLoss,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Footer ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Center(
              child: Text(
                'GRANDMASTER · LUDODO',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: _kInkFaint,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
                ],        // close ListView children
              ),          // close ListView
            ),            // close Expanded
          ],              // close Column children
            ),            // close Column (inner)
          ),              // close ConstrainedBox
        ),                // close Center
      ),                  // close SafeArea
    );
  }
}

// ── Account sheet dispatcher ──────────────────────────────────────────────────

void _showAccountSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AccountActionsSheet(pRef: ref),
  );
}

void _showLanguageSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _LanguageTile(),
  );
}

void _showPrivacySheet(
  BuildContext context,
  WidgetRef ref,
  SettingsState settings,
  SettingsNotifier notifier,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PrivacySheet(settings: settings, notifier: notifier),
  );
}

void _showChangeUsernameSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => _ChangeUsernameSheet(pRef: ref),
  );
}
void _showChangeEmailSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => _ChangeEmailSheet(pRef: ref),
  );
}
void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => _ChangePasswordSheet(pRef: ref),
  );
}
void _showChangeCountrySheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => _ChangeCountrySheet(pRef: ref),
  );
}

// ── Account Actions Sheet ─────────────────────────────────────────────────────

class _AccountActionsSheet extends ConsumerWidget {
  final WidgetRef pRef;
  const _AccountActionsSheet({required this.pRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 12, 0, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kInkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Account',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: _kInk,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sheetRow(
            context: context,
            icon: PhosphorIcons.user(PhosphorIconsStyle.regular),
            label: 'change_username'.tr(),
            onTap: () {
              Navigator.pop(context);
              _showChangeUsernameSheet(context, ref);
            },
          ),
          _divider(),
          _sheetRow(
            context: context,
            icon: PhosphorIcons.envelope(PhosphorIconsStyle.regular),
            label: 'change_email'.tr(),
            onTap: () {
              Navigator.pop(context);
              _showChangeEmailSheet(context, ref);
            },
          ),
          _divider(),
          _sheetRow(
            context: context,
            icon: PhosphorIcons.lock(PhosphorIconsStyle.regular),
            label: 'change_password'.tr(),
            onTap: () {
              Navigator.pop(context);
              _showChangePasswordSheet(context, ref);
            },
          ),
          _divider(),
          _sheetRow(
            context: context,
            icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
            label: 'change_country'.tr(),
            onTap: () {
              Navigator.pop(context);
              _showChangeCountrySheet(context, ref);
            },
          ),
        ],
      ),
    );
  }

  Widget _sheetRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder, width: 1),
              ),
              child: Center(
                child: Icon(icon, color: _kAmber, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kInk,
                ),
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
              color: _kInkMute,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.only(left: 66),
    child: Container(height: 1, color: _kBorder),
  );
}

// ── Privacy Sheet ─────────────────────────────────────────────────────────────

class _PrivacySheet extends StatelessWidget {
  final SettingsState settings;
  final SettingsNotifier notifier;
  const _PrivacySheet({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 12, 0, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _kInkMute, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Privacy',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: _kInk,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'who_can_message'.tr(),
              style: GoogleFonts.inter(fontSize: 12, color: _kInkMute),
            ),
          ),
          ...[
            ('everyone', 'everyone'.tr()),
            ('friends', 'friends_only'.tr()),
            ('nobody', 'nobody'.tr()),
          ].map((opt) => RadioListTile<String>(
            value: opt.$1,
            groupValue: settings.messagePrivacy,
            onChanged: (v) => notifier.setMessagePrivacy(v!),
            title: Text(
              opt.$2,
              style: GoogleFonts.inter(fontSize: 14, color: _kInk),
            ),
            activeColor: _kAmber,
            dense: true,
          )),
        ],
      ),
    );
  }
}

// ── New UI widgets ────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _UserCard({required this.user, required this.onTap});

  static String _fmtRating(int r) {
    if (r >= 1000) {
      final s = r.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return r.toString();
  }

  @override
  Widget build(BuildContext context) {
    final initial = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment(0.0, -1.0),
            end: Alignment(1.0, 1.0),
            colors: [_kCardElevated, _kCard],
          ),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kAmber, _kAmberDeep],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF1A1205),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + ELO
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtRating(user.overallRating)} ELO'
                    '${user.skillLevel != null ? ' · ${user.skillLevel}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _kInkMute,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
              color: _kInkMute,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kInkMute,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder, width: 1),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Widget? right;
  final VoidCallback? onTap;
  final bool danger;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
    this.right,
    this.onTap,
    this.danger = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder, width: 1),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: danger ? _kLoss : _kAmber,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Label + sub
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: danger ? _kLoss : _kInk,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _kInkMute,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Right widget or chevron
                right ??
                    Icon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                      color: _kInkMute,
                      size: 16,
                    ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Container(height: 1, color: _kBorder),
          ),
      ],
    );
  }
}

// ── Design Toggle ─────────────────────────────────────────────────────────────

class _DesignToggle extends StatelessWidget {
  final bool on;
  final VoidCallback onToggle;

  const _DesignToggle({required this.on, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: on ? _kAmber : _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? _kAmber : _kBorderStrong,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: on ? const Color(0xFF1A1205) : _kInk,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Kept intact: _BoardThemeSwatch ────────────────────────────────────────────

class _BoardThemeSwatch extends StatelessWidget {
  final BoardTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _BoardThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Container(color: theme.lightSquare),
                  Container(color: theme.darkSquare),
                  Container(color: theme.darkSquare),
                  Container(color: theme.lightSquare),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            theme.displayName.split(' ').first,
            style: AppTextStyles.labelSmall.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kept intact: _LiveBoardPreview ────────────────────────────────────────────

class _LiveBoardPreview extends StatefulWidget {
  final BoardTheme theme;
  final PieceSet pieceSet;

  const _LiveBoardPreview({required this.theme, required this.pieceSet});

  @override
  State<_LiveBoardPreview> createState() => _LiveBoardPreviewState();
}

class _LiveBoardPreviewState extends State<_LiveBoardPreview> {
  final _engine = ChessEngine();

  @override
  Widget build(BuildContext context) {
    return ChessBoardWidget(
      engine: _engine,
      flipped: false,
      selectedSquare: null,
      legalMoveSquares: const [],
      onSquareTap: (_) {}, // non-interactive in preview
      boardTheme: widget.theme,
      pieceSet: widget.pieceSet,
      showCoordinates: false,
    );
  }
}

// ── Kept intact: _MapPrivacyTile ──────────────────────────────────────────────

class _MapPrivacyTile extends ConsumerStatefulWidget {
  final bool enabled;
  final SettingsNotifier notifier;

  const _MapPrivacyTile({required this.enabled, required this.notifier});

  @override
  ConsumerState<_MapPrivacyTile> createState() => _MapPrivacyTileState();
}

class _MapPrivacyTileState extends ConsumerState<_MapPrivacyTile> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    PhosphorIcons.mapPin(PhosphorIconsStyle.regular),
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('appear_on_map'.tr(),
                        style: AppTextStyles.titleSmall),
                    Text('appear_on_map_subtitle'.tr(),
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (_saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: widget.enabled,
                  onChanged: (v) => _toggle(v),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(bool v) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    if (!v) {
      widget.notifier.setShowOnMap(false);
      setState(() => _saving = true);
      try {
        await ref.read(firestoreServiceProvider).updateMapSettings(
              user.uid,
              showOnMap: false,
            );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    setState(() => _saving = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please enable location services first.')));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission is required to appear on the map.')));
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      widget.notifier.setShowOnMap(true);
      await ref.read(firestoreServiceProvider).updateMapSettings(
            user.uid,
            showOnMap: true,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Kept intact: _ChangeUsernameSheet ─────────────────────────────────────────

class _ChangeUsernameSheet extends ConsumerStatefulWidget {
  final WidgetRef pRef;
  const _ChangeUsernameSheet({required this.pRef});
  @override ConsumerState<_ChangeUsernameSheet> createState() => _ChangeUsernameSheetState();
}
class _ChangeUsernameSheetState extends ConsumerState<_ChangeUsernameSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('change_username'.tr(), style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        TextField(controller: _ctrl, decoration: InputDecoration(labelText: 'new_username'.tr(), errorText: _error, prefixIcon: const Icon(Icons.person_outline_rounded)), autofocus: true, onSubmitted: (_) => _save()),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('save'.tr()),
        )),
      ]),
    );
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty || v.length < 3) { setState(() => _error = 'At least 3 characters'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).changeUsername(v);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username updated!')));
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }
}

// ── Kept intact: _ChangeEmailSheet ────────────────────────────────────────────

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  final WidgetRef pRef;
  const _ChangeEmailSheet({required this.pRef});
  @override ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}
class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override void dispose() { _passCtrl.dispose(); _emailCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('change_email'.tr(), style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        TextField(controller: _passCtrl, decoration: InputDecoration(labelText: 'current_password'.tr(), prefixIcon: const Icon(Icons.lock_outline_rounded)), obscureText: true),
        const SizedBox(height: 12),
        TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'new_email'.tr(), errorText: _error, prefixIcon: const Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('save'.tr()),
        )),
      ]),
    );
  }

  Future<void> _save() async {
    if (_passCtrl.text.isEmpty || _emailCtrl.text.isEmpty) { setState(() => _error = 'All fields required'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).changeEmail(_passCtrl.text, _emailCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent to new address!')));
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }
}

// ── Kept intact: _ChangePasswordSheet ────────────────────────────────────────

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final WidgetRef pRef;
  const _ChangePasswordSheet({required this.pRef});
  @override ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}
class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override void dispose() { _currCtrl.dispose(); _newCtrl.dispose(); _confCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('change_password'.tr(), style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        TextField(controller: _currCtrl, decoration: InputDecoration(labelText: 'current_password'.tr(), prefixIcon: const Icon(Icons.lock_outline_rounded)), obscureText: true),
        const SizedBox(height: 12),
        TextField(controller: _newCtrl, decoration: InputDecoration(labelText: 'new_password'.tr(), prefixIcon: const Icon(Icons.lock_open_outlined)), obscureText: true),
        const SizedBox(height: 12),
        TextField(controller: _confCtrl, decoration: InputDecoration(labelText: 'confirm_password'.tr(), errorText: _error, prefixIcon: const Icon(Icons.lock_open_outlined)), obscureText: true),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('save'.tr()),
        )),
      ]),
    );
  }

  Future<void> _save() async {
    if (_newCtrl.text != _confCtrl.text) { setState(() => _error = 'Passwords do not match'); return; }
    if (_newCtrl.text.length < 6) { setState(() => _error = 'At least 6 characters'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).changePassword(_currCtrl.text, _newCtrl.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!')));
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }
}

// ── Kept intact: _ChangeCountrySheet ─────────────────────────────────────────

class _ChangeCountrySheet extends ConsumerStatefulWidget {
  final WidgetRef pRef;
  const _ChangeCountrySheet({required this.pRef});
  @override ConsumerState<_ChangeCountrySheet> createState() => _ChangeCountrySheetState();
}
class _ChangeCountrySheetState extends ConsumerState<_ChangeCountrySheet> {
  String? _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(currentUserProvider).valueOrNull?.countryCode;
  }

  @override Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Text('change_country'.tr(), style: AppTextStyles.titleMedium),
        const SizedBox(height: 4),
        ListTile(
          leading: const Text('🏳️', style: TextStyle(fontSize: 24)),
          title: Text('no_flag'.tr(), style: AppTextStyles.bodyMedium),
          trailing: _selected == null ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20) : null,
          onTap: () => _save(null),
        ),
        ListTile(
          leading: const Text('🌍', style: TextStyle(fontSize: 24)),
          title: Text('international'.tr(), style: AppTextStyles.bodyMedium),
          trailing: _selected == 'XX' ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20) : null,
          onTap: () => _save('XX'),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            itemCount: _settingsCountries.length,
            itemBuilder: (_, i) {
              final (code, name) = _settingsCountries[i];
              final sel = _selected == code;
              return ListTile(
                leading: Text(UserModel.flagEmoji(code), style: const TextStyle(fontSize: 24)),
                title: Text(name, style: AppTextStyles.bodyMedium),
                trailing: sel ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20) : null,
                onTap: () => _save(code),
              );
            },
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
      ]),
    );
  }

  Future<void> _save(String? code) async {
    setState(() { _loading = true; _selected = code; });
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;
      await ref.read(firestoreServiceProvider).updateUser(user.uid, {'countryCode': code});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('country_updated'.tr())));
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Language Tile (kept intact, used as bottom sheet content) ─────────────────

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  static const _langs = [
    (code: 'en', name: 'English',    flag: '🇬🇧'),
    (code: 'az', name: 'Azərbaycan', flag: '🇦🇿'),
    (code: 'tr', name: 'Türkçe',     flag: '🇹🇷'),
    (code: 'ru', name: 'Русский',    flag: '🇷🇺'),
    (code: 'de', name: 'Deutsch',    flag: '🇩🇪'),
    (code: 'es', name: 'Español',    flag: '🇪🇸'),
    (code: 'fr', name: 'Français',   flag: '🇫🇷'),
    (code: 'hi', name: 'हिन्दी',    flag: '🇮🇳'),
    (code: 'ur', name: 'اردو',       flag: '🇵🇰'),
    (code: 'zh', name: '中文',        flag: '🇨🇳'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _kInkMute, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'language'.tr(),
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: _kInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._langs.map((lang) {
            final selected = current == lang.code;
            return ListTile(
              onTap: () => context.setLocale(Locale(lang.code)),
              leading: Text(lang.flag, style: const TextStyle(fontSize: 22)),
              title: Text(
                lang.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: selected ? _kAmber : _kInk,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: selected
                  ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: _kAmber, size: 18)
                  : null,
            );
          }),
        ],
      ),
    );
  }
}

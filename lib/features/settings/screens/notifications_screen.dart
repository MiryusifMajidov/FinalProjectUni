import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import 'settings_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = Color(0xFF0A0A0B);
const _kSurface      = Color(0xFF131316);
const _kCard         = Color(0xFF1A1A1E);
const _kCardElevated = Color(0xFF1E1E23);
const _kAmber        = Color(0xFFE8B960);
const _kAmberGlow    = Color(0x24E8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kBorder       = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late bool _masterEnabled;

  // GAME
  bool _gameInvites    = true;
  bool _yourTurn       = true;
  bool _clockWarnings  = false;

  // COMMUNITY
  bool _tournaments    = true;
  bool _messages       = true;
  bool _friendRequests = true;

  // QUIET HOURS
  bool   _doNotDisturb = true;
  String _dndStart     = '22:00';
  String _dndEnd       = '08:00';

  /// Tracks whether Firestore prefs have been loaded at least once.
  /// Prevents a late-arriving stream update from overwriting a toggle
  /// the user just changed in this session.
  bool _firestoreLoaded = false;

  @override
  void initState() {
    super.initState();
    _masterEnabled = ref.read(settingsProvider).notificationsEnabled;
    final c    = ref.read(cacheServiceProvider);
    final user = ref.read(currentUserProvider).valueOrNull;

    // Local cache as initial values (instant, no network needed)
    _clockWarnings = c.notifClockWarnings; // local-only
    _doNotDisturb  = c.notifDoNotDisturb;  // local-only
    _dndStart      = c.notifDndStart;
    _dndEnd        = c.notifDndEnd;

    if (user != null) {
      // Firestore values already available → use them (cross-device sync)
      _gameInvites    = user.notifGameInvites;
      _yourTurn       = user.notifYourTurn;
      _tournaments    = user.notifTournaments;
      _messages       = user.notifMessages;
      _friendRequests = user.notifFriendRequests;
      _firestoreLoaded = true;
    } else {
      // Firestore not yet loaded → fall back to cache
      _gameInvites    = c.notifGameInvites;
      _yourTurn       = c.notifYourTurn;
      _tournaments    = c.notifTournaments;
      _messages       = c.notifMessages;
      _friendRequests = c.notifFriendRequests;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _haptic() {
    if (ref.read(cacheServiceProvider).hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// Toggles the master push-notifications switch.
  ///
  /// * Persists the new value locally via [settingsProvider].
  /// * When **disabled**: removes the FCM token from Firestore so Cloud
  ///   Functions have no token to push to.
  /// * When **enabled**: re-registers the FCM token so delivery resumes.
  Future<void> _onMasterToggle() async {
    _haptic();
    final v = !_masterEnabled;
    setState(() => _masterEnabled = v);
    ref.read(settingsProvider.notifier).toggleNotifications();

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final fs = ref.read(firestoreServiceProvider);
    try {
      if (v) {
        // Re-register device so Cloud Functions can push again.
        final token = await NotificationService().getToken();
        if (token != null && token.isNotEmpty) {
          await fs.saveFcmToken(uid, token);
        }
      } else {
        // Unregister device — Cloud Functions will find no valid token.
        await fs.removeFcmToken(uid);
      }
    } catch (_) {
      // Non-critical — Firestore may be offline; local pref still applied.
    }
  }

  /// Persist current notification prefs to Firestore so Cloud Functions can read them.
  Future<void> _syncToFirestore() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).setNotificationPrefs(uid, {
      'notifGameInvites':    _gameInvites,
      'notifYourTurn':       _yourTurn,
      'notifMessages':       _messages,
      'notifFriendRequests': _friendRequests,
      'notifTournaments':    _tournaments,
    });
  }

  Future<void> _showDndTimePicker() async {
    if (!_doNotDisturb) return;
    final startParts = _dndStart.split(':');
    final startTime = TimeOfDay(
      hour:   int.parse(startParts[0]),
      minute: int.parse(startParts[1]),
    );

    final newStart = await showTimePicker(
      context: context,
      initialTime: startTime,
      helpText: 'QUIET HOURS START',
      builder: (ctx, child) => _timepickerTheme(ctx, child),
    );
    if (newStart == null || !mounted) return;

    final endParts = _dndEnd.split(':');
    final endTime = TimeOfDay(
      hour:   int.parse(endParts[0]),
      minute: int.parse(endParts[1]),
    );

    final newEnd = await showTimePicker(
      context: context,
      initialTime: endTime,
      helpText: 'QUIET HOURS END',
      builder: (ctx, child) => _timepickerTheme(ctx, child),
    );
    if (newEnd == null || !mounted) return;

    final startStr =
        '${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}';

    setState(() {
      _dndStart = startStr;
      _dndEnd   = endStr;
    });

    final c = ref.read(cacheServiceProvider);
    await c.setNotifDndStart(startStr);
    await c.setNotifDndEnd(endStr);
  }

  Widget _timepickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.dark(
          primary:    _kAmber,
          onPrimary:  Color(0xFF1A1205),
          surface:    _kCard,
          onSurface:  _kInk,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: _kCard),
      ),
      child: child!,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If user data arrives after initState (e.g. first launch / cold stream),
    // sync once from Firestore values so cross-device prefs are respected.
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
      final user = next.valueOrNull;
      if (user != null && !_firestoreLoaded) {
        _firestoreLoaded = true;
        setState(() {
          _gameInvites    = user.notifGameInvites;
          _yourTurn       = user.notifYourTurn;
          _tournaments    = user.notifTournaments;
          _messages       = user.notifMessages;
          _friendRequests = user.notifFriendRequests;
        });
      }
    });

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: _kInkDim,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'notifications'.tr(),
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
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const SizedBox(height: 16),

                  // ── Master switch hero card ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kCardElevated, _kCard],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _kAmberGlow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _kAmber.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIcons.bell(PhosphorIconsStyle.fill),
                                color: _kAmber,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Push notifications',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _kInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _masterEnabled
                                      ? 'All channels enabled'
                                      : 'All channels disabled',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _kInkMute,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _DesignToggle(
                            on: _masterEnabled,
                            onToggle: () { _onMasterToggle(); },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── GAME, COMMUNITY, QUIET HOURS — dimmed & blocked when master off ──
                  AnimatedOpacity(
                    opacity: _masterEnabled ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 250),
                    child: AbsorbPointer(
                      absorbing: !_masterEnabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── GAME group ─────────────────────────────────
                          _sectionLabel('GAME'),
                          _SettingsGroup(children: [
                            _SettingsRow(
                              icon: PhosphorIcons.sword(PhosphorIconsStyle.fill),
                              label: 'Game invites',
                              right: _DesignToggle(
                                on: _gameInvites,
                                onToggle: () {
                                  _haptic();
                                  final v = !_gameInvites;
                                  setState(() => _gameInvites = v);
                                  ref.read(cacheServiceProvider).setNotifGameInvites(v);
                                  _syncToFirestore();
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.cursor(PhosphorIconsStyle.regular),
                              label: 'Your turn',
                              right: _DesignToggle(
                                on: _yourTurn,
                                onToggle: () {
                                  _haptic();
                                  final v = !_yourTurn;
                                  setState(() => _yourTurn = v);
                                  ref.read(cacheServiceProvider).setNotifYourTurn(v);
                                  _syncToFirestore();
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.clockCountdown(
                                  PhosphorIconsStyle.regular),
                              label: 'Clock warnings',
                              right: _DesignToggle(
                                on: _clockWarnings,
                                onToggle: () {
                                  _haptic();
                                  final v = !_clockWarnings;
                                  setState(() => _clockWarnings = v);
                                  ref
                                      .read(cacheServiceProvider)
                                      .setNotifClockWarnings(v);
                                },
                              ),
                              isLast: true,
                            ),
                          ]),

                          const SizedBox(height: 20),

                          // ── COMMUNITY group ────────────────────────────
                          _sectionLabel('COMMUNITY'),
                          _SettingsGroup(children: [
                            _SettingsRow(
                              icon: PhosphorIcons.trophy(PhosphorIconsStyle.regular),
                              label: 'Tournaments',
                              right: _DesignToggle(
                                on: _tournaments,
                                onToggle: () {
                                  _haptic();
                                  final v = !_tournaments;
                                  setState(() => _tournaments = v);
                                  ref.read(cacheServiceProvider).setNotifTournaments(v);
                                  _syncToFirestore();
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                              label: 'Messages',
                              right: _DesignToggle(
                                on: _messages,
                                onToggle: () {
                                  _haptic();
                                  final v = !_messages;
                                  setState(() => _messages = v);
                                  ref.read(cacheServiceProvider).setNotifMessages(v);
                                  _syncToFirestore();
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.userPlus(PhosphorIconsStyle.regular),
                              label: 'Friend requests',
                              right: _DesignToggle(
                                on: _friendRequests,
                                onToggle: () {
                                  _haptic();
                                  final v = !_friendRequests;
                                  setState(() => _friendRequests = v);
                                  ref.read(cacheServiceProvider).setNotifFriendRequests(v);
                                  _syncToFirestore();
                                },
                              ),
                              isLast: true,
                            ),
                          ]),

                          const SizedBox(height: 20),

                          // ── QUIET HOURS group ──────────────────────────
                          _sectionLabel('QUIET HOURS'),
                          _SettingsGroup(children: [
                            _SettingsRow(
                              icon: PhosphorIcons.moon(PhosphorIconsStyle.regular),
                              label: 'Do not disturb',
                              sub: _doNotDisturb
                                  ? '$_dndStart — $_dndEnd  ·  tap to change'
                                  : 'Disabled',
                              onTap: _doNotDisturb ? _showDndTimePicker : null,
                              right: _DesignToggle(
                                on: _doNotDisturb,
                                onToggle: () {
                                  _haptic();
                                  final v = !_doNotDisturb;
                                  setState(() => _doNotDisturb = v);
                                  ref
                                      .read(cacheServiceProvider)
                                      .setNotifDoNotDisturb(v);
                                },
                              ),
                              isLast: true,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kInkMute,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Shared local widgets ───────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Widget? right;
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
    this.right,
    this.onTap,
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
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Center(
                    child: Icon(icon, color: _kAmber, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
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
                          color: _kInk,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub!,
                          style:
                              GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                        ),
                      ],
                    ],
                  ),
                ),
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
          border: Border.all(color: on ? _kAmber : _kBorderStrong),
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

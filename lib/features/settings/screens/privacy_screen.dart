import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/firestore_service.dart';
import 'settings_screen.dart';
import '../../../core/legal/legal_texts.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = Color(0xFF0A0A0B);
const _kSurface      = Color(0xFF131316);
const _kCard         = Color(0xFF1A1A1E);
const _kAmber        = Color(0xFFE8B960);
const _kAmberGlow    = Color(0x24E8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kBorder       = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  // Visibility
  late String _profileVisibility;
  late bool   _onlineStatus;
  late bool   _showLocation;
  late bool   _invisibleMode;

  // Interactions
  late String _messagePrivacy;
  late String _friendRequestPrivacy;
  late String _challengePrivacy;

  @override
  void initState() {
    super.initState();
    final cache    = ref.read(cacheServiceProvider);
    final settings = ref.read(settingsProvider);
    final user     = ref.read(currentUserProvider).valueOrNull;

    _profileVisibility    = cache.profileVisibility;
    _onlineStatus         = user?.showOnlineStatus ?? cache.onlineStatus;
    _showLocation         = user?.showOnMap ?? cache.showOnMap;
    _invisibleMode        = user?.invisibleMode ?? cache.invisibleMode;
    _messagePrivacy       = settings.messagePrivacy;
    _friendRequestPrivacy = user?.friendRequestPrivacy ?? 'everyone';
    _challengePrivacy     = user?.challengePrivacy ?? 'everyone';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

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
                    'privacy'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 22, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic, color: _kInk,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: Text(
                      'Control who can see your activity and contact you on Grandmaster.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _kInkMute, height: 1.5),
                    ),
                  ),

                  // ── VISIBILITY ────────────────────────────────────────────
                  _sectionLabel('VISIBILITY'),
                  _SettingsGroup(children: [
                    // Profile visibility – segmented
                    _SettingsRowRaw(
                      icon: PhosphorIcons.globe(PhosphorIconsStyle.regular),
                      label: 'Profile visibility',
                      right: _SegmentedPicker(
                        options: const ['Public', 'Friends', 'Private'],
                        selected: _profileVisibility,
                        onSelect: (v) {
                          setState(() => _profileVisibility = v);
                          ref.read(cacheServiceProvider).setProfileVisibility(v);
                          // Sync to Firestore so other users respect the setting
                          final uid = ref
                              .read(authStateProvider)
                              .valueOrNull
                              ?.uid;
                          if (uid != null) {
                            ref
                                .read(firestoreServiceProvider)
                                .updateProfileVisibility(uid, v)
                                .catchError((_) {});
                          }
                        },
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.wifiHigh(PhosphorIconsStyle.regular),
                      label: 'privacy_online_status'.tr(),
                      sub: "Show when you're online",
                      right: _DesignToggle(
                        on: _onlineStatus,
                        onToggle: () async {
                          final v = !_onlineStatus;
                          setState(() => _onlineStatus = v);
                          ref.read(cacheServiceProvider).setOnlineStatus(v);
                          final uid = ref.read(authStateProvider).valueOrNull?.uid;
                          if (uid != null) {
                            await ref
                                .read(firestoreServiceProvider)
                                .setOnlineStatus(uid, v);
                          }
                        },
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.mapPin(PhosphorIconsStyle.regular),
                      label: 'appear_on_map'.tr(),
                      sub: user?.showOnMap == true
                          ? 'appear_on_map_subtitle'.tr()
                          : 'Hidden from map',
                      right: _DesignToggle(
                        on: _showLocation,
                        onToggle: () => _toggleMapVisibility(user),
                      ),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── INTERACTIONS ──────────────────────────────────────────
                  _sectionLabel('INTERACTIONS'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                      label: 'who_can_message'.tr(),
                      sub: _messagePrivacyLabel(_messagePrivacy),
                      onTap: () => _showMessagePrivacySheet(),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.userPlus(PhosphorIconsStyle.regular),
                      label: 'privacy_friend_requests_setting'.tr(),
                      sub: _privacyLabel(_friendRequestPrivacy),
                      onTap: () => _showPrivacyPicker(
                        title: 'Who can send friend requests',
                        current: _friendRequestPrivacy,
                        onSelect: (v) async {
                          setState(() => _friendRequestPrivacy = v);
                          final uid = ref.read(authStateProvider).valueOrNull?.uid;
                          if (uid != null) {
                            await ref
                                .read(firestoreServiceProvider)
                                .setFriendRequestPrivacy(uid, v);
                          }
                        },
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.sword(PhosphorIconsStyle.regular),
                      label: 'privacy_challenges_setting'.tr(),
                      sub: _privacyLabel(_challengePrivacy),
                      onTap: () => _showPrivacyPicker(
                        title: 'Who can challenge you',
                        current: _challengePrivacy,
                        onSelect: (v) async {
                          setState(() => _challengePrivacy = v);
                          final uid = ref.read(authStateProvider).valueOrNull?.uid;
                          if (uid != null) {
                            await ref
                                .read(firestoreServiceProvider)
                                .setChallengePrivacy(uid, v);
                          }
                        },
                      ),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── BLOCKED ───────────────────────────────────────────────
                  _sectionLabel('BLOCKED'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.prohibit(PhosphorIconsStyle.regular),
                      label: 'block_list'.tr(),
                      sub: user?.blockedUsers.isEmpty == true
                          ? 'None'
                          : '${user?.blockedUsers.length} blocked',
                      onTap: () => context.push('/home/settings/privacy/blocked'),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.eyeSlash(PhosphorIconsStyle.regular),
                      label: 'privacy_invisible_mode'.tr(),
                      sub: 'Appear offline to everyone',
                      right: _DesignToggle(
                        on: _invisibleMode,
                        onToggle: () async {
                          final v = !_invisibleMode;
                          setState(() => _invisibleMode = v);
                          ref.read(cacheServiceProvider).setInvisibleMode(v);
                          final uid = ref.read(authStateProvider).valueOrNull?.uid;
                          if (uid != null) {
                            await ref
                                .read(firestoreServiceProvider)
                                .setInvisibleMode(uid, v);
                          }
                        },
                      ),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── DATA ──────────────────────────────────────────────────
                  _sectionLabel('DATA'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.regular),
                      label: 'Request data download',
                      onTap: () => _showDataSheet(user),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.regular),
                      label: 'Privacy policy',
                      onTap: () => _showPrivacyPolicy(),
                      isLast: true,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Data download sheet ────────────────────────────────────────────────────

  void _showDataSheet(dynamic user) {
    final lines = <String>[
      '══ Your Grandmaster Data ══',
      '',
      if (user != null) ...[
        'Username    : ${user.username}',
        'Email       : ${user.email}',
        'Member since: ${_fmtDate(user.createdAt)}',
        '',
        '── Ratings ─────────────────',
        'Bullet   : ${user.bulletStats.rating}  '
            '(W${user.bulletStats.wins}/D${user.bulletStats.draws}/L${user.bulletStats.losses})',
        'Blitz    : ${user.blitzStats.rating}  '
            '(W${user.blitzStats.wins}/D${user.blitzStats.draws}/L${user.blitzStats.losses})',
        'Rapid    : ${user.rapidStats.rating}  '
            '(W${user.rapidStats.wins}/D${user.rapidStats.draws}/L${user.rapidStats.losses})',
        '',
        '── Profile ──────────────────',
        'Visibility  : $_profileVisibility',
        'Show on map : $_showLocation',
        'Invisible   : $_invisibleMode',
      ] else
        '(Sign in to see your data)',
    ];
    final text = lines.join('\n');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _kInkMute,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your data',
              style: GoogleFonts.fraunces(
                fontSize: 18, fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic, color: _kInk,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.45,
              ),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Text(
                  text,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: _kInkDim, height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('copied'.tr()),
                    ),
                  );
                },
                icon: Icon(PhosphorIcons.copy(PhosphorIconsStyle.regular),
                    size: 16),
                label: Text('copy'.tr()),
                style: FilledButton.styleFrom(
                  backgroundColor: _kAmber,
                  foregroundColor: const Color(0xFF1A1205),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-'
      '${dt.day.toString().padLeft(2,'0')}';

  // ── Privacy policy sheet ───────────────────────────────────────────────────

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: _kInkMute,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Privacy Policy',
                    style: GoogleFonts.fraunces(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic, color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Last updated: September 2026',
                    style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2520), height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: kPolicyParagraphs.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    p,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _kInkDim, height: 1.6),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message privacy sheet ──────────────────────────────────────────────────

  void _showMessagePrivacySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              0, 12, 0, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: _kInkMute,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'who_can_message'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic, color: _kInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...([
                ('everyone', 'everyone'.tr()),
                ('friends',  'friends_only'.tr()),
                ('nobody',   'nobody'.tr()),
              ].map((opt) => RadioListTile<String>(
                value: opt.$1,
                groupValue: _messagePrivacy,
                onChanged: (v) async {
                  if (v == null) return;
                  setModal(() {});
                  setState(() => _messagePrivacy = v);
                  ref.read(settingsProvider.notifier).setMessagePrivacy(v);
                  final uid = ref.read(authStateProvider).valueOrNull?.uid;
                  if (uid != null) {
                    ref.read(firestoreServiceProvider)
                        .setMessagePrivacy(uid, v)
                        .catchError((_) {});
                  }
                  Navigator.pop(ctx);
                },
                title: Text(opt.$2,
                    style: GoogleFonts.inter(fontSize: 14, color: _kInk)),
                activeColor: _kAmber,
                dense: true,
              ))),
            ],
          ),
        ),
      ),
    );
  }

  // ── Map visibility toggle ──────────────────────────────────────────────────

  Future<void> _toggleMapVisibility(dynamic user) async {
    final notifier = ref.read(settingsProvider.notifier);
    if (_showLocation) {
      // Turn off
      setState(() => _showLocation = false);
      notifier.setShowOnMap(false);
      if (user != null) {
        try {
          await ref.read(firestoreServiceProvider).updateMapSettings(
                user.uid,
                showOnMap: false,
              );
        } catch (_) {}
      }
      return;
    }

    // Turn on – just flip the Firestore visibility flag (no OS permission here)
    setState(() => _showLocation = true);
    notifier.setShowOnMap(true);
    if (user != null) {
      try {
        await ref.read(firestoreServiceProvider).updateMapSettings(
              user.uid,
              showOnMap: true,
            );
      } catch (_) {}
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _messagePrivacyLabel(String v) => switch (v) {
        'friends' => 'friends_only'.tr(),
        'nobody'  => 'nobody'.tr(),
        _         => 'everyone'.tr(),
      };

  String _privacyLabel(String v) => switch (v) {
        'friends' => 'friends_only'.tr(),
        'nobody'  => 'nobody'.tr(),
        _         => 'everyone'.tr(),
      };

  void _showPrivacyPicker({
    required String title,
    required String current,
    required Future<void> Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              0, 12, 0, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: _kInkMute,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: GoogleFonts.fraunces(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic, color: _kInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...([
                ('everyone', 'everyone'.tr()),
                ('nobody',   'nobody'.tr()),
              ].map((opt) => RadioListTile<String>(
                value: opt.$1,
                groupValue: current,
                onChanged: (v) async {
                  if (v == null) return;
                  setModal(() {});
                  await onSelect(v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                title: Text(opt.$2,
                    style: GoogleFonts.inter(fontSize: 14, color: _kInk)),
                activeColor: _kAmber,
                dense: true,
              ))),
            ],
          ),
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
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _kInkMute, letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Segmented picker ──────────────────────────────────────────────────────────

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: isSelected ? _kAmberGlow : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isSelected ? _kAmber : _kBorder),
            ),
            child: Text(
              opt,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? _kAmber : _kInkDim,
              ),
            ),
          ),
        );
      }).toList(),
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

class _SettingsRowRaw extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget right;

  const _SettingsRowRaw({
    required this.icon,
    required this.label,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Center(child: Icon(icon, color: _kAmber, size: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kInk)),
              ),
              right,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 58),
          child: Container(height: 1, color: _kBorder),
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
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Center(child: Icon(icon, color: _kAmber, size: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _kInk)),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(sub!,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _kInkMute)),
                      ],
                    ],
                  ),
                ),
                right ??
                    Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                        color: _kInkMute, size: 16),
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
        width: 40, height: 24,
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
              width: 18, height: 18,
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

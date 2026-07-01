import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF0A0A0B);
const _kSurface   = Color(0xFF131316);
const _kCard      = Color(0xFF1A1A1E);
const _kAmber     = Color(0xFFE8B960);
const _kAmberGlow = Color(0x24E8B960);
const _kInk       = Color(0xFFF5F3EF);
const _kInkDim    = Color(0xFFB0A898);
const _kInkMute   = Color(0xFF706860);
const _kBorder    = Color(0xFF2A2520);
const _kLoss      = Color(0xFFF07079);
const _kWin       = Color(0xFF5AB67A);

class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return const Scaffold(backgroundColor: _kBg);

    // Watch so the "This device" badge reacts instantly when the session ID
    // is set (e.g. restored from SharedPreferences just after cold-start).
    final currentSessionId = ref.watch(currentSessionIdProvider);

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
                  Expanded(
                    child: Text(
                      'active_sessions'.tr(),
                      style: GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: _kInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: ref.read(firestoreServiceProvider).watchSessions(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _kAmber),
                    );
                  }

                  final sessions = snap.data ?? [];

                  if (sessions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.deviceMobile(PhosphorIconsStyle.regular),
                            color: _kInkMute, size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'no_sessions_yet'.tr(),
                            style: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'sessions_appear_after_login'.tr(),
                            style: GoogleFonts.inter(fontSize: 12, color: _kInkMute),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                    children: [
                      Text(
                        'sessions_device_count'.tr(namedArgs: {'count': sessions.length.toString()}),
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: _kInkMute, letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBorder),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          children: sessions.asMap().entries.map((e) {
                            final i = e.key;
                            final s = e.value;
                            final isCurrent = s['id'] == currentSessionId;
                            return _SessionTile(
                              session: s,
                              isCurrent: isCurrent,
                              isLast: i == sessions.length - 1,
                              onRevoke: isCurrent
                                  ? null
                                  : () async {
                                      await ref
                                          .read(firestoreServiceProvider)
                                          .deleteSession(uid, s['id'] as String);
                                    },
                            );
                          }).toList(),
                        ),
                      ),

                      // ── Sign out all others ──────────────────────────────
                      if (sessions.length > 1) ...[
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => _confirmSignOutAll(context, ref, uid, currentSessionId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _kLoss.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'sign_out_all_others'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kLoss,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Text(
                        'sessions_expire_info'.tr(),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kInkMute, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOutAll(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String? currentSessionId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: _kInkMute, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Icon(PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill),
                color: _kLoss, size: 32),
            const SizedBox(height: 12),
            Text(
              'Sign out all other devices?',
              style: GoogleFonts.fraunces(
                fontSize: 18, fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic, color: _kInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will remove all sessions except the current one.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _kInkMute, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Center(
                        child: Text('cancel'.tr(),
                            style: GoogleFonts.inter(color: _kInkDim, fontSize: 13)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (currentSessionId != null) {
                        await ref
                            .read(firestoreServiceProvider)
                            .deleteOtherSessions(uid, currentSessionId);
                      }
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kLoss.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kLoss.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          'sign_out'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _kLoss,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isCurrent;
  final bool isLast;
  final VoidCallback? onRevoke;

  const _SessionTile({
    required this.session,
    required this.isCurrent,
    required this.isLast,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final device   = (session['deviceModel'] as String?) ?? 'Unknown device';
    final os       = (session['os'] as String?) ?? '';
    final loginTs  = session['loginAt'] as Timestamp?;
    final activeTs = session['lastActiveAt'] as Timestamp?;
    final loginStr = loginTs != null ? _fmtDate(loginTs.toDate()) : 'Unknown';
    final activeStr = activeTs != null ? _timeAgo(activeTs.toDate()) : 'Unknown';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isCurrent ? _kAmberGlow : _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? _kAmber.withValues(alpha: 0.4)
                        : _kBorder,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _osIcon(os),
                    color: isCurrent ? _kAmber : _kInkMute,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _kInk,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kWin.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: _kWin.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              'this_device'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _kWin,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$os  ·  Logged in $loginStr',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _kInkMute),
                    ),
                    Text(
                      'Last active: $activeStr',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _kInkMute),
                    ),
                  ],
                ),
              ),
              if (onRevoke != null)
                GestureDetector(
                  onTap: onRevoke,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _kLoss.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _kLoss.withValues(alpha: 0.25)),
                    ),
                    child: Icon(
                      PhosphorIcons.x(PhosphorIconsStyle.bold),
                      color: _kLoss, size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Container(height: 1, color: _kBorder),
          ),
      ],
    );
  }

  IconData _osIcon(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('android')) return PhosphorIcons.androidLogo(PhosphorIconsStyle.fill);
    if (lower.contains('ios') || lower.contains('iphone')) return PhosphorIcons.appleLogo(PhosphorIconsStyle.fill);
    return PhosphorIcons.deviceMobile(PhosphorIconsStyle.regular);
  }

  String _fmtDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// currentSessionIdProvider is defined in auth_service.dart

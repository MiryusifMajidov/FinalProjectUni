import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/otp_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF0A0A0B);
const _kSurface  = Color(0xFF131316);
const _kCard     = Color(0xFF1A1A1E);
const _kAmber    = Color(0xFFE8B960);
const _kAmberDeep = Color(0xFFC49A45);
const _kAmberGlow = Color(0x24E8B960);
const _kInk      = Color(0xFFF5F3EF);
const _kInkDim   = Color(0xFFB0A898);
const _kInkMute  = Color(0xFF706860);
const _kInkFaint = Color(0xFF3D3530);
const _kBorder   = Color(0xFF2A2520);

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = 'v${info.version} · Build ${info.buildNumber}');
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
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
                    'about'.tr(),
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
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // ── Hero section ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Glow backdrop
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _kAmber.withValues(alpha: 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            // Knight icon box
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_kAmber, _kAmberDeep],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kAmber.withValues(alpha: 0.35),
                                    blurRadius: 36,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '♞',
                                  style: TextStyle(
                                    fontSize: 42,
                                    color: const Color(0xFF1A1205),
                                    fontFamily:
                                        'serif', // system chess rendering
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'CheckMate',
                              style: GoogleFonts.fraunces(
                                fontSize: 26,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                color: _kInk,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (_version.isNotEmpty)
                              Text(
                                _version,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _kInkMute,
                                ),
                              ),
                            const SizedBox(height: 10),
                            // "MADE IN ŞƏKİ" amber pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kAmberGlow,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'MADE BY LUDODO',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _kAmber,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Quote ─────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                    child: Text(
                      '"The board is set, the pieces move. All we have to decide is what to do with the time given to us."',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fraunces(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: _kInkDim,
                        height: 1.55,
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── LEARN ─────────────────────────────────────────────────
                  _sectionLabel('LEARN'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.sparkle(PhosphorIconsStyle.regular),
                      label: "What's new",
                      sub: 'Arena Tournaments · Groups · Player Map',
                      onTap: () => _snack(context, "What's new — coming soon"),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.note(PhosphorIconsStyle.regular),
                      label: 'Release notes',
                      onTap: () => _snack(context, 'Release notes — coming soon'),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.roadHorizon(PhosphorIconsStyle.regular),
                      label: 'Roadmap',
                      onTap: () => _snack(context, 'Public roadmap — coming soon'),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── LEGAL ─────────────────────────────────────────────────
                  _sectionLabel('LEGAL'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.scroll(PhosphorIconsStyle.regular),
                      label: 'Terms of service',
                      onTap: () => _snack(context, 'Terms of service — coming soon'),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.regular),
                      label: 'Privacy policy',
                      onTap: () => _snack(context, 'Privacy policy — coming soon'),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── CONNECT ───────────────────────────────────────────────
                  _sectionLabel('CONNECT'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.discordLogo(PhosphorIconsStyle.regular),
                      label: 'Join the community',
                      sub: 'Discord · Telegram',
                      onTap: () => _snack(context, 'Community links coming soon'),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.chatDots(PhosphorIconsStyle.regular),
                      label: 'send_feedback'.tr(),
                      onTap: () => _showFeedbackSheet(context, ref),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.bug(PhosphorIconsStyle.regular),
                      label: 'report_bug_label'.tr(),
                      onTap: () => _showFeedbackSheet(context, ref, isBug: true),
                      isLast: true,
                    ),
                  ]),

                  // ── Footer ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
                    child: Center(
                      child: Text(
                        '© 2026 CHECKMATE · ALL RIGHTS RESERVED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: _kInkFaint,
                          letterSpacing: 0.5,
                        ),
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

  static void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  void _showFeedbackSheet(BuildContext context, WidgetRef ref,
      {bool isBug = false}) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool sending  = false;
        String? error = null;
        return StatefulBuilder(
          builder: (ctx, setModal) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),
                Text(
                  isBug ? 'report_bug_label'.tr() : 'send_feedback'.tr(),
                  style: GoogleFonts.fraunces(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic, color: _kInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isBug
                      ? 'Describe what happened and how to reproduce it.'
                      : 'We read every message — thank you for helping improve CheckMate.',
                  style: GoogleFonts.inter(fontSize: 12, color: _kInkMute, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  maxLines: 5,
                  autofocus: true,
                  style: GoogleFonts.inter(color: _kInk, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isBug ? 'Describe the bug…' : 'Your feedback…',
                    hintStyle: GoogleFonts.inter(color: _kInkMute),
                    filled: true,
                    fillColor: _kSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kAmber),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF07079)),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: sending ? null : () async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      setModal(() { sending = true; error = null; });

                      try {
                        final fbUser  = ref.read(authStateProvider).valueOrNull;
                        final uid      = fbUser?.uid ?? 'anonymous';
                        final curUser  = ref.read(currentUserProvider).valueOrNull;
                        final username = curUser?.username ?? uid;
                        final email    = fbUser?.email ?? '';

                        // Collect device + version metadata.
                        String? appVersion;
                        String? deviceInfo;
                        try {
                          final pkg = await PackageInfo.fromPlatform();
                          appVersion = '${pkg.version}+${pkg.buildNumber}';
                        } catch (_) {}
                        try {
                          final di = DeviceInfoPlugin();
                          final android = await di.androidInfo;
                          deviceInfo = '${android.manufacturer} ${android.model} / Android ${android.version.release}';
                        } catch (_) {
                          try {
                            final ios = await DeviceInfoPlugin().iosInfo;
                            deviceInfo = '${ios.name} ${ios.systemVersion}';
                          } catch (_) {}
                        }

                        // Primary: save to Firestore (required).
                        await ref.read(firestoreServiceProvider).saveFeedback(
                          uid: uid,
                          username: username,
                          email: email,
                          text: text,
                          isBug: isBug,
                          appVersion: appVersion,
                          deviceInfo: deviceInfo,
                        );

                        // Secondary: email notification (best-effort).
                        try {
                          await ref.read(otpServiceProvider).sendFeedbackEmail(
                            fromUsername: username,
                            fromEmail: email,
                            text: text,
                            isBug: isBug,
                            appVersion: appVersion,
                            deviceInfo: deviceInfo,
                          );
                        } catch (_) {
                          // Email failed — Firestore backup still received it.
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isBug
                                  ? 'Bug report sent — thank you!'
                                  : 'Feedback sent — thank you!'),
                            ),
                          );
                        }
                      } catch (e) {
                        setModal(() {
                          sending = false;
                          error = 'Failed to send. Please try again.';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAmber,
                      foregroundColor: const Color(0xFF1A1205),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF1A1205)),
                          )
                        : Text(
                            'send_feedback'.tr(),
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
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

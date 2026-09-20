import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _registerBundledAssetLicences();
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
                      onTap: () => _showDocSheet(
                        context,
                        title: "What's new",
                        subtitle: _version.isEmpty ? 'This release' : _version,
                        paragraphs: _kWhatsNewParagraphs,
                      ),
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
                      onTap: () => _showDocSheet(
                        context,
                        title: 'Terms of Service',
                        subtitle: 'Last updated: $_kLegalUpdated',
                        paragraphs: _kTermsParagraphs,
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.regular),
                      label: 'Privacy policy',
                      onTap: () => _showDocSheet(
                        context,
                        title: 'Privacy Policy',
                        subtitle: 'Last updated: $_kLegalUpdated',
                        paragraphs: _kPolicyParagraphs,
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.certificate(PhosphorIconsStyle.regular),
                      label: 'Third-party licences',
                      sub: 'Open-source packages, piece sets, map data',
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'CheckMate',
                        applicationVersion: _version,
                        applicationLegalese:
                            '© 2026 CheckMate · All rights reserved.',
                      ),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── CONNECT ───────────────────────────────────────────────
                  _sectionLabel('CONNECT'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.lifebuoy(PhosphorIconsStyle.regular),
                      label: 'Contact support',
                      sub: _kSupportEmail,
                      onTap: () => _showSupportSheet(context),
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

  // ── Document sheet (privacy policy, terms, what's new) ─────────────────────

  void _showDocSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> paragraphs,
  }) {
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
                    title,
                    style: GoogleFonts.fraunces(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic, color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                  ),
                ],
              ),
            ),
            const Divider(color: _kBorder, height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: paragraphs
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            p,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: _kInkDim, height: 1.6),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Support sheet ──────────────────────────────────────────────────────────

  void _showSupportSheet(BuildContext context) {
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
            const SizedBox(height: 18),
            Text(
              'Contact support',
              style: GoogleFonts.fraunces(
                fontSize: 18, fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic, color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Write to us for account, billing or safety questions. '
              'We reply within 3 business days. For bugs and ideas, the in-app '
              'forms below reach us faster because they attach your app version '
              'and device model.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _kInkMute, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                _kSupportEmail,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, color: _kInk, letterSpacing: 0.2),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      const ClipboardData(text: _kSupportEmail));
                  Navigator.pop(ctx);
                  _snack(context, 'Support address copied');
                },
                icon: Icon(PhosphorIcons.copy(PhosphorIconsStyle.regular),
                    size: 16),
                label: Text(
                  'Copy address',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _kAmber,
                  foregroundColor: const Color(0xFF1A1205),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

// ── Legal content ─────────────────────────────────────────────────────────────

const _kLegalUpdated  = '21 September 2026';
const _kSupportEmail  = 'privacy@grandmasterapp.com';
const _kPrivacyUrl    = 'https://chess-ac4eb.web.app/privacy';
const _kTermsUrl      = 'https://chess-ac4eb.web.app/terms';

const _kWhatsNewParagraphs = [
  'Arena Tournaments\n'
  'Timed arenas you can join from the lobby. Pairings are automatic, the '
  'leaderboard updates live, and your arena results feed into your normal '
  'rating history.',

  'Groups\n'
  'Create or join a group, chat with its members and challenge them directly '
  'without adding everyone as a friend first.',

  'Player Map\n'
  'See other players near you and challenge them. The map is opt-in: your '
  'location is only shared while "Appear on Player Map" is on in Settings → Privacy, '
  'and turning it off removes your pin immediately.',

  'Elsewhere in this release\n'
  'Six bot difficulty tiers backed by the Stockfish Online API, three chess '
  'piece sets, ten interface languages, and a redesigned profile with '
  'per-time-control rating breakdowns.',
];

const _kPolicyParagraphs = [
  'This policy explains what CheckMate collects, why, and what you can do '
  'about it. The same text is published at $_kPrivacyUrl.',

  '1. Information We Collect\n'
  'Account: your email address and username, handled by Firebase '
  'Authentication. Profile: an optional profile photo, stored in Firebase '
  'Storage. Play: game history, moves, ratings and tournament results. '
  'Social: chat messages, friend lists, group membership and block lists, '
  'stored in Cloud Firestore. Technical: app version, device model and OS '
  'version, attached to feedback and bug reports you send us. We do not ask '
  'for your real name, phone number or payment details.',

  '2. Location and the Player Map\n'
  'The nearby-players map is opt-in and off by default. If you turn on '
  '"Appear on Player Map" in Settings → Privacy, the app asks the operating system '
  'for your location and stores your latest coordinates so other players can '
  'see your pin on a public map. Anyone using the app can see the pins. Turn '
  '"Appear on Player Map" off at any time to stop sharing and remove your pin; you '
  'can also revoke location permission in your device settings.',

  '3. Notifications\n'
  'If you allow notifications, Firebase Cloud Messaging issues a device token '
  'that we store so we can send you game invites, move alerts and messages. '
  'You can turn notifications off in Settings → Notifications or in your '
  'device settings.',

  '4. How We Use Your Information\n'
  'To run your account and your games; to show ratings and leaderboards; to '
  'deliver the notifications you opted into; to answer support requests; and '
  'to detect cheating, abuse and other conduct that breaks our terms.',

  '5. Third-Party Services\n'
  'Firebase (Google) hosts authentication, the database, file storage, '
  'messaging and server functions. Bot moves and post-game analysis send the '
  'board position to the Stockfish Online API at stockfish.online, which also '
  'receives your IP address; we do not send your username or email with it. '
  'The player map loads tiles from tile.openstreetmap.org, which receives '
  'your IP address and the area of the map you are viewing. Interface fonts '
  'are fetched from fonts.gstatic.com, which receives your IP address. Each '
  'of these providers handles that data under its own privacy policy.',

  '6. Information Sharing\n'
  'We do not sell your personal information and we do not run advertising '
  'networks in the app. Your username, rating, game history and — if you '
  'enabled it — your map pin are visible to other players. Your email address '
  'is never shown publicly. We may disclose information if the law requires '
  'it, or to investigate abuse or security incidents.',

  '7. Deleting Your Account\n'
  'You can delete your account from inside the app: Settings → Account → '
  'Delete account. Deleting removes your profile, photo, chat messages, '
  'friend and block lists, map location and device tokens. Finished games may '
  'be kept in a form that no longer identifies you, so that your opponents\' '
  'own game records and ratings stay intact.',

  '8. Data Retention\n'
  'Account and profile data is kept while your account exists. Chat messages '
  'are kept until you or your account are deleted. Map coordinates are '
  'overwritten each time they update and removed when you leave the map. '
  'Feedback and bug reports are kept for up to 24 months. Backups may hold '
  'deleted data for up to 30 days before they roll over.',

  '9. Security\n'
  'Traffic is encrypted with TLS, and access to stored data is restricted by '
  'Firebase security rules. No method of transmission or storage is completely '
  'secure, so we cannot guarantee absolute security.',

  '10. Children\'s Privacy\n'
  'CheckMate is not directed to children under 13, and we do not knowingly '
  'collect personal information from them. If you believe a child under 13 has '
  'created an account, write to $_kSupportEmail and we will remove it.',

  '11. Your Choices\n'
  'Settings → Privacy controls who can message, challenge or friend you, who '
  'sees your online status, and whether you appear on the map. Settings → '
  'Privacy → Request data download shows a copy of your account data. '
  'Settings → Account → Delete account removes it.',

  '12. Changes to This Policy\n'
  'We may update this policy. Significant changes will be reflected in the '
  '"Last updated" date above and in the published web version.',

  '13. Contact\n'
  'Questions about this policy or your data: $_kSupportEmail.',
];

const _kTermsParagraphs = [
  'These terms are an agreement between you and the developer of CheckMate, '
  'not with Apple or Google. The same text is published at $_kTermsUrl.',

  '1. Acceptance\n'
  'By downloading or using CheckMate you accept these terms. If you do not '
  'accept them, do not use the app.',

  '2. Licence\n'
  'We grant you a personal, non-transferable, non-exclusive licence to use '
  'CheckMate on any device that you own or control, as permitted by the App '
  'Store or Google Play usage rules for the store you installed it from. The '
  'app is licensed, not sold. You may not copy, sell, rent, sublicense, '
  'reverse-engineer or modify the app, or attempt to extract its source code, '
  'except where the law expressly allows it.',

  '3. Your Account\n'
  'You are responsible for the account you create and for everything done '
  'through it. Keep your credentials to yourself, give accurate information, '
  'and tell us at $_kSupportEmail if you believe someone else is using your '
  'account. You must be at least 13 years old to hold an account.',

  '4. Acceptable Use\n'
  'While using CheckMate you must not: harass, threaten, stalk or abuse other '
  'players; use a chess engine, external assistance or another person to '
  'choose your moves in rated or tournament play; use multiple accounts, '
  'sandbag or manipulate ratings and leaderboards; post or send illegal, '
  'hateful, sexual or otherwise offensive content, including in usernames, '
  'profile photos and chat; impersonate anyone; upload malware; or scrape, '
  'automate or overload the service.',

  '5. Your Content\n'
  'You keep ownership of the content you upload, such as your profile photo '
  'and messages. You give us the limited right to store, display and transmit '
  'that content so the app can work — for example, showing your photo to your '
  'opponents. You are responsible for having the rights to whatever you '
  'upload.',

  '6. Moderation and Termination\n'
  'We may limit, suspend or terminate an account that breaks these terms, '
  'including for cheating or harassment, and may remove content that breaks '
  'them. You may stop using the app at any time and delete your account from '
  'Settings → Account → Delete account. Termination ends the licence in '
  'section 2.',

  '7. No Warranty\n'
  'CheckMate is provided "as is" and "as available", without warranties of '
  'any kind, whether express or implied, including merchantability, fitness '
  'for a particular purpose and non-infringement. We do not warrant that the '
  'app will be uninterrupted, error-free or free of harmful components. Some '
  'jurisdictions do not allow the exclusion of implied warranties, so parts '
  'of this section may not apply to you.',

  '8. Limitation of Liability\n'
  'To the extent permitted by law, we are not liable for indirect, '
  'incidental, special or consequential damages, or for lost data or lost '
  'profits, arising out of your use of the app. Nothing here limits liability '
  'that cannot be limited by law.',

  '9. Third-Party Services\n'
  'The app relies on services we do not control, including Firebase (Google), '
  'the Stockfish Online API and OpenStreetMap tiles. Their availability is '
  'not guaranteed, and their own terms apply to your use of them. '
  'Attributions for bundled artwork and open-source components are listed '
  'under About → Third-party licences.',

  '10. Apple\n'
  'If you installed CheckMate from the App Store: this agreement is between '
  'you and us only, and Apple is not responsible for the app or its content. '
  'Apple has no obligation to provide maintenance or support. If the app '
  'fails to conform to any applicable warranty, you may notify Apple and '
  'Apple will refund the purchase price, if any; to the maximum extent '
  'permitted by law, Apple has no other warranty obligation. We, not Apple, '
  'are responsible for addressing claims about the app, including product '
  'liability, legal compliance and intellectual-property claims. You confirm '
  'you are not located in a country subject to a U.S. Government embargo or '
  'designated as terrorist-supporting, and that you are not on any U.S. '
  'restricted-party list. Apple and its subsidiaries are third-party '
  'beneficiaries of this agreement and may enforce it against you.',

  '11. Changes\n'
  'We may update these terms. Continuing to use the app after an update means '
  'you accept the revised terms, which will carry a new "Last updated" date.',

  '12. Contact\n'
  'Questions about these terms: $_kSupportEmail.',
];

// ── Bundled-asset licences (shown by showLicensePage) ─────────────────────────

bool _extraLicencesRegistered = false;

/// Registers licences for assets that ship with the app but are not Dart
/// packages, so they appear alongside the package licences in showLicensePage.
void _registerBundledAssetLicences() {
  if (_extraLicencesRegistered) return;
  _extraLicencesRegistered = true;

  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['CheckMate assets: cburnett piece set'],
      'Chess piece set "cburnett" by Colin M. L. Burnett.\n'
      'Source: Wikimedia Commons (the "Chess ___45.svg" series), also '
      'distributed with Lichess (lichess-org/lila).\n\n'
      'Used under the Creative Commons Attribution-ShareAlike 3.0 Unported '
      'licence (CC BY-SA 3.0): https://creativecommons.org/licenses/by-sa/3.0/\n'
      'Attribution is required and modified versions must be shared under the '
      'same licence. The Commons originals are multi-licensed (GFDL and a '
      'BSD-style licence are also offered); verify upstream terms before '
      'relying on a licence other than CC BY-SA 3.0.',
    );

    yield const LicenseEntryWithLineBreaks(
      ['CheckMate assets: merida piece set'],
      'Chess piece set "merida" by Armando Hernandez Marroquin.\n'
      'Distributed with Lichess (lichess-org/lila).\n\n'
      'The set is widely redistributed as free software, commonly stated as '
      'GPL-licensed. The exact licence text is not bundled here — verify '
      'upstream terms at https://github.com/lichess-org/lila before '
      'redistribution.',
    );

    yield const LicenseEntryWithLineBreaks(
      ['CheckMate assets: alpha piece set'],
      'Chess piece set "alpha" by Eric Bentzen.\n'
      'Distributed with Lichess (lichess-org/lila).\n\n'
      'Eric Bentzen\'s chess fonts have historically been published as free '
      'for personal, non-commercial use, which may not cover distribution '
      'inside a commercial app. Verify upstream terms and obtain permission, '
      'or remove this set, before relying on it.',
    );

    yield const LicenseEntryWithLineBreaks(
      ['CheckMate assets: OpenStreetMap'],
      'Player map data © OpenStreetMap contributors.\n'
      'Map data is available under the Open Database Licence (ODbL) 1.0: '
      'https://www.openstreetmap.org/copyright\n'
      'Map tiles are currently served by tile.openstreetmap.org under the '
      'OpenStreetMap Foundation Tile Usage Policy.',
    );

    yield const LicenseEntryWithLineBreaks(
      ['CheckMate services: Stockfish Online API'],
      'Bot moves and post-game analysis are computed by the Stockfish Online '
      'API (https://stockfish.online), a third-party HTTPS service that runs '
      'the Stockfish chess engine. Stockfish itself is published under the GNU '
      'General Public License version 3: https://stockfishchess.org\n\n'
      'This app does not bundle, link against or modify the Stockfish engine; '
      'it sends board positions to the API over the network and reads the '
      'result.',
    );
  });
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

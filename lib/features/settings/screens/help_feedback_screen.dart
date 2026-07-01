import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/otp_service.dart';

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
const _kWin       = Color(0xFF5AB67A);
const _kLoss      = Color(0xFFF07079);

class HelpFeedbackScreen extends ConsumerStatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  ConsumerState<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends ConsumerState<HelpFeedbackScreen> {
  bool _isBug = false;
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please describe your ${_isBug ? 'bug' : 'feedback'}');
      return;
    }

    setState(() { _sending = true; _error = null; });

    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) throw Exception('Not logged in');

      // Collect device + version info
      String? appVersion;
      String? deviceInfo;
      try {
        final pkgInfo = await PackageInfo.fromPlatform();
        appVersion = '${pkgInfo.version}+${pkgInfo.buildNumber}';
      } catch (_) {}
      try {
        final di = DeviceInfoPlugin();
        final android = await di.androidInfo;
        deviceInfo = '${android.manufacturer} ${android.model} / Android ${android.version.release}';
      } catch (_) {
        try {
          final di = DeviceInfoPlugin();
          final ios = await di.iosInfo;
          deviceInfo = '${ios.name} ${ios.systemVersion}';
        } catch (_) {}
      }

      // Primary: save to Firestore (required — this is the source of truth).
      await ref.read(firestoreServiceProvider).saveFeedback(
        uid: user.uid,
        username: user.username,
        email: user.email,
        text: text,
        isBug: _isBug,
        appVersion: appVersion,
        deviceInfo: deviceInfo,
      );

      // Secondary: email notification (best-effort — SMTP may be blocked on
      // mobile networks; Firestore backup already ensures nothing is lost).
      try {
        await ref.read(otpServiceProvider).sendFeedbackEmail(
          fromUsername: user.username,
          fromEmail: user.email,
          text: text,
          isBug: _isBug,
          appVersion: appVersion,
          deviceInfo: deviceInfo,
        );
      } catch (_) {
        // Email failed — feedback is already saved to Firestore, so still
        // consider this a success from the user's point of view.
      }

      setState(() { _sent = true; _sending = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _sending = false;
      });
    }
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
                    'help_feedback'.tr(),
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
              child: _sent ? _buildSuccess() : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _kWin.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: _kWin, size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'feedback_sent'.tr(),
              style: GoogleFonts.fraunces(
                fontSize: 24, fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic, color: _kInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isBug
                  ? 'Your bug report has been sent. We\'ll investigate shortly.'
                  : 'Thanks for your feedback! We read every message.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: _kInkMute, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: _kAmber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'done'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1205),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── Type selector ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              _TypeTab(
                label: 'general_feedback'.tr(),
                icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                selected: !_isBug,
                onTap: () => setState(() => _isBug = false),
              ),
              _TypeTab(
                label: 'report_bug_label'.tr(),
                icon: PhosphorIcons.bug(PhosphorIconsStyle.regular),
                selected: _isBug,
                onTap: () => setState(() => _isBug = true),
                accent: _kLoss,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Description ────────────────────────────────────────────────
        Text(
          _isBug ? 'Describe the bug' : 'your_feedback'.tr(),
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: _kInkMute, letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: TextField(
            controller: _ctrl,
            maxLines: 8,
            minLines: 6,
            style: GoogleFonts.inter(fontSize: 14, color: _kInk, height: 1.5),
            decoration: InputDecoration(
              hintText: _isBug
                  ? 'Steps to reproduce, what happened, what you expected…'
                  : 'Tell us what you think, suggest a feature, or ask for help…',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _kInkMute),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: GoogleFonts.inter(fontSize: 12, color: _kLoss),
          ),
        ],

        const SizedBox(height: 8),
        Text(
          'Your response will be sent to our team along with your app version and device info.',
          style: GoogleFonts.inter(fontSize: 11, color: _kInkMute, height: 1.4),
        ),

        const SizedBox(height: 24),

        // ── Submit ────────────────────────────────────────────────────
        GestureDetector(
          onTap: _sending ? null : _submit,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: _kAmber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _sending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1A1205),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                          color: const Color(0xFF1A1205), size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'send_feedback'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1205),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  const _TypeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? _kAmber;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? color : _kInkMute),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? color : _kInkMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

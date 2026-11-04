import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = AppColors.background;
const _kCard      = AppColors.card;
const _kAmber     = AppColors.amber;
const _kAmberDeep = AppColors.amberDeep;
const _kInk       = AppColors.ink;
const _kInkDim    = AppColors.inkDim;
const _kInkMute   = AppColors.inkMute;
const _kBorder    = AppColors.border;
const _kLoss      = AppColors.loss;
const _kLossSoft  = AppColors.lossSoft;
const _kWin       = AppColors.win;
const _kDark      = Color(0xFF1A1205);

/// Shown right after e-mail registration (and from Account → Email when the
/// address is still unverified).
///
/// Verification does not block playing: "Skip for now" continues, and the
/// screen notices a click on the link by itself. It used to be a dead end
/// whose only exit, the back arrow, silently signed the new user out — and
/// trying to register again then failed with "email already in use".
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  static const _cooldown = 60;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _pollTimer;
  bool _checking = false;
  bool _done = false;
  String? _errorMessage;
  String? _infoMessage;

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authServiceProvider);
    final sentAt = auth.lastVerificationEmailSentAt;
    final sinceSent =
        sentAt == null ? null : DateTime.now().difference(sentAt).inSeconds;
    if (sinceSent != null && sinceSent < _cooldown) {
      // Registration already sent it a moment ago — don't send a second one
      // (Firebase answers rapid resends with too-many-requests).
      _startCooldown(_cooldown - sinceSent);
    } else {
      _send(initial: true);
    }
    // Pick up a click on the link without making the user tap anything.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _send({bool initial = false}) async {
    final ok = await ref.read(authServiceProvider).sendVerificationEmail();
    if (!mounted) return;
    setState(() {
      if (ok) {
        _errorMessage = null;
        _infoMessage = initial ? null : 'verification_resent'.tr();
      } else if (!initial) {
        _errorMessage = 'verification_send_failed'.tr();
      }
    });
    if (ok) _startCooldown(_cooldown);
  }

  void _startCooldown(int seconds) {
    if (!mounted) return;
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _poll() async {
    if (_checking || _done) return;
    try {
      final verified =
          await ref.read(authServiceProvider).reloadAndCheckVerified();
      if (verified) _finish(verified: true);
    } catch (_) {
      // Offline for a moment — the next tick tries again.
    }
  }

  Future<void> _checkVerification() async {
    setState(() { _checking = true; _errorMessage = null; _infoMessage = null; });
    try {
      final verified =
          await ref.read(authServiceProvider).reloadAndCheckVerified();
      if (!mounted) return;
      if (verified) {
        _finish(verified: true);
      } else {
        setState(() {
          _errorMessage = 'verification_not_yet'.tr();
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'verification_check_failed'.tr();
          _checking = false;
        });
      }
    }
  }

  void _finish({required bool verified}) {
    if (_done || !mounted) return;
    _done = true;
    _pollTimer?.cancel();
    if (verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('verification_success'.tr())),
      );
    }
    final user = ref.read(currentUserProvider).valueOrNull;
    final hasPhoto = (user?.photoUrl ?? '').isNotEmpty;
    if (context.canPop()) {
      // Opened from Account → back where we came from.
      context.pop();
    } else {
      context.go(hasPhoto ? '/home' : '/auth/profile-photo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final resendDisabled = _cooldownSeconds > 0;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Icon ──
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_kAmber, _kAmberDeep],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _kAmber.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          PhosphorIcons.envelope(PhosphorIconsStyle.fill),
                          size: 32,
                          color: _kDark,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        'verification_title'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'verification_sent_to'.tr(),
                        style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: _kAmber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              PhosphorIcons.info(PhosphorIconsStyle.regular),
                              size: 15,
                              color: _kInkMute,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'verification_hint'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _kInkMute,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      if (_errorMessage != null || _infoMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _errorMessage != null
                                ? _kLossSoft
                                : _kWin.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (_errorMessage != null ? _kLoss : _kWin)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _errorMessage ?? _infoMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _errorMessage != null ? _kLoss : _kWin,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── CTA ──
                      Semantics(
                        button: true,
                        label: 'verification_continue'.tr(),
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: _checking ? null : _checkVerification,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: _checking
                                  ? null
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [_kAmber, _kAmberDeep],
                                    ),
                              color: _checking ? _kCard : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _checking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: _kAmber,
                                      ),
                                    )
                                  : Text(
                                      'verification_continue'.tr(),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _kDark,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Resend ──
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: resendDisabled ? null : () => _send(),
                          icon: Icon(
                            PhosphorIcons.arrowCounterClockwise(
                                PhosphorIconsStyle.regular),
                            size: 16,
                            color: resendDisabled ? _kInkMute : _kInk,
                          ),
                          label: Text(
                            resendDisabled
                                ? 'resend_timer'.tr(namedArgs: {
                                    'seconds': '$_cooldownSeconds'
                                  })
                                : 'resend'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: resendDisabled ? _kInkMute : _kInk,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _kCard,
                            side: const BorderSide(color: _kBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Center(
                        child: TextButton(
                          onPressed: () => _finish(verified: false),
                          child: Text(
                            'skip_for_now'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kInkDim,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

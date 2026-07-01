import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg      = AppColors.background;
const _kCard    = AppColors.card;
const _kSurface = AppColors.surface;
const _kAmber   = AppColors.amber;
const _kAmberDeep = AppColors.amberDeep;
const _kAmberGlow = AppColors.amberGlow;
const _kInk     = AppColors.ink;
const _kInkDim  = AppColors.inkDim;
const _kInkMute = AppColors.inkMute;
const _kBorder  = AppColors.border;
const _kLoss    = AppColors.loss;
const _kLossSoft = AppColors.lossSoft;

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _resendCooldown = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _checking = false;
  String? _errorMessage;

  String get _email =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _startCooldown();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to send email. Please try again.');
      }
    }
  }

  void _startCooldown() {
    if (!mounted) return;
    setState(() {
      _resendCooldown = true;
      _cooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _resendCooldown = false;
          t.cancel();
        }
      });
    });
  }

  Future<void> _checkVerification() async {
    setState(() { _checking = true; _errorMessage = null; });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        if (mounted) context.go('/auth/profile-photo');
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Email not verified yet. Check your inbox and spam folder.';
            _checking = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error checking verification. Please try again.';
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) context.go('/login');
                    },
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
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 1),

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
                            color: _kAmber.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        PhosphorIcons.envelope(PhosphorIconsStyle.fill),
                        size: 32,
                        color: const Color(0xFF1A1205),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Heading ──
                    Text(
                      'Check your\nemail.',
                      style: GoogleFonts.fraunces(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: _kInk,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'We sent a verification link to:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _kInkMute,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _kAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Error ──
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kLossSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _kLoss.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _kLoss,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── CTA ──
                    GestureDetector(
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
                          boxShadow: _checking
                              ? null
                              : [
                                  BoxShadow(
                                    color: _kAmber.withOpacity(0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _checking
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: _kAmber,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Checking...',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _kInkDim,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  "I've verified · Continue",
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A1205),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Resend ──
                    GestureDetector(
                      onTap: _resendCooldown ? null : _sendVerificationEmail,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.arrowCounterClockwise(
                                    PhosphorIconsStyle.regular),
                                color: _resendCooldown ? _kInkMute : _kInk,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _resendCooldown
                                    ? 'resend_timer'.tr(namedArgs: {'seconds': '$_cooldownSeconds'})
                                    : 'resend'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _resendCooldown ? _kInkMute : _kInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

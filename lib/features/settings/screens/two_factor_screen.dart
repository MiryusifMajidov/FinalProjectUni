import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
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
const _kLoss      = Color(0xFFF07079);
const _kWin       = Color(0xFF5AB67A);

enum _TfaStep { intro, verify, done }

class TwoFactorScreen extends ConsumerStatefulWidget {
  /// [enabling] = true → user wants to TURN ON 2FA.
  /// [enabling] = false → user wants to TURN OFF 2FA.
  final bool enabling;
  const TwoFactorScreen({super.key, required this.enabling});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  _TfaStep _step = _TfaStep.intro;
  bool _loading = false;
  String? _error;
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  String get _code => _ctrls.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(otpServiceProvider).send2faOtp(user.email);
      setState(() { _step = _TfaStep.verify; _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_code.length != 6) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final valid = await ref.read(otpServiceProvider).verifyOtp(user.email, _code);
      if (!valid) {
        setState(() { _error = 'Incorrect or expired code'; _loading = false; });
        return;
      }
      await ref.read(firestoreServiceProvider).setTwoFactorEnabled(
        user.uid, widget.enabling,
      );
      ref.invalidate(currentUserProvider);
      setState(() { _step = _TfaStep.done; _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
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
                    widget.enabling
                        ? 'enable_2fa'.tr()
                        : 'disable_2fa'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_step) {
                _TfaStep.intro  => _buildIntro(),
                _TfaStep.verify => _buildVerify(),
                _TfaStep.done   => _buildDone(),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Intro ──────────────────────────────────────────────────────────
  Widget _buildIntro() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kAmberGlow,
              shape: BoxShape.circle,
              border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
            ),
            child: Icon(
              PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
              color: _kAmber, size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.enabling
                ? 'tfa_security_add'.tr()
                : 'tfa_security_remove'.tr(),
            style: GoogleFonts.fraunces(
              fontSize: 22, fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic, color: _kInk,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.enabling
                ? 'tfa_desc_enable'.tr()
                : 'tfa_desc_disable'.tr(),
            style: GoogleFonts.inter(fontSize: 14, color: _kInkMute, height: 1.6),
            textAlign: TextAlign.center,
          ),
          if (user != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.envelope(PhosphorIconsStyle.regular),
                      color: _kAmber, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    user.email,
                    style: GoogleFonts.inter(fontSize: 13, color: _kInkDim),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.inter(fontSize: 12, color: _kLoss)),
          ],
          const Spacer(),
          GestureDetector(
            onTap: _loading ? null : _sendCode,
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                color: widget.enabling ? _kAmber : _kLoss.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: widget.enabling
                    ? null
                    : Border.all(color: _kLoss.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: _loading
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.enabling
                              ? const Color(0xFF1A1205)
                              : _kLoss,
                        ),
                      )
                    : Text(
                        'send_code'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: widget.enabling
                              ? const Color(0xFF1A1205)
                              : _kLoss,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Enter OTP ──────────────────────────────────────────────────────
  Widget _buildVerify() {
    final email = ref.watch(currentUserProvider).valueOrNull?.email ?? '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(PhosphorIcons.envelope(PhosphorIconsStyle.fill),
              color: _kAmber, size: 48),
          const SizedBox(height: 16),
          Text(
            'enter_verification_code'.tr(),
            style: GoogleFonts.fraunces(
              fontSize: 22, fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic, color: _kInk,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'code_sent_to'.tr(namedArgs: {'email': email}),
            style: GoogleFonts.inter(fontSize: 13, color: _kInkMute, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // 6-box OTP input
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Container(
                width: 44, height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: TextField(
                  controller: _ctrls[i],
                  focusNode: _foci[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20, fontWeight: FontWeight.bold, color: _kAmber,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) {
                      _foci[i + 1].requestFocus();
                    }
                    if (v.isEmpty && i > 0) {
                      _foci[i - 1].requestFocus();
                    }
                    setState(() {});
                  },
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.inter(fontSize: 12, color: _kLoss)),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _sendCode,
            child: Text(
              'resend'.tr(),
              style: GoogleFonts.inter(fontSize: 13, color: _kAmber),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: (_loading || _code.length != 6) ? null : _verifyCode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                color: _code.length == 6 ? _kAmber : _kSurface,
                borderRadius: BorderRadius.circular(14),
                border: _code.length != 6
                    ? Border.all(color: _kBorder)
                    : null,
              ),
              child: Center(
                child: _loading
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _code.length == 6
                              ? const Color(0xFF1A1205)
                              : _kInkMute,
                        ),
                      )
                    : Text(
                        'verify'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: _code.length == 6
                              ? const Color(0xFF1A1205)
                              : _kInkMute,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Done ───────────────────────────────────────────────────────────
  Widget _buildDone() {
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
              widget.enabling ? 'tfa_enabled'.tr() : 'tfa_disabled'.tr(),
              style: GoogleFonts.fraunces(
                fontSize: 24, fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic, color: _kInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.enabling
                  ? 'tfa_done_enable'.tr()
                  : 'tfa_done_disable'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: _kInkMute, height: 1.5),
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
                    fontSize: 14, fontWeight: FontWeight.w600,
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
}

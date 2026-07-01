import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/services/otp_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0A0A0B);
const _kSurface = Color(0xFF131316);
const _kCard    = Color(0xFF1A1A1E);
const _kAmber   = Color(0xFFE8B960);
const _kInk     = Color(0xFFF5F3EF);
const _kInkDim  = Color(0xFFB0A898);
const _kInkMute = Color(0xFF706860);
const _kBorder  = Color(0xFF2A2520);
const _kLoss    = Color(0xFFF07079);

class TwoFactorVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const TwoFactorVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<TwoFactorVerifyScreen> createState() =>
      _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState
    extends ConsumerState<TwoFactorVerifyScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;
  String? _error;

  String get _code => _ctrls.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final valid = await ref
          .read(otpServiceProvider)
          .verifyOtp(widget.email, _code);
      if (!mounted) return;
      if (valid) {
        context.pop(true);   // return true → login continues
      } else {
        setState(() {
          _error = 'Incorrect or expired code';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _error = null; });
    try {
      await ref.read(otpServiceProvider).sendOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New code sent!')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to send code — check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),

              Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                  color: _kAmber, size: 52),
              const SizedBox(height: 18),

              Text(
                'Two-Factor Authentication',
                style: GoogleFonts.fraunces(
                  fontSize: 22, fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic, color: _kInk,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '${'enter_verification_code'.tr()}\n${'code_sent_to'.tr(namedArgs: {'email': widget.email})}',
                style: GoogleFonts.inter(
                    fontSize: 13, color: _kInkMute, height: 1.5),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ── OTP boxes ────────────────────────────────────────────────
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
                        fontSize: 20, fontWeight: FontWeight.bold,
                        color: _kAmber,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) _foci[i + 1].requestFocus();
                        if (v.isEmpty && i > 0)    _foci[i - 1].requestFocus();
                        setState(() {});
                      },
                    ),
                  );
                }),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: GoogleFonts.inter(fontSize: 12, color: _kLoss),
                    textAlign: TextAlign.center),
              ],

              const SizedBox(height: 16),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: _resending
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kAmber),
                      )
                    : Text('resend'.tr(),
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _kAmber)),
              ),

              const Spacer(),

              // ── Verify button ─────────────────────────────────────────────
              GestureDetector(
                onTap: (_loading || _code.length != 6) ? null : _verify,
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

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.pop(false),
                child: Text(
                  'Cancel login',
                  style: GoogleFonts.inter(fontSize: 13, color: _kInkMute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

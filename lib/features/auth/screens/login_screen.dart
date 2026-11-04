import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/legal/legal_consent.dart';
import '../../../core/utils/email_validator.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/widgets/guest_notice.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/google_sign_in_button.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/text_case.dart';
import '../../../core/widgets/app_logo.dart';
// ── Design tokens ─────────────────────────────────────────────────────────────

const _kBg        = AppColors.background;
const _kField     = AppColors.surface;
const _kAmber     = AppColors.amber;
const _kAmberGlow = AppColors.amberGlow;
const _kInk       = AppColors.ink;
const _kInkDim    = AppColors.inkDim;
const _kInkMute   = AppColors.inkMute;
const _kBorderStr = AppColors.borderStrong;
const _kLoss      = AppColors.loss;
const _kDark      = Color(0xFF1A1205);

/// The first screen a signed-out person sees.
///
/// It used to open on "Welcome back." with an e-mail form — the wrong greeting
/// for someone who installed the app a minute ago, and a wall of fields before
/// they could play a single move. Half the people who installed never got past
/// it. It now leads with "Play now as guest"; returning players open the
/// e-mail form with one tap, or use Google / Apple.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading        = false;
  bool _guestLoading   = false;
  bool _showEmailForm  = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _busy => _loading || _guestLoading;

  // ── Guest ──────────────────────────────────────────────────────────────────

  Future<void> _playAsGuest() async {
    if (_busy) return;
    setState(() { _guestLoading = true; _error = null; });
    final flow = ref.read(authFlowInProgressProvider.notifier)..state = true;
    try {
      // The device session is recorded by ChessApp's auth listener.
      await ref.read(authServiceProvider).signInAsGuest();
      if (!mounted) return;
      // Home shows the one-time "this account lives only on this phone"
      // dialog — said up front, while it can still change their mind.
      ref.read(pendingGuestWelcomeProvider.notifier).state = true;
      context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = _guestError(e));
    } finally {
      if (mounted) setState(() => _guestLoading = false);
      flow.state = false;
    }
  }

  String _guestError(Object e) {
    final code = e is FirebaseAuthException ? e.code : e.toString();
    if (code.contains('operation-not-allowed') ||
        code.contains('admin-restricted-operation')) {
      // Anonymous sign-in is switched off in the Firebase console.
      return 'guest_disabled'.tr();
    }
    if (code.contains('network-request-failed')) return 'err_no_internet'.tr();
    return 'guest_failed'.tr();
  }

  // ── E-mail sign-in ─────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    // Signing in makes the router re-run its redirect. Without this flag it
    // sent the screen to /home at once and the 2FA check below never ran.
    final flow = ref.read(authFlowInProgressProvider.notifier)..state = true;
    try {
      final user = await ref.read(authServiceProvider).signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      // ── 2FA check ──────────────────────────────────────────────────────
      if (user?.twoFactorEnabled == true) {
        // Send OTP — best-effort: SMTP can be blocked by mobile carriers,
        // so we proceed to the verify screen regardless. The user can tap
        // "Resend code" once they have a connection.
        bool emailSent = false;
        try {
          await ref.read(otpServiceProvider).sendOtp(user!.email);
          emailSent = true;
        } catch (_) {}
        if (!mounted) return;
        if (!emailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('verification_email_delayed'.tr()),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        final verified = await context.push<bool>('/login/2fa-verify',
            extra: user!.email);
        if (verified != true) {
          // User cancelled or failed — sign out
          await ref.read(authServiceProvider).signOut();
          return;
        }
      }

      // ── Save session ───────────────────────────────────────────────────
      final uid = user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final sessionId =
            await ref.read(authServiceProvider).saveLoginSession(uid);
        if (sessionId != null && mounted) {
          ref.read(currentSessionIdProvider.notifier).state = sessionId;
        }
      }

      if (!mounted) return;
      // No profile document (an account from the old, non-atomic sign-up):
      // home shows "complete your profile" for exactly this case.
      final hasPhoto = (user?.photoUrl ?? '').isNotEmpty;
      context.go(user == null || hasPhoto ? '/home' : '/auth/profile-photo');
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
      flow.state = false;
    }
  }

  String _friendlyError(Object e) {
    final raw = e is FirebaseAuthException ? e.code : e.toString();
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential') ||
        raw.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'err_invalid_credentials'.tr();
    }
    if (raw.contains('invalid-email')) return 'err_invalid_email'.tr();
    if (raw.contains('user-disabled')) return 'err_user_disabled'.tr();
    if (raw.contains('too-many-requests')) return 'err_too_many_requests'.tr();
    if (raw.contains('network-request-failed')) return 'err_no_internet'.tr();
    return 'err_generic'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;

    return Scaffold(
      backgroundColor: _kBg,
      body: isTablet
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  // ── Tablet: split screen ───────────────────────────────────────────────────

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        // Left decorative panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F0F0A), Color(0xFF1A150A)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  left: -60,
                  child: _glow(300, 0.15),
                ),
                Positioned(
                  bottom: -80,
                  right: -40,
                  child: _glow(250, 0.08),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _logoMark(72),
                        const SizedBox(height: 32),
                        Text(
                          'CheckMate',
                          style: GoogleFonts.inter(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                            letterSpacing: -1.5,
                            height: 1.0,
                          ),
                        ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                        const SizedBox(height: 12),
                        Text(
                          'welcome_tagline'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: _kInkDim,
                            height: 1.5,
                          ),
                        ).animate(delay: 200.ms).fadeIn(),
                        const SizedBox(height: 40),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            (PhosphorIcons.gameController(PhosphorIconsStyle.regular), 'feature_online_offline'.tr()),
                            (PhosphorIcons.trophy(PhosphorIconsStyle.regular), 'feature_hourly_arenas'.tr()),
                            (PhosphorIcons.robot(PhosphorIconsStyle.regular), 'feature_bot'.tr()),
                            (PhosphorIcons.translate(PhosphorIconsStyle.regular), 'feature_languages'.tr()),
                          ].map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Icon(item.$1, size: 18, color: _kAmber),
                                const SizedBox(width: 12),
                                Text(
                                  item.$2,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: _kInkDim,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ).animate(delay: 300.ms).fadeIn(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0x1AFFFFFF)),
        Expanded(
          flex: 4,
          child: Container(
            color: _kBg,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                  child: _buildForm(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phone: centered narrow column ──────────────────────────────────────────

  Widget _buildPhoneLayout(BuildContext context) {
    return Stack(
      children: [
        // Amber glow behind the logo. Outside the SafeArea so the gradient is
        // not cut off in a hard line under the status bar.
        Positioned(
          top: -140,
          right: -110,
          child: IgnorePointer(child: _glow(320, 0.12)),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _buildForm(context, showLogo: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _glow(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _kAmber.withValues(alpha: alpha),
              _kAmber.withValues(alpha: 0.0),
            ],
          ),
        ),
      );

  Widget _logoMark(double size) => AppLogo(size: size).animate().scale(
        begin: const Offset(0.8, 0.8),
        duration: 400.ms,
        curve: Curves.easeOutBack,
      );

  // ── Shared column ──────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context, {bool showLogo = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),

        if (showLogo) ...[
          _logoMark(56),
          const SizedBox(height: 24),
          Text(
            'CheckMate',
            style: GoogleFonts.inter(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: _kInk,
              letterSpacing: -1.2,
              height: 1.0,
            ),
          ).animate(delay: 80.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 10),
          Text(
            'welcome_tagline'.tr(),
            style: GoogleFonts.inter(fontSize: 14, color: _kInkDim, height: 1.5),
          ).animate(delay: 140.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 32),
        ] else ...[
          Text(
            'login_headline'.tr(),
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: _kInk,
              letterSpacing: -1.0,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 28),
        ],

        // ── Primary: play as guest ───────────────────────────────────────
        _PrimaryButton(
          label: 'play_as_guest'.tr(),
          icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
          loading: _guestLoading,
          onTap: _busy ? null : _playAsGuest,
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(PhosphorIcons.info(PhosphorIconsStyle.regular),
                  size: 14, color: _kInkMute),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'guest_caption'.tr(),
                style: GoogleFonts.inter(
                    fontSize: 12, color: _kInkMute, height: 1.45),
              ),
            ),
          ],
        ).animate(delay: 240.ms).fadeIn(),

        const SizedBox(height: 24),

        // ── OR divider ────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: Container(height: 1, color: _kBorderStr)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or_sign_in'.tr().toUpperCaseFor(context),
                style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11, color: _kInkMute, letterSpacing: 0.6,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: _kBorderStr)),
          ],
        ).animate(delay: 280.ms).fadeIn(),

        const SizedBox(height: 16),

        // Apple platforms only — hidden everywhere else.
        if (appleSignInAvailable) ...[
          AppleSignInButton(
            onSuccess: () => context.go('/home'),
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 12),
        ],

        GoogleSignInButton(
          onSuccess: () => context.go('/home'),
        ).animate(delay: 320.ms).fadeIn(),

        const SizedBox(height: 12),

        // ── E-mail: collapsed until asked for ─────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _showEmailForm
              ? _buildEmailForm()
              : _OutlineButton(
                  label: 'sign_in_with_email'.tr(),
                  icon: PhosphorIcons.envelopeSimple(PhosphorIconsStyle.regular),
                  onTap: _busy
                      ? null
                      : () => setState(() => _showEmailForm = true),
                ).animate(delay: 340.ms).fadeIn(),
        ),

        // Guest errors show here; e-mail errors show inside the form.
        if (_error != null && !_showEmailForm) ...[
          const SizedBox(height: 14),
          _ErrorBanner(_error!),
        ],

        const SizedBox(height: 24),

        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'new_here'.tr(),
                style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _busy ? null : () => context.push('/register'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'create_account'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _kAmber,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: 380.ms).fadeIn(),

        const SizedBox(height: 16),

        // Guideline 1.2: the terms have to be in front of the user before
        // they sign in, whichever method they use — guest included.
        const LegalConsentNotice().animate(delay: 400.ms).fadeIn(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _DesignField(
            label: 'email'.tr().toUpperCaseFor(context),
            hint: 'your@email.com',
            controller: _emailCtrl,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'err_email_required'.tr();
              if (!isValidEmail(value)) return 'err_invalid_email'.tr();
              return null;
            },
          ),
          const SizedBox(height: 16),
          _DesignField(
            label: 'password'.tr().toUpperCaseFor(context),
            hint: '••••••••',
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _login(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'err_password_required'.tr();
              if (v.length < 6) return 'err_password_short'.tr();
              return null;
            },
            suffix: IconButton(
              tooltip: _obscurePassword
                  ? 'show_password'.tr()
                  : 'hide_password'.tr(),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? PhosphorIcons.eye(PhosphorIconsStyle.regular)
                    : PhosphorIcons.eyeSlash(PhosphorIconsStyle.regular),
                size: 18,
                color: _kInkMute,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                minimumSize: const Size(0, 40),
              ),
              child: Text(
                'forgot_password'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kAmber,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            _ErrorBanner(_error!),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),
          _PrimaryButton(
            label: 'sign_in'.tr(),
            loading: _loading,
            onTap: _busy ? null : _login,
          ),
        ],
      ),
    );
  }

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(
        authService: ref.read(authServiceProvider),
        initialEmail: _emailCtrl.text.trim(),
      ),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 54,
          decoration: BoxDecoration(
            color: enabled || loading ? _kAmber : _kAmber.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: _kAmberGlow, blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kDark),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: _kDark),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _kDark,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _OutlineButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _kBorderStr),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: _kInk),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kLoss.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kLoss.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kLoss, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: _kLoss),
            ),
          ),
        ],
      ),
    ).animate().shake();
  }
}

// ── Design field ──────────────────────────────────────────────────────────────

class _DesignField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  const _DesignField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.suffix,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kInkMute,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        // The validator's message renders below the box (not inside it), so
        // the rounded border never gets squeezed by an error line.
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: GoogleFonts.inter(fontSize: 15, color: _kInk),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 15, color: _kInkMute),
            filled: true,
            fillColor: _kField,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorderStr, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kAmber, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kLoss, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kLoss, width: 1.5),
            ),
            errorStyle: GoogleFonts.inter(fontSize: 12, color: _kLoss),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ── Forgot Password Sheet ─────────────────────────────────────────────────────

/// One step: Firebase e-mails a reset link and hosts the "new password" page.
///
/// The old three-step sheet could never work: it first asked the `sendOtp`
/// Cloud Function for a code, but that function rejects callers who are not
/// signed in — and someone resetting a forgotten password never is. Every
/// attempt ended at "Failed to send code". It then asked for the new password
/// anyway, only to throw it away and send this same reset link.
class _ForgotPasswordSheet extends StatefulWidget {
  final AuthService authService;
  final String initialEmail;
  const _ForgotPasswordSheet({
    required this.authService,
    required this.initialEmail,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _error = 'err_invalid_email'.tr());
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.authService.sendPasswordReset(email);
      if (mounted) setState(() { _sent = true; _loading = false; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (e.code) {
          // With e-mail enumeration protection on (the Firebase default) an
          // unknown address does not error; older projects still report it.
          'user-not-found' => 'reset_no_account'.tr(),
          'invalid-email' => 'err_invalid_email'.tr(),
          'too-many-requests' => 'err_too_many_requests'.tr(),
          'network-request-failed' => 'err_no_internet'.tr(),
          _ => 'reset_link_failed'.tr(),
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() { _loading = false; _error = 'reset_link_failed'.tr(); });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131316),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _sent ? _buildSent() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const SizedBox(height: 20),
        Text(
          'reset_password'.tr(),
          style: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'reset_link_subtitle'.tr(),
          style: GoogleFonts.inter(fontSize: 13, color: _kInkDim, height: 1.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofocus: widget.initialEmail.isEmpty,
          autocorrect: false,
          onSubmitted: (_) => _send(),
          style: GoogleFonts.inter(fontSize: 15, color: _kInk),
          decoration: InputDecoration(
            hintText: 'your@email.com',
            hintStyle: GoogleFonts.inter(fontSize: 15, color: _kInkMute),
            filled: true,
            fillColor: const Color(0xFF1A1A1E),
            prefixIcon: Icon(
              PhosphorIcons.envelopeSimple(PhosphorIconsStyle.regular),
              size: 18, color: _kInkMute,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorderStr, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kAmber, width: 1.5),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(_error!),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'send_reset_link'.tr(),
          loading: _loading,
          onTap: _loading ? null : _send,
        ),
      ],
    );
  }

  Widget _buildSent() {
    return Column(
      key: const ValueKey('sent'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 24),
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: _kAmberGlow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(PhosphorIcons.envelopeOpen(PhosphorIconsStyle.fill),
              color: _kAmber, size: 26),
        ),
        const SizedBox(height: 16),
        Text(
          'reset_link_sent_title'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'reset_link_sent'.tr(namedArgs: {'email': _emailCtrl.text.trim()}),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: _kInkDim, height: 1.5),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'done'.tr(),
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: _kInkMute,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

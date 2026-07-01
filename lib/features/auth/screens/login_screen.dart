import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/otp_service.dart';
import '../widgets/google_sign_in_button.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kBg        = Color(0xFF0A0A0B);
const _kAmber     = Color(0xFFE8B960);
const _kAmberDeep = Color(0xFFB88A3A);
const _kAmberGlow = Color(0x24E8B960);
const _kAmberSoft = Color(0xFFFFD98B);
const _kInk       = Color(0xFFF5F3EF);
const _kInkDim    = Color(0xFFA8A39A);
const _kInkMute   = Color(0xFF706B62);
const _kBorder    = Color(0x0FFFFFFF);
const _kBorderStr = Color(0x1AFFFFFF);
const _kLoss      = Color(0xFFF07079);
const _kDark      = Color(0xFF1A1205);

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
  String? _error;
  bool _emailFocused    = false;
  bool _passwordFocused = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() =>
        setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() =>
        setState(() => _passwordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
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
            const SnackBar(
              content: Text(
                  'Verification email may be delayed — tap "Resend code" if it doesn\'t arrive.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        final verified = await context.push<bool>('/login/2fa-verify',
            extra: user!.email);
        if (verified != true) {
          // User cancelled or failed — sign out
          await ref.read(authServiceProvider).signOut();
          if (mounted) setState(() => _loading = false);
          return;
        }
      }

      // ── Save session ───────────────────────────────────────────────────
      if (user != null) {
        final sessionId = await ref
            .read(authServiceProvider)
            .saveLoginSession(user.uid);
        if (sessionId != null && mounted) {
          ref.read(currentSessionIdProvider.notifier).state = sessionId;
        }
      }

      if (mounted) {
        // Show photo prompt for users who haven't set a profile photo yet.
        // Use a short timeout so we don't block indefinitely on a slow network.
        final appUser = await ref
            .read(currentUserProvider.future)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (mounted) {
          final hasPhoto = appUser?.photoUrl != null &&
            appUser!.photoUrl!.isNotEmpty;
        context.go(hasPhoto ? '/home' : '/auth/profile-photo');
        }
      }
    } catch (e) {
      setState(() { _error = _friendlyError(e.toString()); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Invalid email or password.';
    }
    if (raw.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    if (raw.contains('smtp') || raw.contains('SMTP') ||
        raw.contains('SocketException') || raw.contains('SmtpClientCommunicationException')) {
      return 'Failed to send verification code. Please check your connection.';
    }
    return 'Something went wrong. Please try again.';
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
                // Glow circles
                Positioned(
                  top: -60,
                  left: -60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kAmber.withValues(alpha: 0.15),
                          _kAmber.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  right: -40,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kAmber.withValues(alpha: 0.08),
                          _kAmber.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const RadialGradient(
                              colors: [_kAmberSoft, _kAmberDeep],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kAmber.withValues(alpha: 0.3),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '♞',
                              style: GoogleFonts.fraunces(
                                fontSize: 44,
                                color: _kDark,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ).animate().scale(
                          begin: const Offset(0.7, 0.7),
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'CheckMate',
                          style: GoogleFonts.fraunces(
                            fontSize: 48,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: _kInk,
                            letterSpacing: -1.5,
                            height: 1.0,
                          ),
                        ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                        const SizedBox(height: 12),
                        Text(
                          'Play. Compete. Dominate.',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: _kInkDim,
                            letterSpacing: 0.2,
                          ),
                        ).animate(delay: 200.ms).fadeIn(),
                        const SizedBox(height: 48),
                        // Feature chips
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ('♟', 'Online & Offline Play'),
                            ('🏆', 'Arena Tournaments'),
                            ('🤖', 'Stockfish Bot'),
                            ('🌍', '10 Languages'),
                          ].map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Text(item.$1, style: const TextStyle(fontSize: 18)),
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
        // Vertical divider
        Container(width: 1, color: const Color(0x1AFFFFFF)),
        // Right: login form
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

  // ── Phone: centered narrow form ────────────────────────────────────────────

  Widget _buildPhoneLayout(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            children: [
              // Amber glow decoration (top right)
              Positioned(
                top: -120,
                right: -100,
                child: IgnorePointer(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kAmber.withValues(alpha: 0.12),
                          _kAmber.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _buildForm(context, showLogo: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared form ────────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context, {bool showLogo = false}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          if (showLogo) ...[
          // App mark — 56x56 squircle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const RadialGradient(
                colors: [_kAmberSoft, _kAmberDeep],
              ),
              boxShadow: const [
                BoxShadow(
                  color: _kAmberGlow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '♞',
                style: GoogleFonts.fraunces(
                  fontSize: 35,
                  color: _kDark,
                  height: 1.0,
                ),
              ),
            ),
          ).animate().scale(
                begin: const Offset(0.7, 0.7),
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 28),
          ],

          // Headline
          Text(
            'login_headline'.tr(),
            style: GoogleFonts.fraunces(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: _kInk,
              letterSpacing: -1.0,
              height: 1.05,
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),

          const SizedBox(height: 10),

          Text(
            'login_board_subtitle'.tr(),
            style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
          ).animate(delay: 150.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 36),

          // EMAIL field
          _DesignField(
            label: 'EMAIL',
            hint: 'your@email.com',
            controller: _emailCtrl,
            focusNode: _emailFocus,
            focused: _emailFocused,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),

          const SizedBox(height: 16),

          // PASSWORD field
          _DesignField(
            label: 'PASSWORD',
            hint: '••••••••',
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            focused: _passwordFocused,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password is too short';
              return null;
            },
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_outlined,
                size: 18,
                color: _kInkMute,
              ),
            ),
          ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.15),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _showForgotPassword,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'forgot_password'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kAmber,
                  ),
                ),
              ),
            ),
          ).animate(delay: 300.ms).fadeIn(),

          // Error banner
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
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
                      _error!,
                      style: GoogleFonts.inter(fontSize: 13, color: _kLoss),
                    ),
                  ),
                ],
              ),
            ).animate().shake(),
          ],

          const SizedBox(height: 24),

          // Sign In button
          GestureDetector(
            onTap: _loading ? null : _login,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: _loading ? _kAmber.withValues(alpha: 0.6) : _kAmber,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: _kAmberGlow, blurRadius: 20, offset: Offset(0, 6)),
                ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kDark),
                      )
                    : Text(
                        'sign_in'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700, color: _kDark,
                        ),
                      ),
              ),
            ),
          ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.2),

          const SizedBox(height: 20),

          // OR divider
          Row(
            children: [
              Expanded(child: Container(height: 1, color: _kBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or_divider'.tr(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: _kInkMute, letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: _kBorder)),
            ],
          ).animate(delay: 370.ms).fadeIn(),

          const SizedBox(height: 16),

          GoogleSignInButton(
            onSuccess: () => context.go('/home'),
          ).animate(delay: 380.ms).fadeIn(),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'new_here'.tr(),
                style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
              ),
              GestureDetector(
                onTap: () => context.push('/register'),
                child: Text(
                  'create_account'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _kAmber,
                  ),
                ),
              ),
            ],
          ).animate(delay: 400.ms).fadeIn(),

          const SizedBox(height: 24),
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
        otpService: ref.read(otpServiceProvider),
        authService: ref.read(authServiceProvider),
      ),
    );
  }
}

// ── Design field ──────────────────────────────────────────────────────────────

class _DesignField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;

  const _DesignField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.focused,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _kInkMute,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF131316),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? _kAmber : _kBorderStr,
              width: 1.5,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: _kAmberGlow,
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: _kInk,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: _kInkMute,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: InputBorder.none,
              suffixIcon: suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: suffix,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Forgot Password Sheet ─────────────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  final OtpService otpService;
  final AuthService authService;
  const _ForgotPasswordSheet({
    required this.otpService,
    required this.authService,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  // 1 = email input, 2 = otp verify, 3 = new password
  int _step = 1;

  final _emailCtrl       = TextEditingController();
  final _otpCtrl         = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _loading   = false;
  String? _error;

  int _countdown = 600;
  int _resendIn  = 60;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _countdown = 600;
    _resendIn  = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) _countdown--;
        if (_resendIn > 0) _resendIn--;
      });
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.otpService.sendOtp(email);
      if (!mounted) return;
      setState(() { _step = 2; _loading = false; });
      _startTimer();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to send code. Try again.'; });
    }
  }

  Future<void> _resendOtp() async {
    setState(() { _resendIn = 60; _countdown = 600; _error = null; });
    try {
      await widget.otpService.sendOtp(_emailCtrl.text.trim());
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to resend. Try again.');
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await widget.otpService.verifyOtp(_emailCtrl.text.trim(), code);
      if (!mounted) return;
      if (ok) {
        _timer?.cancel();
        setState(() { _step = 3; _loading = false; });
      } else {
        setState(() { _loading = false; _error = 'Incorrect or expired code.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Verification failed.'; });
    }
  }

  Future<void> _resetPassword() async {
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (newPass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.authService.sendPasswordReset(_emailCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent to your email. Click it to set your new password.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to reset password. Try again.'; });
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
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _step == 1
            ? _buildEmailStep()
            : _step == 2
                ? _buildOtpStep()
                : _buildNewPasswordStep(),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const SizedBox(height: 20),
        Text('reset_password'.tr(), style: AppTextStyles.titleLarge),
        const SizedBox(height: 6),
        Text(
          'enter_email_send_code'.tr(),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'email'.tr(),
          hint: 'your@email.com',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendOtp(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 24),
        AppButton(
          label: 'send_code'.tr(),
          onTap: _loading ? null : _sendOtp,
          isLoading: _loading,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const SizedBox(height: 20),
        Text('enter_verification_code'.tr(), style: AppTextStyles.titleLarge),
        const SizedBox(height: 6),
        Text(
          'code_sent_to'.tr(namedArgs: {'email': _emailCtrl.text.trim()}),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofocus: true,
          style: AppTextStyles.displayMedium.copyWith(letterSpacing: 12),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: AppTextStyles.displayMedium.copyWith(
              letterSpacing: 12,
              color: AppColors.textHint,
            ),
          ),
          onChanged: (v) { if (v.length == 6) _verifyOtp(); },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _countdown > 0 ? 'expires_in'.tr(namedArgs: {'time': _fmt(_countdown)}) : 'code_expired'.tr(),
              style: AppTextStyles.labelSmall.copyWith(
                color: _countdown > 0 ? AppColors.textHint : AppColors.error,
              ),
            ),
            TextButton(
              onPressed: _resendIn == 0 ? _resendOtp : null,
              child: Text(
                _resendIn > 0 ? 'resend_timer'.tr(namedArgs: {'seconds': '$_resendIn'}) : 'resend'.tr(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: _resendIn == 0 ? AppColors.primary : AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'verify'.tr(),
          onTap: (_loading || _countdown == 0) ? null : _verifyOtp,
          isLoading: _loading,
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      key: const ValueKey(3),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const SizedBox(height: 20),
        Text('set_new_password'.tr(), style: AppTextStyles.titleLarge),
        const SizedBox(height: 6),
        Text(
          'choose_new_password_hint'.tr(),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'new_password'.tr(),
          hint: '••••••••',
          controller: _newPassCtrl,
          obscureText: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'confirm_password'.tr(),
          hint: '••••••••',
          controller: _confirmPassCtrl,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _resetPassword(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 24),
        AppButton(
          label: 'reset_password'.tr(),
          onTap: _loading ? null : _resetPassword,
          isLoading: _loading,
        ),
      ],
    );
  }

  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textHint,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

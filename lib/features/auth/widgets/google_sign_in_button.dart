import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_button.dart';

const _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class GoogleSignInButton extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const GoogleSignInButton({super.key, required this.onSuccess});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;

      // ── 2FA check (existing users only) ───────────────────────────────
      if (!result.isNewUser && result.user?.twoFactorEnabled == true) {
        // Best-effort OTP send — SMTP may be blocked on some mobile carriers.
        bool emailSent = false;
        try {
          await ref.read(otpServiceProvider).sendOtp(result.user!.email);
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
        final verified = await context.push<bool>(
          '/login/2fa-verify',
          extra: result.user!.email,
        );
        if (!mounted) return;
        if (verified != true) {
          await ref.read(authServiceProvider).signOut();
          setState(() => _loading = false);
          return;
        }
      }

      // Save login session so it appears in Active Sessions screen.
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        final sessionId =
            await ref.read(authServiceProvider).saveLoginSession(uid);
        if (sessionId != null && mounted) {
          ref.read(currentSessionIdProvider.notifier).state = sessionId;
        }
      }

      // Whether existing or new user, navigate to home.
      // If new (no Firestore profile), home screen will show the username setup.
      if (mounted) widget.onSuccess();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('sign_in_canceled')) {
        // user dismissed — no error shown
      } else if (mounted) {
        String friendly = 'Google sign-in failed.';
        if (msg.contains('network') || msg.contains('NETWORK')) {
          friendly = 'No internet connection.';
        } else if (msg.contains('10:') || msg.contains('DEVELOPER_ERROR')) {
          friendly = 'Configuration error: SHA-1 or google-services.json not set up correctly.';
        } else if (msg.contains('sign_in_failed')) {
          friendly = 'Google sign-in failed. Make sure Google is enabled in Firebase Console.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendly),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _loading ? null : _signIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.string(
                    _googleLogoSvg,
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Username setup sheet for new Google users ─────────────────────────────────

class _UsernameSheet extends StatefulWidget {
  final dynamic firebaseUser;
  final AuthService authService;
  const _UsernameSheet({required this.firebaseUser, required this.authService});

  @override
  State<_UsernameSheet> createState() => _UsernameSheetState();
}

class _UsernameSheetState extends State<_UsernameSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _skillLevel;

  static const _skillLevels = ['Beginner', 'Casual', 'Intermediate', 'Advanced', 'Expert'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _ctrl.text.trim();
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() => _error = 'Only letters, numbers and underscores');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.authService.completeGoogleSignUp(
        firebaseUser: widget.firebaseUser,
        username: username,
        skillLevel: _skillLevel,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().contains('already taken')
              ? 'Username already taken'
              : 'Something went wrong';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('choose_username'.tr(), style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text(
            'choose_username_subtitle'.tr(),
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'username'.tr(),
            hint: 'e.g. chess_master',
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          Text(
            'Skill Level (optional)',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillLevels.map((level) {
              final selected = _skillLevel == level;
              return GestureDetector(
                onTap: () => setState(() =>
                    _skillLevel = selected ? null : level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.amber.withOpacity(0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.amber : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.amber : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Continue',
            onTap: _loading ? null : _submit,
            isLoading: _loading,
          ),
        ],
      ),
    );
  }
}

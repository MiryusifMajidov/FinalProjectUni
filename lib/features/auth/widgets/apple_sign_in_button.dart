import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_button.dart';

/// Sign in with Apple exists only on Apple platforms — every other platform
/// must hide the button.
bool get appleSignInAvailable =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

class AppleSignInButton extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const AppleSignInButton({super.key, required this.onSuccess});

  @override
  ConsumerState<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends ConsumerState<AppleSignInButton> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithApple();
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

      // ── New Apple user: claim a username and create the profile ───────
      if (result.isNewUser) {
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AppleUsernameSheet(
            firebaseUser: result.firebaseUser,
            authService: ref.read(authServiceProvider),
          ),
        );
        // If the sheet was dismissed the account still has no Firestore
        // profile; the home screen then shows its own username setup.
        if (!mounted) return;
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

      if (mounted) widget.onSuccess();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('canceled')) {
        // user dismissed — no error shown
      } else if (mounted) {
        String friendly = 'Apple sign-in failed.';
        if (msg.contains('network') || msg.contains('NETWORK')) {
          friendly = 'No internet connection.';
        } else if (msg.contains('notHandled') ||
            msg.contains('invalid-credential')) {
          friendly =
              'Configuration error: Apple is not enabled in Firebase Console.';
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
      child: ElevatedButton(
        onPressed: _loading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          disabledBackgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          side: BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Apple's HIG requires the Apple mark next to an approved
                  // label; the glyph sits slightly high, hence the offset.
                  const Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Icon(Icons.apple, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Apple',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Username setup sheet for new Apple users ─────────────────────────────────

class _AppleUsernameSheet extends StatefulWidget {
  final User firebaseUser;
  final AuthService authService;
  const _AppleUsernameSheet({
    required this.firebaseUser,
    required this.authService,
  });

  @override
  State<_AppleUsernameSheet> createState() => _AppleUsernameSheetState();
}

class _AppleUsernameSheetState extends State<_AppleUsernameSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _skillLevel;

  static const _skillLevels = [
    'Beginner',
    'Casual',
    'Intermediate',
    'Advanced',
    'Expert'
  ];

  @override
  void initState() {
    super.initState();
    // Apple only shares the name on the first authorization — use it as a
    // starting point so the user rarely has to type anything.
    final suggestion = (widget.firebaseUser.displayName ?? '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (suggestion.length >= 3) _ctrl.text = suggestion;
  }

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authService.completeAppleSignUp(
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
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
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
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillLevels.map((level) {
              final selected = _skillLevel == level;
              return GestureDetector(
                onTap: () =>
                    setState(() => _skillLevel = selected ? null : level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.amber.withValues(alpha: 0.15)
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
                      color:
                          selected ? AppColors.amber : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
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

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../features/auth/widgets/apple_sign_in_button.dart'
    show appleSignInAvailable;
import '../../features/auth/widgets/google_sign_in_button.dart'
    show GoogleLogo;
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/email_validator.dart';

// Everything a guest (anonymous) account needs to be told: it works fully,
// but lives only on this device until an e-mail, Google or Apple sign-in is
// linked to it. Deleting the app — or signing out — loses it for good.

const _kDark = Color(0xFF1A1205);

/// Set by "Play as guest" so the home screen shows [showGuestWelcomeDialog]
/// once, right after the guest account is created.
final pendingGuestWelcomeProvider = StateProvider<bool>((_) => false);

/// Hidden for the rest of this app session once the banner's × is tapped.
/// It comes back on the next launch: the risk does not go away by itself.
final guestBannerDismissedProvider = StateProvider<bool>((_) => false);

// ── Welcome dialog (right after "Play as guest") ──────────────────────────────

Future<void> showGuestWelcomeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _GuestDialog(
      icon: PhosphorIcons.userCircleCheck(PhosphorIconsStyle.fill),
      title: 'guest_welcome_title'.tr(),
      body: 'guest_welcome_body'.tr(),
      primaryLabel: 'guest_add_email_now'.tr(),
      onPrimary: () {
        Navigator.of(ctx).pop();
        showLinkAccountSheet(context);
      },
      secondaryLabel: 'got_it'.tr(),
      onSecondary: () => Navigator.of(ctx).pop(),
    ),
  );
}

// ── Sign-out warning ──────────────────────────────────────────────────────────

/// Asks a guest to confirm signing out. Returns true only for "Sign out
/// anyway"; "Add e-mail" opens the link sheet and returns false.
Future<bool> confirmGuestSignOut(BuildContext context) async {
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => _GuestDialog(
      icon: PhosphorIcons.warning(PhosphorIconsStyle.fill),
      iconColor: AppColors.loss,
      title: 'guest_signout_title'.tr(),
      body: 'guest_signout_body'.tr(),
      primaryLabel: 'guest_add_email'.tr(),
      onPrimary: () => Navigator.of(ctx).pop('link'),
      secondaryLabel: 'guest_signout_anyway'.tr(),
      secondaryDanger: true,
      onSecondary: () => Navigator.of(ctx).pop('signout'),
      showCancel: true,
    ),
  );
  if (result == 'link' && context.mounted) {
    await showLinkAccountSheet(context);
  }
  return result == 'signout';
}

class _GuestDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final bool secondaryDanger;
  final bool showCancel;

  const _GuestDialog({
    required this.icon,
    this.iconColor = AppColors.amber,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.secondaryDanger = false,
    this.showCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.inkDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: _kDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: secondaryDanger ? AppColors.loss : AppColors.inkDim,
                ),
              ),
            ),
            if (showCancel)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'cancel'.tr(),
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.inkMute),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Home banner ───────────────────────────────────────────────────────────────

/// Compact warning card for guests. Renders nothing for everyone else.
class GuestBanner extends ConsumerWidget {
  final EdgeInsetsGeometry margin;
  final bool dismissible;
  const GuestBanner({
    super.key,
    this.margin = EdgeInsets.zero,
    this.dismissible = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final dismissed = ref.watch(guestBannerDismissedProvider);
    if (!isGuest || (dismissible && dismissed)) return const SizedBox.shrink();

    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.amberGlow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                color: AppColors.amber, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'guest_banner_title'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'guest_banner_body'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.inkDim,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => showLinkAccountSheet(context),
                    icon: Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.bold),
                        size: 16),
                    label: Text(
                      'guest_secure_account'.tr(),
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: _kDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (dismissible)
            IconButton(
              tooltip: 'close'.tr(),
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(guestBannerDismissedProvider.notifier).state = true,
              icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold),
                  size: 16, color: AppColors.inkMute),
            ),
        ],
      ),
    );
  }
}

// ── Link-account sheet ────────────────────────────────────────────────────────

/// Lets a guest attach an e-mail + password (or Google / Apple) to the
/// account they are already using. The uid does not change, so nothing is
/// lost. Returns true when an account was linked.
Future<bool> showLinkAccountSheet(BuildContext context) async {
  // Grabbed up front: the banner that opened the sheet disappears the moment
  // the account stops being a guest, taking its context with it.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final linked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LinkAccountSheet(),
  );
  if (linked == true) {
    messenger?.showSnackBar(
      SnackBar(content: Text('guest_linked_success'.tr())),
    );
  }
  return linked == true;
}

class _LinkAccountSheet extends ConsumerStatefulWidget {
  const _LinkAccountSheet();

  @override
  ConsumerState<_LinkAccountSheet> createState() => _LinkAccountSheetState();
}

class _LinkAccountSheetState extends ConsumerState<_LinkAccountSheet> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _busy; // 'email' | 'google' | 'apple'
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(String method, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() { _busy = method; _error = null; });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = _message(e);
      setState(() { _busy = null; _error = msg; });
    }
  }

  String? _message(Object e) {
    final code = e is FirebaseAuthException ? e.code : e.toString();
    if (code.contains('cancelled') || code.contains('canceled')) return null;
    if (code.contains('email-already-in-use')) return 'link_email_in_use'.tr();
    if (code.contains('credential-already-in-use') ||
        code.contains('account-exists-with-different-credential')) {
      return 'link_provider_in_use'.tr();
    }
    if (code.contains('provider-already-linked')) {
      return 'link_already_linked'.tr();
    }
    if (code.contains('invalid-email')) return 'err_invalid_email'.tr();
    if (code.contains('weak-password')) return 'err_password_short'.tr();
    if (code.contains('network-request-failed')) return 'err_no_internet'.tr();
    if (code.contains('too-many-requests')) return 'err_too_many_requests'.tr();
    return 'err_generic'.tr();
  }

  void _linkEmail() {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (!isValidEmail(email)) {
      setState(() => _error = 'err_invalid_email'.tr());
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'err_password_short'.tr());
      return;
    }
    _run('email', () => ref
        .read(authServiceProvider)
        .linkGuestWithEmail(email: email, password: pass));
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.inkMute),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: Icon(icon, size: 18, color: AppColors.inkMute),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final busy = _busy != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkMute,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'link_title'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'link_subtitle'.tr(),
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.inkDim, height: 1.5),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _emailCtrl,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.ink),
                decoration: _decoration('your@email.com',
                    PhosphorIcons.envelopeSimple(PhosphorIconsStyle.regular)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passCtrl,
                enabled: !busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _linkEmail(),
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.ink),
                decoration: _decoration(
                  'link_password_hint'.tr(),
                  PhosphorIcons.lock(PhosphorIconsStyle.regular),
                  suffix: IconButton(
                    tooltip: _obscure
                        ? 'show_password'.tr()
                        : 'hide_password'.tr(),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? PhosphorIcons.eye(PhosphorIconsStyle.regular)
                          : PhosphorIcons.eyeSlash(PhosphorIconsStyle.regular),
                      size: 18,
                      color: AppColors.inkMute,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lossSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.loss.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.loss, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: busy ? null : _linkEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    disabledBackgroundColor:
                        AppColors.amber.withValues(alpha: 0.5),
                    foregroundColor: _kDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _busy == 'email'
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kDark),
                        )
                      : Text(
                          'link_save_account'.tr(),
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'or_divider'.tr(),
                      style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11, color: AppColors.inkMute),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 12),
              _ProviderButton(
                label: 'continue_with_google'.tr(),
                leading: const GoogleLogo(),
                loading: _busy == 'google',
                onTap: busy
                    ? null
                    : () => _run('google',
                        () => ref.read(authServiceProvider).linkGuestWithGoogle()),
              ),
              if (appleSignInAvailable) ...[
                const SizedBox(height: 10),
                _ProviderButton(
                  label: 'continue_with_apple'.tr(),
                  leading: const Icon(Icons.apple, size: 20, color: AppColors.ink),
                  loading: _busy == 'apple',
                  onTap: busy
                      ? null
                      : () => _run('apple',
                          () => ref.read(authServiceProvider).linkGuestWithApple()),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final bool loading;
  final VoidCallback? onTap;

  const _ProviderButton({
    required this.label,
    required this.leading,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.borderStrong),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.amber),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

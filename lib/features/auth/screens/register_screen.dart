import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/constants/countries.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/google_sign_in_button.dart';

/// Skill levels shown on step 2.
const _skillLevels = [
  (label: 'Beginner', sub: 'Just learning the rules', rating: 400, emoji: '🐣'),
  (label: 'Casual', sub: 'Play for fun occasionally', rating: 800, emoji: '🙂'),
  (label: 'Intermediate', sub: 'Know most tactics', rating: 1200, emoji: '⚡'),
  (label: 'Advanced', sub: 'Study and play regularly', rating: 1600, emoji: '🔥'),
  (label: 'Expert', sub: 'Tournament experience', rating: 2000, emoji: '🏆'),
  (label: 'Master', sub: 'Professional / near-master', rating: 2400, emoji: '👑'),
];


class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Step 1 state
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Country picker
  String? _selectedCountryCode;

  // Live validation state
  String? _usernameError;
  bool _usernameValid = false;
  bool _checkingUsername = false;
  String? _emailError;
  String? _passwordStrength;
  String? _confirmError;
  Timer? _debounceTimer;

  // Step 2 state
  int? _selectedSkillIndex;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pageCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Live Validation ───────────────────────────────────────────────────────

  void _onUsernameChanged(String val) {
    _debounceTimer?.cancel();
    if (val.length < 3) {
      setState(() { _usernameError = 'Min 3 characters'; _usernameValid = false; });
      return;
    }
    if (val.length > 20) {
      setState(() { _usernameError = 'Max 20 characters'; _usernameValid = false; });
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) {
      setState(() { _usernameError = 'Only letters, numbers, underscore'; _usernameValid = false; });
      return;
    }
    setState(() { _usernameError = null; _checkingUsername = true; });
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final exists = await ref.read(authServiceProvider).usernameExists(val.trim());
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        if (exists) {
          _usernameError = 'Username taken';
          _usernameValid = false;
        } else {
          _usernameError = null;
          _usernameValid = true;
        }
      });
    });
  }

  void _onEmailChanged(String val) {
    final emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    setState(() {
      _emailError = emailRegex.hasMatch(val.trim()) ? null : 'Enter a valid email';
    });
  }

  void _onPasswordChanged(String val) {
    String strength;
    int score = 0;
    if (val.length >= 8) score++;
    if (val.contains(RegExp(r'[0-9]'))) score++;
    if (val.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;
    if (val.length >= 12) score++;
    strength = score <= 1 ? 'Weak' : (score <= 2 ? 'Medium' : 'Strong');
    setState(() {
      _passwordStrength = val.isEmpty ? null : strength;
      _confirmError = _confirmCtrl.text.isNotEmpty && _confirmCtrl.text != val
          ? 'Passwords do not match' : null;
    });
  }

  void _onConfirmChanged(String val) {
    setState(() {
      _confirmError = val != _passwordCtrl.text ? 'Passwords do not match' : null;
    });
  }

  // ── Country Picker ────────────────────────────────────────────────────────

  Future<void> _showCountryPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('choose_country'.tr(), style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            // Special: No flag
            ListTile(
              leading: const Text('🏳️', style: TextStyle(fontSize: 24)),
              title: Text('no_flag'.tr(), style: AppTextStyles.bodyMedium),
              onTap: () => Navigator.pop(ctx, '__none__'),
            ),
            // Special: International
            ListTile(
              leading: const Text('🌍', style: TextStyle(fontSize: 24)),
              title: Text('international'.tr(), style: AppTextStyles.bodyMedium),
              onTap: () => Navigator.pop(ctx, 'XX'),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: kCountries.length,
                itemBuilder: (_, i) {
                  final (code, name) = kCountries[i];
                  return ListTile(
                    leading: Text(UserModel.flagEmoji(code), style: const TextStyle(fontSize: 24)),
                    title: Text(name, style: AppTextStyles.bodyMedium),
                    onTap: () => Navigator.pop(ctx, code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (result == '__none__') {
        _selectedCountryCode = null;
      } else {
        _selectedCountryCode = result;
      }
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goToStep2() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_checkingUsername || _usernameError != null || !_usernameValid) {
      setState(() => _error = 'Please fix the errors above.');
      return;
    }
    FocusScope.of(context).unfocus();

    _pageCtrl.animateToPage(
      1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() { _currentPage = 1; _error = null; });
  }

  void _goToStep1() {
    _pageCtrl.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = 0);
  }

  // ── Registration ──────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (_selectedSkillIndex == null) {
      setState(() => _error = 'Please select your skill level.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final skill = _skillLevels[_selectedSkillIndex!];
    try {
      await ref.read(authServiceProvider).register(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            username: _usernameCtrl.text.trim(),
            startingRating: skill.rating,
            skillLevel: skill.label,
            countryCode: _selectedCountryCode,
          );
      if (mounted) context.go('/email-verification');
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (raw.contains('Username already taken')) {
      return 'That username is taken. Choose another.';
    }
    if (raw.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    return 'Registration failed. Please try again.';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(context.hPadding, 12, context.hPadding, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_currentPage == 1) _goToStep1();
                      else context.pop();
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: AppColors.inkDim, size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _currentPage == 0 ? 'create_account'.tr() : 'your_level'.tr(),
                      style: GoogleFonts.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  // Step pills
                  Row(
                    children: List.generate(2, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: i == _currentPage ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.primary
                              : AppColors.textHint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.isTablet ? 680 : 420,
                  ),
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(),
                      _Step2(
                        selectedIndex: _selectedSkillIndex,
                        onSelect: (i) =>
                            setState(() => _selectedSkillIndex = i),
                        error: _error,
                        loading: _loading,
                        onRegister: _register,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'register_story_headline'.tr(),
              style: GoogleFonts.fraunces(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: AppColors.ink,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2),
            const SizedBox(height: 8),
            Text(
              'register_community_subtitle'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.inkMute,
              ),
            ).animate(delay: 50.ms).fadeIn(),
            const SizedBox(height: 28),

            // Username field with live validation
            AppTextField(
              label: 'username'.tr(),
              hint: 'ChessMaster99',
              controller: _usernameCtrl,
              maxLength: 20,
              onChanged: _onUsernameChanged,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Username is required';
                if (v.length < 3) return 'Minimum 3 characters';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                  return 'Only letters, numbers, and underscores';
                }
                return null;
              },
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.15),
            if (_checkingUsername)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 6),
                    Text('Checking availability...', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                  ],
                ),
              )
            else if (_usernameError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(_usernameError!, style: TextStyle(color: AppColors.error, fontSize: 12)),
              )
            else if (_usernameValid)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text('Username available', style: TextStyle(color: AppColors.success, fontSize: 12)),
              ),
            const SizedBox(height: 16),

            // Email field
            AppTextField(
              label: 'email'.tr(),
              hint: 'your@email.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              onChanged: _onEmailChanged,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.15),
            if (_emailError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(_emailError!, style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            const SizedBox(height: 16),

            // Password field
            AppTextField(
              label: 'password'.tr(),
              hint: '••••••••',
              controller: _passwordCtrl,
              obscureText: true,
              onChanged: _onPasswordChanged,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),
            if (_passwordStrength != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    ...List.generate(3, (i) {
                      final colors = [AppColors.error, AppColors.warning, AppColors.success];
                      final filled = switch (_passwordStrength!) {
                        'Weak' => i == 0,
                        'Medium' => i <= 1,
                        _ => true,
                      };
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: filled ? colors[i] : context.appColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(_passwordStrength!, style: TextStyle(
                      fontSize: 11,
                      color: switch (_passwordStrength!) {
                        'Weak' => AppColors.error,
                        'Medium' => AppColors.warning,
                        _ => AppColors.success,
                      },
                      fontWeight: FontWeight.w500,
                    )),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Confirm password field
            AppTextField(
              label: 'confirm_password'.tr(),
              hint: '••••••••',
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: _onConfirmChanged,
              onSubmitted: (_) => _goToStep2(),
              validator: (v) {
                if (v != _passwordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.15),
            if (_confirmError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(_confirmError!, style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            const SizedBox(height: 16),

            // Country picker
            _CountryPickerRow(
              selectedCode: _selectedCountryCode,
              onTap: _showCountryPicker,
            ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.15),
            const SizedBox(height: 32),

            AppButton(
              label: 'next'.tr(),
              onTap: _goToStep2,
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
            const SizedBox(height: 12),
            // Apple platforms only — hidden everywhere else.
            if (appleSignInAvailable) ...[
              AppleSignInButton(
                onSuccess: () => context.go('/home'),
              ).animate(delay: 310.ms).fadeIn(),
              const SizedBox(height: 12),
            ],
            GoogleSignInButton(
              onSuccess: () => context.go('/home'),
            ).animate(delay: 320.ms).fadeIn(),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'already_account'.tr(),
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Text(
                    'sign_in'.tr(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ).animate(delay: 340.ms).fadeIn(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Country Picker Row ────────────────────────────────────────────────────────

class _CountryPickerRow extends StatelessWidget {
  final String? selectedCode;
  final VoidCallback onTap;
  const _CountryPickerRow({required this.selectedCode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String? name;
    String flag;
    if (selectedCode == 'XX') {
      name = 'international'.tr();
      flag = '🌍';
    } else if (selectedCode != null) {
      name = kCountries.firstWhere((c) => c.$1 == selectedCode, orElse: () => (selectedCode!, selectedCode!)).$2;
      flag = UserModel.flagEmoji(selectedCode);
    } else {
      flag = '';
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.divider, width: 1.5),
        ),
        child: Row(
          children: [
            if (selectedCode != null) ...[
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(name!, style: AppTextStyles.bodyMedium)),
            ] else
              Expanded(child: Text('country_optional'.tr(), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint))),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Skill level ───────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final int? selectedIndex;
  final void Function(int) onSelect;
  final String? error;
  final bool loading;
  final VoidCallback onRegister;

  const _Step2({
    required this.selectedIndex,
    required this.onSelect,
    required this.error,
    required this.loading,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('what_is_your_level'.tr(), style: AppTextStyles.displayMedium)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'starting_elo_subtitle'.tr(),
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ).animate(delay: 50.ms).fadeIn(),
          const SizedBox(height: 24),

          // 6 skill level cards (2-column grid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemCount: _skillLevels.length,
            itemBuilder: (_, i) {
              final skill = _skillLevels[i];
              final sel = selectedIndex == i;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withOpacity(0.15)
                        : context.appColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(skill.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const Spacer(),
                      Text(
                        'skill_${skill.label.toLowerCase()}'.tr(),
                        style: AppTextStyles.titleSmall.copyWith(
                          color: sel
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${skill.rating} ELO',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: sel
                              ? AppColors.primary.withOpacity(0.8)
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(delay: Duration(milliseconds: 60 * i))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.1);
            },
          ),

          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ).animate().shake(),
          ],

          const SizedBox(height: 28),
          AppButton(
            label: 'register'.tr(),
            onTap: loading ? null : onRegister,
            isLoading: loading,
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


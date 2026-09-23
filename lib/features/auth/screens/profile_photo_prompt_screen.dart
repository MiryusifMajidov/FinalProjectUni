import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/photo_service.dart';

// Session-level flag: true once the user has responded to the photo prompt
// (uploaded or skipped). Prevents the home screen from re-showing the prompt
// after the user dismisses it within the same app session.
final photoPromptDismissedProvider = StateProvider<bool>((ref) => false);

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = Color(0xFF0A0A0B);
const _kCard         = Color(0xFF1A1A1E);
const _kAmber        = Color(0xFFE8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kBorder       = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);

class ProfilePhotoPromptScreen extends ConsumerStatefulWidget {
  const ProfilePhotoPromptScreen({super.key});

  @override
  ConsumerState<ProfilePhotoPromptScreen> createState() =>
      _ProfilePhotoPromptScreenState();
}

class _ProfilePhotoPromptScreenState
    extends ConsumerState<ProfilePhotoPromptScreen> {
  bool _uploading = false;

  void _done() {
    // Mark dismissed for this session so home doesn't re-prompt
    ref.read(photoPromptDismissedProvider.notifier).state = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_uploading) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      _done();
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(photoServiceProvider)
          .pickAndUpload(user.uid, source: source);
      if (!mounted) return;
      if (url != null) _done();
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final username =
        userAsync.valueOrNull?.username ?? '';

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            children: [
              // Amber glow backdrop
              Positioned(
                top: 60,
                left: -40,
                right: -40,
                child: Center(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kAmber.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),

                  // "WELCOME, USERNAME"
                  if (username.isNotEmpty)
                    Text(
                      'WELCOME, ${username.toUpperCase()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kAmber,
                        letterSpacing: 1.4,
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Avatar slot
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kCard,
                          border: Border.all(
                            color: _kBorderStrong,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Ambient glow
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.4, -0.5),
                                    radius: 0.8,
                                    colors: [
                                      _kAmber.withValues(alpha: 0.22),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_uploading)
                              const Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: _kAmber,
                                  ),
                                ),
                              )
                            else
                              Center(
                                child: Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.fraunces(
                                    fontSize: 70,
                                    color: _kAmber.withValues(alpha: 0.85),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Camera badge
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _kAmber,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kBg, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: _kAmber.withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            PhosphorIcons.camera(PhosphorIconsStyle.fill),
                            size: 18,
                            color: const Color(0xFF1A1205),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Show your face.',
                    style: GoogleFonts.fraunces(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: 280,
                    child: Text(
                      'A photo helps friends recognize you across games and chats. You can change it any time.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _kInkDim,
                        height: 1.55,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── CTAs ──────────────────────────────────────────────────
                  Column(
                    children: [
                      // Primary: Take a photo
                      _AmberButton(
                        onTap: _uploading
                            ? () {}
                            : () => _pickPhoto(ImageSource.camera),
                        child: _uploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1A1205),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIcons.camera(
                                        PhosphorIconsStyle.fill),
                                    size: 16,
                                    color: const Color(0xFF1A1205),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Take a photo',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1205),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 10),

                      // Secondary: Choose from gallery
                      GestureDetector(
                        onTap: _uploading
                            ? null
                            : () => _pickPhoto(ImageSource.gallery),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIcons.image(PhosphorIconsStyle.regular),
                                size: 16,
                                color: _uploading ? _kInkMute : _kInk,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Choose from gallery',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _uploading ? _kInkMute : _kInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Tertiary: Skip
                      TextButton(
                        onPressed: _uploading ? null : _done,
                        child: Text(
                          'skip'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kInkMute,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Amber primary button ───────────────────────────────────────────────────────

class _AmberButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _AmberButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _kAmber,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kAmber.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

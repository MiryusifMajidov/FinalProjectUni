import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    final user = authState.isLoading
        ? await ref.read(authStateProvider.future)
        : authState.valueOrNull;

    if (!mounted) return;
    if (user != null) {
      context.go('/home');
      return;
    }
    // Android: a guest tied to this phone comes back by itself after cleared
    // app data or a reinstall, instead of landing on the start screen.
    final restored = await ref
        .read(authServiceProvider)
        .tryAutoRestoreDeviceGuest(
            firstSession: ref.read(cacheServiceProvider).isFirstSession)
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
    if (!mounted) return;
    context.go(restored ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    // The same felt and the same mark the launcher showed, so the hand-over
    // from the Android splash is seamless: no glow, no slogan, no bounce.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 88,
                height: 88,
                cacheWidth:
                    (88 * MediaQuery.devicePixelRatioOf(context)).round(),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'CheckMate',
              style: AppFonts.ui(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }
}

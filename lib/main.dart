import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/log_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Pre-load fonts before the first frame so glyphs are always ready.
  // A timeout prevents a slow/offline network from blocking the splash screen.
  // Impeller is disabled in AndroidManifest.xml (EnableImpeller=false) to avoid
  // Vulkan driver bugs that corrupt font texture atlases on certain Android GPUs.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.fraunces(),
      GoogleFonts.inter(),
      GoogleFonts.jetBrainsMono(),
    ]).timeout(const Duration(seconds: 5));
  } catch (_) {
    // Fonts will fall back to cached / system fonts — acceptable on slow networks.
  }

  // Lock to portrait on phones; tablets can use landscape too.
  // We set orientations later inside the app once we know the device type.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Disable Firestore offline persistence on web (avoids IndexedDB errors)
  if (kIsWeb) {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
  }

  // Initialize SharedPreferences cache (settings, flags)
  final cache = await CacheService.create();

  // Initialize push notifications (no-op on web).
  // This runs BEFORE runApp(), so it must never throw: an uncaught exception
  // here means no UI is ever built and the app looks hung on a white screen.
  // Push is a degradable feature — losing it must not cost us the launch.
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Push init failed (non-fatal): $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('az'),
        Locale('tr'),
        Locale('ru'),
        Locale('hi'),
        Locale('ur'),
        Locale('zh'),
        Locale('de'),
        Locale('es'),
        Locale('fr'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: ProviderScope(
        overrides: [
          cacheServiceProvider.overrideWith((_) => cache),
        ],
        child: const ChessApp(),
      ),
    ),
  );
}

class ChessApp extends ConsumerStatefulWidget {
  const ChessApp({super.key});

  @override
  ConsumerState<ChessApp> createState() => _ChessAppState();
}

class _ChessAppState extends ConsumerState<ChessApp>
    with WidgetsBindingObserver {
  Timer? _heartbeatTimer;

  /// Guards against restoring/creating the session more than once per
  /// app lifecycle (cold-start OR first sign-in).
  bool _sessionInitialized = false;

  /// Throttle session_start / session_end logs — at most one per 30 seconds
  /// to avoid spamming Firestore on rapid resume/pause cycles (e.g. pull-down
  /// notifications, phone calls, PiP, etc.).
  DateTime? _lastSessionLog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ping Firestore every 2 minutes to keep `lastSeen` fresh.
    // Also refresh the session's lastActiveAt so it doesn't expire.
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _pingLastSeen();
      _refreshSession();
    });

    // Try to restore the session after the first frame, by which point the
    // auth stream has had a chance to emit the cached user.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  // ── Session helpers ──────────────────────────────────────────────────────

  /// Checks the current auth state and immediately tries to restore/create a
  /// session if the user is already signed in (typical cold-start case).
  void _initSession() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) _tryRestoreSession(uid);
    // If uid is null (stream still loading), the ref.listen in build() will
    // catch the first non-null emission and call _tryRestoreSession.
  }

  /// Runs at most once per lifecycle. Restores the session from SharedPreferences
  /// (or creates a new one) and writes the ID into [currentSessionIdProvider].
  void _tryRestoreSession(String? uid) {
    if (uid == null || _sessionInitialized) return;
    _sessionInitialized = true;
    ref.read(authServiceProvider).restoreOrCreateSession(uid).then((sid) {
      if (sid != null && mounted) {
        ref.read(currentSessionIdProvider.notifier).state = sid;
      }
    });
  }

  /// Updates the session's lastActiveAt timestamp (called from heartbeat).
  void _refreshSession() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final sid = ref.read(currentSessionIdProvider);
    if (uid == null || sid == null) return;
    ref
        .read(firestoreServiceProvider)
        .refreshSession(uid, sid)
        .catchError((_) {});
  }

  void _pingLastSeen() {
    final cache = ref.read(cacheServiceProvider);
    if (!cache.onlineStatus || cache.invisibleMode) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    ref.read(firestoreServiceProvider).updateLastSeen(uid).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final logService = ref.read(logServiceProvider);

    // Try to get username from current user
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final username = currentUser?.username ?? 'unknown';

    // Throttle: skip if last log was less than 30 seconds ago.
    final now = DateTime.now();
    if (_lastSessionLog != null &&
        now.difference(_lastSessionLog!).inSeconds < 30) {
      return;
    }

    if (lifecycle == AppLifecycleState.resumed) {
      _lastSessionLog = now;
      logService.log(
        uid: uid,
        username: username,
        type: 'session_start',
        metadata: {
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'other',
        },
      );
    } else if (lifecycle == AppLifecycleState.paused) {
      _lastSessionLog = now;
      logService.log(
        uid: uid,
        username: username,
        type: 'session_end',
        metadata: {
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'other',
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state so we can restore a session when the user signs in
    // after the first frame (covers the case where auth is still loading
    // when initState / addPostFrameCallback runs).
    ref.listen(authStateProvider, (_, next) {
      final uid = next.valueOrNull?.uid;
      if (uid == null) {
        // User signed out — reset flag so the next sign-in is handled too.
        _sessionInitialized = false;
      } else {
        _tryRestoreSession(uid);
      }
    });
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      // key forces full widget-tree rebuild when locale changes,
      // ensuring every pushed page reflects the new language.
      key: ValueKey(context.locale.languageCode),
      title: 'CheckMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        // Global bottom-safe-area: keeps all content above the Android
        // navigation bar (back / home / recents buttons or gesture bar).
        // top: false → AppBar still draws behind the status bar (correct).
        // left/right: false → no unwanted side insets on normal phones.
        // Inner SafeArea widgets won't double-count because Flutter's
        // SafeArea removes its padding from the descendant MediaQuery.
        final Widget safeChild = SafeArea(
          top: false,
          left: false,
          right: false,
          child: child ?? const SizedBox.shrink(),
        );

        // Orientation: lock portrait on phones, allow landscape on tablets.
        final shortestSide = MediaQuery.of(context).size.shortestSide;
        final isTablet = shortestSide >= 600;
        if (!isTablet) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }

        // Web / very wide desktop: constrain to 520 px max-width, centered.
        // Tablets & phones: fill the screen fully — layout handled per-screen.
        final isWebWide = MediaQuery.of(context).size.width > 900 && !isTablet;
        if (!isWebWide) return safeChild;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ColoredBox(
          color: isDark ? const Color(0xFF070709) : const Color(0xFFE8E8F0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ClipRect(child: safeChild),
            ),
          ),
        );
      },
    );
  }
}

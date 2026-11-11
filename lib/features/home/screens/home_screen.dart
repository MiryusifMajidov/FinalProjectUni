import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/online_count.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/device_guest.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/models/user_model.dart';
import '../../profile/screens/profile_screen.dart';
import '../../auth/screens/profile_photo_prompt_screen.dart'
    show photoPromptDismissedProvider;
import '../../../core/models/game_model.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../game/widgets/recent_game_tile.dart';
import '../../tournaments/screens/tournament_list_screen.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/widgets/guest_notice.dart';
import '../../../core/widgets/invite_listener.dart';
import '../../../core/constants/countries.dart';
import '../../../core/models/game_type.dart';
import '../../../core/widgets/game_switch.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/moulded.dart';
import '../../../core/widgets/table_pieces.dart';
// Bot setup screens navigated via GoRouter (activeGame.botSetupRoute)

// ── Global rank provider ───────────────────────────────────────────────────────
// Counts users with a higher rating to approximate leaderboard rank.
// Key: "fieldPath:rating" e.g. "blitzStats.rating:1200"
// Cached (no autoDispose) — avoids re-querying every time the user
// switches back to the home tab.
final _globalRankProvider = FutureProvider.family<int, String>((
  ref,
  key,
) async {
  final parts = key.split(':');
  final field = parts[0];
  final rating = int.tryParse(parts[1]) ?? 1200;
  try {
    final agg =
        await FirebaseFirestore.instance
            .collection('users')
            .where(field, isGreaterThan: rating)
            .count()
            .get();
    return (agg.count ?? 0) + 1;
  } catch (_) {
    return 0; // 0 = unknown / fallback
  }
});

/// Sums rating changes from online rated games in the last 30 days.
/// Returns null when no qualifying games are found (badge hidden in that case).
/// Cached (no autoDispose) — reuses _recentGamesProvider, and updates with it.
final _monthlyRatingChangeProvider = FutureProvider.family<int?, String>((
  ref,
  uid,
) async {
  try {
    final games = await ref.watch(_recentGamesProvider(uid).future);
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    int total = 0;
    bool found = false;
    for (final g in games) {
      if (g.createdAt.isBefore(cutoff)) continue;
      if (g.mode != GameMode.online) continue;
      if (g.result == GameResult.ongoing || g.result == GameResult.aborted) {
        continue;
      }
      final isWhite = g.whiteUid == uid;
      final c = isWhite ? g.whiteRatingChange : g.blackRatingChange;
      if (c != null) {
        total += c;
        found = true;
      }
    }
    return found ? total : null;
  } catch (_) {
    return null;
  }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _onboardingChecked = false;
  bool _photoPromptShown = false;

  /// Tracks which tabs have been visited so we can build them lazily.
  /// IndexedStack builds all children at once — wrapping unvisited tabs in
  /// a lightweight placeholder avoids firing their Firestore streams and
  /// heavy widget trees on the very first frame.
  final _visitedTabs = <int>{0}; // Tab 0 (Home) is always visited initially

  @override
  void initState() {
    super.initState();
    // Run after the first frame so that navigation is fully settled
    // and ref.watch(currentUserProvider) in build() keeps the provider alive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGuestWelcomeIfPending();
      _checkPhotoPrompt();
      _ensureGameFields();
    });
  }

  /// Right after "Play as guest": explain once that the account lives only on
  /// this phone until an e-mail is added.
  void _showGuestWelcomeIfPending() {
    if (!mounted || !ref.read(pendingGuestWelcomeProvider)) return;
    ref.read(pendingGuestWelcomeProvider.notifier).state = false;
    showGuestWelcomeDialog(context);
  }

  /// Patches legacy Firestore docs so checkersStats/dominoStats exist.
  Future<void> _ensureGameFields() async {
    final uid = ref.read(currentUserProvider).valueOrNull?.uid;
    if (uid != null) {
      ref.read(firestoreServiceProvider).ensureGameFields(uid);
    }
  }

  /// Guaranteed one-shot photo-prompt trigger.
  /// Uses currentUserProvider.future which resolves as soon as Firestore emits
  /// the first value — regardless of how fast or slow the response is.
  Future<void> _checkPhotoPrompt() async {
    if (!mounted || _photoPromptShown) return;
    if (ref.read(photoPromptDismissedProvider)) return;

    // Fast path: data already in memory (Firestore local cache hit)
    UserModel? user = ref.read(currentUserProvider).valueOrNull;

    // Slow path: wait for stream to emit (up to 8 s)
    if (user == null) {
      try {
        user = await ref
            .read(currentUserProvider.future)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        return;
      }
    }

    if (!mounted || _photoPromptShown) return;
    if (ref.read(photoPromptDismissedProvider)) return;
    if (user == null) return;

    // Firebase Auth is the source of truth for guest-ness; repair the flag on
    // the profile if an earlier link-account write did not land.
    ref.read(authServiceProvider).syncGuestFlag(user);

    _photoPromptShown = true;
    // A guest came to play, not to fill in a profile — they get the welcome
    // dialog instead, and can add a photo from Account any time.
    if (user.isGuest || ref.read(isGuestProvider)) return;
    if ((user.photoUrl ?? '').isEmpty) {
      context.push('/auth/profile-photo');
    }
  }

  // ── Live location streaming ──────────────────────────────────────────────────
  // Only active when the user has opted in via showOnMap.
  StreamSubscription<Position>? _locationSub;
  DateTime? _lastLocationWrite;

  void _startLocationStream() async {
    if (_locationSub != null) return;

    // Only stream location when the user opted in.
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.showOnMap) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;

      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 30,
        ),
      ).listen(_onPositionUpdate);
    } catch (e) {
      debugPrint('[Location] stream start error: $e');
    }
  }

  void _stopLocationStream() {
    _locationSub?.cancel();
    _locationSub = null;
    _lastLocationWrite = null;
  }

  Future<void> _onPositionUpdate(Position pos) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    // Only track location when the user has explicitly opted in.
    if (!user.showOnMap) return;

    final now = DateTime.now();

    // Update the player-facing map, throttled to every 20 seconds.
    if (_lastLocationWrite == null ||
        now.difference(_lastLocationWrite!).inSeconds >= 20) {
      _lastLocationWrite = now;
      try {
        await ref
            .read(firestoreServiceProvider)
            .updateLocationOnly(user.uid, pos.latitude, pos.longitude);
      } catch (e) {
        debugPrint('[Location] write error: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_onboardingChecked) {
      _onboardingChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Start location stream only if the user opted in (showOnMap).
        _startLocationStream();
      });
    }
  }

  @override
  void dispose() {
    _stopLocationStream();
    super.dispose();
  }

  /// Profile is a tab like the others (it used to open as a separate page
  /// over the home screen, which hid the navigation bar).
  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The navigation and the tabs wear the selected game's colour
    // (AppColors.accent), so they rebuild when it changes.
    ref.watch(activeGameProvider);
    final userAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final myUid = userAsync.valueOrNull?.uid;

    if (authUser != null && userAsync.hasValue && userAsync.value == null) {
      return _CompleteProfileScreen(firebaseUser: authUser);
    }

    // Stream runs continuously for admin history tracking.
    // showOnMap toggling is handled inside _onPositionUpdate — no need to
    // start/stop the stream when the setting changes.

    final chatUnreadCount =
        myUid != null
            ? ref.watch(_chatUnreadProvider(myUid))
            : const AsyncValue.data(0);

    // Lazy tab loading: only build a tab's real content after it's been
    // visited at least once. This prevents IndexedStack from firing all
    // Firestore streams (tournaments, chats) on the very first frame.
    final tabs = [
      // Tab 0: Home (always built)
      Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: userAsync.when(
              loading: () => const _HomeShimmer(),
              error:
                  (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
              data:
                  (user) =>
                      user == null
                          ? const Center(child: CircularProgressIndicator())
                          : _HomeContent(user: user),
            ),
          ),
        ],
      ),
      // Tab 1: Arena (Tournaments) — deferred until first visit
      if (_visitedTabs.contains(1))
        const TournamentListScreen()
      else
        const SizedBox.shrink(),
      // Tab 2: Chat — deferred until first visit
      if (_visitedTabs.contains(2))
        const ChatListScreen()
      else
        const SizedBox.shrink(),
      // Tab 3: your profile — deferred until first visit
      if (_visitedTabs.contains(3) && myUid != null && myUid.isNotEmpty)
        ProfileScreen(uid: myUid, asTab: true)
      else
        const SizedBox.shrink(),
    ];

    final isTablet = context.isTablet;

    // Back from another tab returns to Play before it leaves the app.
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedIndex = 0);
      },
      child: InviteListener(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body:
              isTablet
                  ? Row(
                    children: [
                      // ── Side Navigation Rail (tablet) ──────────────────────────
                      _SideNav(
                        selectedIndex: _selectedIndex,
                        chatUnread: chatUnreadCount.valueOrNull ?? 0,
                        onTap: _onNavTap,
                      ),
                      // Divider
                      Container(width: 1, color: AppColors.border),
                      // ── Content ───────────────────────────────────────────────
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: tabs,
                        ),
                      ),
                    ],
                  )
                  : IndexedStack(index: _selectedIndex, children: tabs),
          bottomNavigationBar:
              isTablet
                  ? null
                  : _BottomNav(
                    selectedIndex: _selectedIndex,
                    chatUnread: chatUnreadCount.valueOrNull ?? 0,
                    onTap: _onNavTap,
                  ),
        ),
      ),
    );
  }
}

// ── Premium Bottom Navigation ──────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final int chatUnread;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.selectedIndex,
    required this.chatUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _NavItem(
                icon: PhosphorIcons.house(PhosphorIconsStyle.regular),
                iconFill: PhosphorIcons.house(PhosphorIconsStyle.fill),
                label: 'play'.tr(),
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: PhosphorIcons.trophy(PhosphorIconsStyle.regular),
                iconFill: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                label: 'arena'.tr(),
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                iconFill: PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
                label: 'chat'.tr(),
                selected: selectedIndex == 2,
                badge: chatUnread,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: PhosphorIcons.userCircle(PhosphorIconsStyle.regular),
                iconFill: PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
                label: 'profile'.tr(),
                selected: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData iconFill;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.iconFill,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon pill
            Container(
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.accentGlow : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child:
                    badge > 0 && !selected
                        ? _NavBadge(
                          count: badge,
                          child: Icon(
                            selected ? iconFill : icon,
                            color:
                                selected ? AppColors.accent : AppColors.inkMute,
                            size: 22,
                          ),
                        )
                        : Icon(
                          selected ? iconFill : icon,
                          color: selected ? AppColors.accent : AppColors.inkMute,
                          size: 22,
                        ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.ui(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.ink : AppColors.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Side Navigation Rail (tablet) ─────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  final int selectedIndex;
  final int chatUnread;
  final ValueChanged<int> onTap;

  const _SideNav({
    required this.selectedIndex,
    required this.chatUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        PhosphorIcons.house(PhosphorIconsStyle.regular),
        PhosphorIcons.house(PhosphorIconsStyle.fill),
        'play'.tr(),
        0,
      ),
      (
        PhosphorIcons.trophy(PhosphorIconsStyle.regular),
        PhosphorIcons.trophy(PhosphorIconsStyle.fill),
        'arena'.tr(),
        0,
      ),
      (
        PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
        PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
        'chat'.tr(),
        chatUnread,
      ),
      (
        PhosphorIcons.userCircle(PhosphorIconsStyle.regular),
        PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
        'profile'.tr(),
        0,
      ),
    ];

    return Container(
      width: 80,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Logo
            const AppLogo(size: 40),
            const SizedBox(height: 24),
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final (icon, iconFill, label, badge) = e.value;
              final selected = selectedIndex == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.accentGlow : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        badge > 0 && !selected
                            ? _NavBadge(
                              count: badge,
                              child: Icon(
                                selected ? iconFill : icon,
                                color:
                                    selected
                                        ? AppColors.accent
                                        : AppColors.inkMute,
                                size: 22,
                              ),
                            )
                            : Icon(
                              selected ? iconFill : icon,
                              color:
                                  selected
                                      ? AppColors.accent
                                      : AppColors.inkMute,
                              size: 22,
                            ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: AppFonts.ui(
                            fontSize: 9.5,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color:
                                selected ? AppColors.accent : AppColors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Photo Onboarding Bottom Sheet ─────────────────────────────────────────────

class _PhotoOnboardingSheet extends ConsumerStatefulWidget {
  final String uid;
  final String username;
  const _PhotoOnboardingSheet({required this.uid, required this.username});

  @override
  ConsumerState<_PhotoOnboardingSheet> createState() =>
      _PhotoOnboardingSheetState();
}

class _PhotoOnboardingSheetState extends ConsumerState<_PhotoOnboardingSheet>
    with SingleTickerProviderStateMixin {
  bool _uploading = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?';
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35],
          colors: [AppColors.accentGlow, AppColors.surface],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(28, 14, 28, bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.inkMute.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 40),

          // Avatar
          GestureDetector(
            onTap: _uploading ? null : _pickPhoto,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder:
                  (_, child) => Transform.scale(
                    scale: _uploading ? 1.0 : _pulseAnim.value,
                    child: child,
                  ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 48,
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _uploading ? 0.55 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: AppFonts.ui(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111915),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_uploading)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          AnimatedOpacity(
            opacity: _uploading ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              'Tap to choose',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accent.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Put a face to the name.',
            style: AppTextStyles.headlineLarge.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your photo appears next to your moves,\nmessages, and across the board.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.inkDim,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _uploading ? null : _pickPhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: const Color(0xFF111915),
                disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child:
                    _uploading
                        ? Text(
                          'uploading'.tr(),
                          key: const ValueKey('uploading'),
                          style: AppTextStyles.buttonLarge.copyWith(
                            color: const Color(0xFF111915).withOpacity(0.7),
                          ),
                        )
                        : Text(
                          'upload_photo'.tr(),
                          key: const ValueKey('idle'),
                          style: AppTextStyles.buttonLarge.copyWith(
                            color: const Color(0xFF111915),
                          ),
                        ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          TextButton(
            onPressed: _uploading ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Not now',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkMute,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(photoServiceProvider)
          .pickAndUpload(widget.uid);
      if (!mounted) return;
      if (url != null) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      // silently fall through
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

// ── Home Content ───────────────────────────────────────────────────────────────

class _HomeContent extends ConsumerWidget {
  final UserModel user;
  const _HomeContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    final isTablet = context.isTablet;
    final hp = context.hPadding;
    final activeGame = ref.watch(activeGameProvider);

    return isTablet
        ? _buildTabletLayout(context, isOnline, hp, ref, activeGame)
        : _buildPhoneLayout(context, isOnline, hp, ref, activeGame);
  }

  // ── Tablet: two-column layout ─────────────────────────────────────────────

  Widget _buildTabletLayout(
    BuildContext context,
    bool isOnline,
    double hp,
    WidgetRef ref,
    GameType activeGame,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, hp, showLogo: false),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hp, 12, hp / 2, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const GameSwitch(),
                    const SizedBox(height: 16),
                    _PlayerPanel(user: user, activeGame: activeGame),
                    const SizedBox(height: 18),
                    _buildPlaySection(context, ref, isOnline, activeGame),
                    const GuestBanner(margin: EdgeInsets.only(top: 16)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hp / 2, 28, hp, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SectionTitle('recent_games'.tr()),
                    const SizedBox(height: 10),
                    _RecentGames(uid: user.uid),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Phone: single-column layout ───────────────────────────────────────────

  Widget _buildPhoneLayout(
    BuildContext context,
    bool isOnline,
    double hp,
    WidgetRef ref,
    GameType activeGame,
  ) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, hp, showLogo: true),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hp, 6, hp, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const GameSwitch(),
              const SizedBox(height: 14),
              _PlayerPanel(user: user, activeGame: activeGame),
              const SizedBox(height: 16),
              _buildPlaySection(context, ref, isOnline, activeGame),
              // Below the Play button, not above it: the guest's risk is
              // worth a card, not worth pushing the game off the screen.
              const GuestBanner(margin: EdgeInsets.only(top: 16)),
              const SizedBox(height: 28),
              _SectionTitle('recent_games'.tr()),
              const SizedBox(height: 10),
              _RecentGames(uid: user.uid),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Shared sub-widgets ────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(
    BuildContext context,
    double hp, {
    required bool showLogo,
  }) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: 64,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: hp),
        child: Row(
          children: [
            if (showLogo) ...[
              const AppLogo(size: 30),
              const SizedBox(width: 10),
              Text(
                'CheckMate',
                style: AppFonts.ui(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
            const Spacer(),
            _NavButton(
              icon: PhosphorIcons.ranking(PhosphorIconsStyle.bold),
              tooltip: 'leaderboard'.tr(),
              onTap: () => context.push('/home/leaderboard'),
            ),
            const SizedBox(width: 8),
            _NavButton(
              icon: PhosphorIcons.mapPin(PhosphorIconsStyle.bold),
              tooltip: 'map'.tr(),
              onTap: () => context.push('/home/map'),
            ),
            const SizedBox(width: 8),
            _NavButton(
              icon: PhosphorIcons.gear(PhosphorIconsStyle.bold),
              tooltip: 'settings'.tr(),
              onTap: () => context.push('/home/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaySection(
    BuildContext context,
    WidgetRef ref,
    bool isOnline,
    GameType activeGame,
  ) {
    final accent = activeGame.accent;
    // Players online now: the same number as on the player map.
    final online = ref.watch(onlineCountProvider).valueOrNull;
    final playSub = !isOnline
        ? 'offline'.tr()
        : online == null
            ? 'ranked_online'.tr()
            : '${'rated_game'.tr()} · ${'online_now_n'.tr(namedArgs: {
                'count': NumberFormat.decimalPattern(context.locale.toString())
                    .format(online),
              })}';
    final progress = switch (activeGame) {
      GameType.checkers => user.checkersCampaignProgress,
      GameType.domino => user.dominoCampaignProgress,
      GameType.chess => user.campaignProgress,
    };
    final chapters = activeGame.identity.questChapters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── The one big action ────────────────────────────────────────────
        SizedBox(
          height: 68,
          child: Moulded(
            color: accent,
            radius: 16,
            lip: 5,
            semanticLabel: 'play_online'.tr(),
            onTap: isOnline ? () => context.push('/home/matchmaking') : null,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.fill),
                  color: AppColors.onAmber,
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'play_online'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.ui(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onAmber,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        playSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.ui(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                  color: AppColors.onAmber,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ModeTile(
          icon: PhosphorIcons.robot(PhosphorIconsStyle.bold),
          accent: accent,
          title: 'play_vs_bot'.tr(),
          subtitle: 'bot_tiers'.tr(),
          onTap: () => context.push(activeGame.botSetupRoute),
        ),
        const SizedBox(height: 8),
        _ModeTile(
          icon: PhosphorIcons.usersThree(PhosphorIconsStyle.bold),
          accent: accent,
          title: 'play_friend'.tr(),
          subtitle: isOnline ? 'invite_or_local'.tr() : 'local_only'.tr(),
          onTap: () => _showFriendOptions(context, isOnline, activeGame),
        ),
        const SizedBox(height: 8),
        _ModeTile(
          icon: PhosphorIcons.path(PhosphorIconsStyle.bold),
          accent: accent,
          title: activeGame.identity.questTitle,
          subtitle: '${'campaign'.tr()} · $progress/$chapters',
          progress: chapters == 0 ? 0 : progress / chapters,
          onTap: () => context.push('/home/campaign'),
        ),
        _ArenaTeaser(gameType: activeGame),
      ],
    );
  }

  void _showFriendOptions(
    BuildContext context,
    bool isOnline,
    GameType activeGame,
  ) {
    final accent = activeGame.identity.accent;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'play_with_friend'.tr(),
                  style: AppFonts.ui(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'friend_sheet_sub'.tr(),
                  style: AppFonts.ui(fontSize: 12, color: AppColors.inkMute),
                ),
                const SizedBox(height: 20),
                // Same Device option
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/home/local-setup');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.cardElevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              PhosphorIcons.usersFour(
                                PhosphorIconsStyle.regular,
                              ),
                              color: accent,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'same_device'.tr(),
                                style: AppFonts.ui(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'same_device_subtitle'.tr(),
                                style: AppFonts.ui(
                                  fontSize: 13,
                                  color: AppColors.inkMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                          color: AppColors.inkMute,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Invite by Username option
                GestureDetector(
                  onTap:
                      isOnline
                          ? () {
                            Navigator.pop(ctx);
                            context.push('/home/invite');
                          }
                          : () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('no_internet'.tr())),
                            );
                          },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.cardElevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              PhosphorIcons.wifiHigh(PhosphorIconsStyle.bold),
                              color: accent,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'invite_by_username'.tr(),
                                style: AppFonts.ui(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isOnline
                                    ? 'invite_subtitle'.tr()
                                    : 'requires_internet'.tr(),
                                style: AppFonts.ui(
                                  fontSize: 11,
                                  color:
                                      isOnline
                                          ? AppColors.inkMute
                                          : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                          color: AppColors.inkMute,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                // 2v2 table with friends — domino only (classic partnership play)
                if (activeGame == GameType.domino) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap:
                        isOnline
                            ? () {
                              Navigator.pop(ctx);
                              context.push('/home/domino-table');
                            }
                            : () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('no_internet'.tr())),
                              );
                            },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIcons.usersFour(
                                  PhosphorIconsStyle.regular,
                                ),
                                color: accent,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'domino_table_2v2'.tr(),
                                  style: AppFonts.ui(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOnline
                                      ? 'domino_table_2v2_sub'.tr()
                                      : 'requires_internet'.tr(),
                                  style: AppFonts.ui(
                                    fontSize: 11,
                                    color:
                                        isOnline
                                            ? AppColors.inkMute
                                            : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            PhosphorIcons.caretRight(
                              PhosphorIconsStyle.regular,
                            ),
                            color: AppColors.inkMute,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }
}

// ── Nav icon button ───────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Moulded(
          color: AppColors.card,
          radius: 12,
          lip: 3,
          semanticLabel: tooltip,
          onTap: onTap,
          child: Center(child: Icon(icon, color: AppColors.inkDim, size: 20)),
        ),
      ),
    );
  }
}

/// The position after [moves] (SAN), or null if they do not replay.
String? _finalFen(List<String> moves) {
  try {
    final game = ch.Chess();
    for (final m in moves) {
      if (!game.move(m)) return null;
    }
    return game.fen;
  } catch (_) {
    return null;
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppFonts.ui(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.2,
    ),
  );
}

// ── Player panel: the game's object, the rating, the record ──────────────────

class _PlayerPanel extends ConsumerWidget {
  final UserModel user;
  final GameType activeGame;
  const _PlayerPanel({required this.user, this.activeGame = GameType.chess});

  // Chess shows the Blitz rating: a real pool, ranked on the same field
  // below. (It used to show an average of three pools that exists nowhere
  // in the data, ranked against Blitz.)
  int get _rating => switch (activeGame) {
    GameType.checkers => user.checkersStats.rating,
    GameType.domino => user.dominoStats.rating,
    GameType.chess => user.blitzStats.rating,
  };

  (int, int, int) get _record => switch (activeGame) {
    GameType.checkers => (
      user.checkersStats.wins,
      user.checkersStats.draws,
      user.checkersStats.losses,
    ),
    GameType.domino => (
      user.dominoStats.wins,
      user.dominoStats.draws,
      user.dominoStats.losses,
    ),
    GameType.chess => (
      user.bulletStats.wins + user.blitzStats.wins + user.rapidStats.wins,
      user.bulletStats.draws + user.blitzStats.draws + user.rapidStats.draws,
      user.bulletStats.losses + user.blitzStats.losses + user.rapidStats.losses,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankField = switch (activeGame) {
      GameType.checkers => 'checkersStats.rating',
      GameType.domino => 'dominoStats.rating',
      GameType.chess => 'blitzStats.rating',
    };
    final rating = _rating;
    final rank = ref
        .watch(_globalRankProvider('$rankField:$rating'))
        .maybeWhen(data: (r) => r > 0 ? '#$r' : '—', orElse: () => '…');
    final change =
        ref.watch(_monthlyRatingChangeProvider(user.uid)).valueOrNull;
    final (w, d, l) = _record;
    final kind = activeGame.isPointBased ? 'points_label'.tr() : 'blitz'.tr();
    // Chess: the final position of the player's last game; the start
    // position before their first one.
    String? lastFen;
    if (activeGame == GameType.chess) {
      final games = ref.watch(_recentGamesProvider(user.uid)).valueOrNull;
      final last =
          games
              ?.where((g) => g.gameType == 'chess' && g.moves.isNotEmpty)
              .firstOrNull;
      if (last != null) lastFen = _finalFen(last.moves);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GamePreview(game: activeGame.name, size: 104, fen: lastFen),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.ui(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkDim,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$rating',
                          style: AppFonts.ui(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -1,
                            height: 1.05,
                            fontFeatures: AppTextStyles.tabularFigures,
                          ),
                        ),
                        if (change != null && change != 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${change > 0 ? '+' : '−'}${change.abs()}',
                            style: AppFonts.ui(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color:
                                  change > 0 ? AppColors.win : AppColors.loss,
                              fontFeatures: AppTextStyles.tabularFigures,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$kind · ${'rank_global'.tr(namedArgs: {'rank': rank})}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.ui(
                        fontSize: 13,
                        color: AppColors.inkMute,
                        fontFeatures: AppTextStyles.tabularFigures,
                      ),
                    ),
                    Text(
                      '${w}W · ${d}D · ${l}L',
                      style: AppFonts.ui(
                        fontSize: 13,
                        color: AppColors.inkMute,
                        fontFeatures: AppTextStyles.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Mode tile: a moulded row on the felt ─────────────────────────────────────

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final double? progress;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Moulded(
      color: AppColors.card,
      radius: 14,
      semanticLabel: '$title, $subtitle',
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(
                    fontSize: 13,
                    color: AppColors.inkMute,
                    fontFeatures: AppTextStyles.tabularFigures,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: AppColors.cardElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
            color: AppColors.inkMute,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ── Recent games ───────────────────────────────────────────────────────────────

class _RecentGames extends ConsumerWidget {
  final String uid;
  const _RecentGames({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(_recentGamesProvider(uid));
    return gamesAsync.when(
      // After a game the list reloads; keep showing the old one meanwhile.
      skipLoadingOnReload: true,
      loading: () => const ShimmerList(count: 3, itemHeight: 70),
      error: (_, __) => const SizedBox.shrink(),
      data: (games) {
        if (games.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.clockCounterClockwise(
                    PhosphorIconsStyle.regular,
                  ),
                  color: AppColors.inkMute,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'no_games_start_playing'.tr(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.inkDim,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children:
              games
                  .map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap:
                            g.gameType == 'chess'
                                ? () => context.push(
                                  '/home/game-replay/${g.id}',
                                  extra: uid,
                                )
                                : null, // replay not yet available for checkers/domino
                        child: RecentGameTile(game: g, uid: uid),
                      ),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

final _recentGamesProvider = FutureProvider.family<List<GameModel>, String>((
  ref,
  uid,
) {
  // Fetched once and reused — but again whenever a finished game is recorded
  // (it is appended to the profile's recentGameIds). Without this the list
  // and the monthly rating badge kept showing the state from app launch.
  ref.watch(
    currentUserProvider.select((u) => u.valueOrNull?.recentGameIds.lastOrNull),
  );
  return ref.read(firestoreServiceProvider).getRecentGames(uid);
});

// ── Complete profile (signed in, but no users/{uid} document) ────────────────

/// Shown when the account is signed in but has no profile document yet: a
/// new Google/Apple user, a guest whose setup was interrupted, or an e-mail
/// account from before registration became atomic.
///
/// Guests get their random-name profile created automatically. Everyone else
/// picks a username. (This used to be "Google username setup" for every case,
/// with a button labelled "Verify" and no way out except force-closing the app.)
class _CompleteProfileScreen extends ConsumerStatefulWidget {
  final User firebaseUser;
  const _CompleteProfileScreen({required this.firebaseUser});

  @override
  ConsumerState<_CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<_CompleteProfileScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _countryCode;
  bool _creatingGuest = false;

  @override
  void initState() {
    super.initState();
    final region =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode
            ?.toUpperCase();
    if (region != null && kCountries.any((c) => c.$1 == region)) {
      _countryCode = region;
    }
    if (isGuestUser(widget.firebaseUser)) {
      _creatingGuest = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _createGuestProfile(),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _createGuestProfile() async {
    setState(() {
      _creatingGuest = true;
      _error = null;
    });
    try {
      // The profile stream picks the new document up and swaps this screen
      // for home on its own.
      await ref
          .read(authServiceProvider)
          .ensureGuestProfile(widget.firebaseUser);
    } catch (e) {
      if (mounted) {
        setState(() {
          _creatingGuest = false;
          _error = 'guest_failed'.tr();
        });
      }
    }
  }

  String _flagEmoji(String code) => UserModel.flagEmoji(code);

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder:
                (_, ctrl) => Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.inkMute,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'choose_country'.tr(),
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          controller: ctrl,
                          itemCount: kCountries.length,
                          itemBuilder: (_, i) {
                            final (code, name) = kCountries[i];
                            return ListTile(
                              leading: Text(
                                _flagEmoji(code),
                                style: const TextStyle(fontSize: 22),
                              ),
                              title: Text(
                                name,
                                style: AppTextStyles.bodyMedium,
                              ),
                              onTap: () => Navigator.of(context).pop(code),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
    if (picked != null) setState(() => _countryCode = picked);
  }

  Future<void> _submit() async {
    final username = _ctrl.text.trim();
    if (username.length < 3) {
      setState(() => _error = 'err_username_min'.tr());
      return;
    }
    if (username.length > 20) {
      setState(() => _error = 'err_username_max'.tr());
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() => _error = 'err_username_chars'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .completeProfile(
            firebaseUser: widget.firebaseUser,
            username: username,
            countryCode: _countryCode,
          );
      if (mounted) {
        context.push('/auth/profile-photo');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              e.toString().contains('already taken')
                  ? 'err_username_taken'.tr()
                  : 'err_generic'.tr();
        });
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_creatingGuest) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'guest_setting_up'.tr(),
                style: AppFonts.ui(fontSize: 14, color: AppColors.inkDim),
              ),
            ],
          ),
        ),
      );
    }

    final (countryFlag, countryName) =
        _countryCode != null
            ? (
              _flagEmoji(_countryCode!),
              kCountries
                  .firstWhere(
                    (c) => c.$1 == _countryCode,
                    orElse: () => (_countryCode!, _countryCode!),
                  )
                  .$2,
            )
            : ('', '');
    final isAnon = isGuestUser(widget.firebaseUser);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  const AppLogo(size: 56),
                  const SizedBox(height: 20),
                  Text(
                    'choose_username'.tr(),
                    style: AppFonts.ui(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'choose_username_subtitle'.tr(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.inkDim,
                    ),
                  ),
                  if ((widget.firebaseUser.email ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.firebaseUser.email!,
                      style: AppFonts.ui(
                        fontSize: 13,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  TextField(
                    controller: _ctrl,
                    autofocus: !isAnon,
                    maxLength: 20,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'username'.tr(),
                      hintText: 'e.g. chess_master',
                      filled: true,
                      fillColor: AppColors.card,
                      errorText: _error,
                      counterText: '',
                    ),
                    style: AppTextStyles.bodyLarge,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),

                  // Country picker
                  GestureDetector(
                    onTap: _pickCountry,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          if (_countryCode != null) ...[
                            Text(
                              countryFlag,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                countryName,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ] else
                            Expanded(
                              child: Text(
                                'country_optional'.tr(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.inkMute,
                                ),
                              ),
                            ),
                          Icon(
                            PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                            color: AppColors.inkMute,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child:
                          _loading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF111915),
                                ),
                              )
                              : Text(
                                'continue'.tr(),
                                style: AppTextStyles.buttonLarge.copyWith(
                                  color: const Color(0xFF111915),
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _signOut,
                      child: Text(
                        'use_different_account'.tr(),
                        style: AppFonts.ui(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkDim,
                        ),
                      ),
                    ),
                  ),
                  if (isAnon && _error != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _createGuestProfile,
                        child: Text('retry'.tr()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Arena teaser ──────────────────────────────────────────────────────────────

/// The live (or next) arena for the selected game, one tap from home. The
/// live arenas only help if people notice them; they used to live two taps
/// deep in the Arena tab.
class _ArenaTeaser extends ConsumerStatefulWidget {
  final GameType gameType;
  const _ArenaTeaser({required this.gameType});

  @override
  ConsumerState<_ArenaTeaser> createState() => _ArenaTeaserState();
}

class _ArenaTeaserState extends ConsumerState<_ArenaTeaser> {
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tick; // start the countdown
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arenas = ref.watch(openArenasProvider).valueOrNull ?? const [];
    final open = sortArenas(
      arenas.where((t) => t.gameType == widget.gameType.name && !t.isFinished),
    );
    if (open.isEmpty) return const SizedBox.shrink();
    // The live server arena with the most time left is the best one to join.
    final liveServer =
        open.where((t) => t.isActive && t.isSystem).toList()..sort(
          (a, b) =>
              (b.endsAt ?? DateTime(0)).compareTo(a.endsAt ?? DateTime(0)),
        );
    final t = liveServer.isNotEmpty ? liveServer.first : open.first;
    final accent = widget.gameType.accent;
    final now = DateTime.now();
    final live = t.isActive;
    final timing =
        live && t.endsAt != null
            ? 'arena_ends_in'.tr(
              namedArgs: {'time': formatCountdown(t.endsAt!.difference(now))},
            )
            : t.startsAt != null
            ? 'arena_starts_in_short'.tr(
              namedArgs: {'time': formatCountdown(t.startsAt!.difference(now))},
            )
            : 'arena_status_waiting'.tr();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        button: true,
        label: tournamentDisplayName(t),
        child: GestureDetector(
          onTap: () => context.push('/home/tournaments/${t.id}'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.cardElevated,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (live) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.live,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              tournamentDisplayName(t),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.ui(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${arenaClockLabel(t)} · $timing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.ui(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 13,
                          color: AppColors.inkMute,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Moulded(
                  color: accent,
                  radius: 10,
                  lip: 3,
                  onTap: () => context.push('/home/tournaments/${t.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Text(
                    'join'.tr(),
                    style: AppFonts.ui(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onAmber,
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

// ── Home Shimmer ───────────────────────────────────────────────────────────────

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 64),
          const ShimmerBox(width: 120, height: 14, borderRadius: 6),
          const SizedBox(height: 6),
          const ShimmerBox(width: 220, height: 36, borderRadius: 8),
          const SizedBox(height: 20),
          const ShimmerBox(
            width: double.infinity,
            height: 110,
            borderRadius: 18,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 90,
                  borderRadius: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 90,
                  borderRadius: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 90,
                  borderRadius: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const ShimmerBox(width: 60, height: 12, borderRadius: 4),
          const SizedBox(height: 10),
          const ShimmerBox(
            width: double.infinity,
            height: 72,
            borderRadius: 16,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 100,
                  borderRadius: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 100,
                  borderRadius: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Nav Badge ─────────────────────────────────────────────────────────────────

class _NavBadge extends StatelessWidget {
  final Widget child;
  final int count;
  const _NavBadge({required this.child, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: AppColors.loss,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _chatUnreadProvider = StreamProvider.family<int, String>((ref, uid) {
  // Watched rather than read, so blocking someone clears their contribution to
  // the badge immediately instead of at the next cold start.
  final blocked =
      ref.watch(currentUserProvider).valueOrNull?.blockedUsers ??
      const <String>[];
  return ref
      .read(chatServiceProvider)
      .watchTotalUnread(uid, blockedUids: blocked);
});

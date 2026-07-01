import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/models/user_model.dart';
import '../../auth/screens/profile_photo_prompt_screen.dart'
    show photoPromptDismissedProvider;
import '../../../core/models/game_model.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../game/widgets/recent_game_tile.dart';
import '../../tournaments/screens/tournament_list_screen.dart';
import '../../../core/widgets/invite_listener.dart';
import '../../../core/services/log_service.dart';
import '../../../core/constants/countries.dart';
import '../../../core/models/game_type.dart';
import '../../../core/widgets/game_switch.dart';
// Bot setup screens navigated via GoRouter (activeGame.botSetupRoute)

// ── Global rank provider ───────────────────────────────────────────────────────
// Counts users with a higher rating to approximate leaderboard rank.
// Key: "fieldPath:rating" e.g. "blitzStats.rating:1200"
// Cached (no autoDispose) — avoids re-querying every time the user
// switches back to the home tab.
final _globalRankProvider =
    FutureProvider.family<int, String>((ref, key) async {
  final parts = key.split(':');
  final field = parts[0];
  final rating = int.tryParse(parts[1]) ?? 1200;
  try {
    final agg = await FirebaseFirestore.instance
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
/// Cached (no autoDispose) — reuses the already-cached _recentGamesProvider.
final _monthlyRatingChangeProvider =
    FutureProvider.family<int?, String>((ref, uid) async {
  try {
    final games = await ref.read(_recentGamesProvider(uid).future);
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
      _checkPhotoPrompt();
      _ensureGameFields();
    });
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

    _photoPromptShown = true;
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
          permission == LocationPermission.deniedForever) return;

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

  void _onNavTap(int index) {
    if (index == 3) {
      final myUid = ref.read(currentUserProvider).valueOrNull?.uid;
      if (myUid != null && myUid.isNotEmpty) {
        context.push('/home/profile/$myUid');
      }
    } else {
      setState(() {
        _selectedIndex = index;
        _visitedTabs.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final myUid = userAsync.valueOrNull?.uid;

    if (authUser != null && userAsync.hasValue && userAsync.value == null) {
      return _GoogleUsernameSetup(firebaseUser: authUser);
    }

    // Stream runs continuously for admin history tracking.
    // showOnMap toggling is handled inside _onPositionUpdate — no need to
    // start/stop the stream when the setting changes.

    final chatUnreadCount = myUid != null
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
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error)),
              ),
              data: (user) => user == null
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
    ];

    final isTablet = context.isTablet;

    return InviteListener(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: isTablet
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
            : IndexedStack(
                index: _selectedIndex,
                children: tabs,
              ),
        bottomNavigationBar: isTablet
            ? null
            : _BottomNav(
                selectedIndex: _selectedIndex,
                chatUnread: chatUnreadCount.valueOrNull ?? 0,
                onTap: _onNavTap,
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
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
                selected: false,
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
              width: 44,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? AppColors.amberGlow : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: badge > 0 && !selected
                    ? _NavBadge(
                        count: badge,
                        child: Icon(
                          selected ? iconFill : icon,
                          color: selected ? AppColors.amber : AppColors.inkMute,
                          size: 20,
                        ),
                      )
                    : Icon(
                        selected ? iconFill : icon,
                        color: selected ? AppColors.amber : AppColors.inkMute,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.amber : AppColors.inkMute,
                letterSpacing: 0.3,
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
      (PhosphorIcons.house(PhosphorIconsStyle.regular),
       PhosphorIcons.house(PhosphorIconsStyle.fill),
       'play'.tr(), 0),
      (PhosphorIcons.trophy(PhosphorIconsStyle.regular),
       PhosphorIcons.trophy(PhosphorIconsStyle.fill),
       'arena'.tr(), 0),
      (PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
       PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
       'chat'.tr(), chatUnread),
      (PhosphorIcons.userCircle(PhosphorIconsStyle.regular),
       PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
       'profile'.tr(), 0),
    ];

    return Container(
      width: 80,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Logo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.amber, AppColors.amberDeep],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '♞',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    color: const Color(0xFF1a1205),
                    height: 1.0,
                  ),
                ),
              ),
            ),
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
                      color: selected ? AppColors.amberGlow : Colors.transparent,
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
                                  color: selected ? AppColors.amber : AppColors.inkMute,
                                  size: 22,
                                ),
                              )
                            : Icon(
                                selected ? iconFill : icon,
                                color: selected ? AppColors.amber : AppColors.inkMute,
                                size: 22,
                              ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? AppColors.amber : AppColors.inkMute,
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
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.username.isNotEmpty
        ? widget.username[0].toUpperCase()
        : '?';
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35],
          colors: [
            AppColors.amberGlow,
            AppColors.surface,
          ],
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
              builder: (_, child) => Transform.scale(
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
                          color: AppColors.amber.withOpacity(
                              _uploading ? 0.15 : 0.38),
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
                          style: GoogleFonts.fraunces(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0A0A0B),
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
                color: AppColors.amber.withOpacity(0.7),
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
                backgroundColor: AppColors.amber,
                foregroundColor: const Color(0xFF0A0A0B),
                disabledBackgroundColor: AppColors.amber.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _uploading
                    ? Text('uploading'.tr(),
                        key: const ValueKey('uploading'),
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: const Color(0xFF0A0A0B).withOpacity(0.7),
                        ))
                    : Text('upload_photo'.tr(),
                        key: const ValueKey('idle'),
                        style: AppTextStyles.buttonLarge
                            .copyWith(color: const Color(0xFF0A0A0B))),
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

  Widget _buildTabletLayout(BuildContext context, bool isOnline, double hp, WidgetRef ref, GameType activeGame) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column — greeting + ELO + play modes
        Expanded(
          flex: 5,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, hp, showLogo: false),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hp, 18, hp / 2, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const GameSwitch(),
                    const SizedBox(height: 16),
                    _buildGreeting(context),
                    const SizedBox(height: 20),
                    _HeroRatingCard(user: user, activeGame: activeGame)
                        .animate(delay: 80.ms)
                        .fadeIn(duration: 350.ms),
                    const SizedBox(height: 12),
                    if (activeGame == GameType.chess) _buildRatingPills(context),
                    const SizedBox(height: 24),
                    _buildPlaySection(context, isOnline, activeGame),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
        // Vertical divider
        Container(width: 1, color: AppColors.border),
        // Right column — recent games
        Expanded(
          flex: 4,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hp / 2, 24, hp, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'recent_games'.tr(),
                      style: GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ).animate(delay: 500.ms).fadeIn(),
                    const SizedBox(height: 14),
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

  Widget _buildPhoneLayout(BuildContext context, bool isOnline, double hp, WidgetRef ref, GameType activeGame) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, hp, showLogo: true),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hp),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 14),
              const GameSwitch(),
              const SizedBox(height: 16),
              _buildGreeting(context),
              const SizedBox(height: 20),
              _HeroRatingCard(user: user, activeGame: activeGame)
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.1),
              const SizedBox(height: 12),
              if (activeGame == GameType.chess) _buildRatingPills(context),
              const SizedBox(height: 24),
              _buildPlaySection(context, isOnline, activeGame),
              const SizedBox(height: 28),
              Text(
                'recent_games'.tr(),
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ).animate(delay: 500.ms).fadeIn(),
              const SizedBox(height: 12),
              _RecentGames(uid: user.uid),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Shared sub-widgets ────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context, double hp, {required bool showLogo}) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: hp - 16),
        child: Row(
          children: [
            if (showLogo) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.amber, AppColors.amberDeep],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '♞',
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      color: const Color(0xFF1a1205),
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
            const Spacer(),
            _NavButton(
              icon: PhosphorIcons.trophy(PhosphorIconsStyle.regular),
              onTap: () => context.push('/home/leaderboard'),
            ),
            const SizedBox(width: 8),
            _NavButton(
              icon: PhosphorIcons.mapTrifold(PhosphorIconsStyle.regular),
              onTap: () => context.push('/home/map'),
            ),
            const SizedBox(width: 8),
            _NavButton(
              icon: PhosphorIcons.gear(PhosphorIconsStyle.regular),
              onTap: () => context.push('/home/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final isTablet = context.isTablet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'welcome_back'.tr(),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMute,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.username,
          style: GoogleFonts.fraunces(
            fontSize: isTablet ? 38 : 34,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: AppColors.ink,
            letterSpacing: -1,
            height: 1.05,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
      ],
    );
  }

  Widget _buildRatingPills(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RatingPill(
            label: 'Bullet',
            icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
            color: const Color(0xFFF5A462),
            rating: user.bulletStats.rating,
            trend: 0,
            delay: 150,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RatingPill(
            label: 'Blitz',
            icon: PhosphorIcons.flame(PhosphorIconsStyle.fill),
            color: const Color(0xFF6FB4E0),
            rating: user.blitzStats.rating,
            trend: 0,
            delay: 200,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RatingPill(
            label: 'Rapid',
            icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
            color: AppColors.win,
            rating: user.rapidStats.rating,
            trend: 0,
            delay: 250,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaySection(BuildContext context, bool isOnline, GameType activeGame) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'play'.tr().toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMute,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        // ── Bot card (per-game accent) ──────────────────────────────────
        _PlayVsBotCard(
          delay: 300,
          gameType: activeGame,
          onTap: () => context.push(activeGame.botSetupRoute),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                title: 'matchmaking'.tr(),
                subtitle: isOnline ? 'ranked_online'.tr() : 'offline'.tr(),
                icon: PhosphorIcons.globe(PhosphorIconsStyle.regular),
                bgColor: activeGame == GameType.chess
                    ? const Color(0xFF1e2a26)
                    : activeGame == GameType.checkers
                        ? const Color(0xFF0a1620)
                        : const Color(0xFF0a1f16),
                delay: 360,
                disabled: !isOnline,
                onTap: () => context.push('/home/matchmaking'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeCard(
                title: 'friends'.tr(),
                subtitle: isOnline ? 'invite_or_local'.tr() : 'local_only'.tr(),
                icon: PhosphorIcons.users(PhosphorIconsStyle.regular),
                bgColor: activeGame == GameType.chess
                    ? const Color(0xFF2a211e)
                    : activeGame == GameType.checkers
                        ? const Color(0xFF102a3d)
                        : const Color(0xFF0f3329),
                delay: 410,
                onTap: () => _showFriendOptions(context, isOnline, activeGame),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SoloQuestCard(
          progress: switch (activeGame) {
            GameType.checkers => user.checkersCampaignProgress,
            GameType.domino   => user.dominoCampaignProgress,
            GameType.chess    => user.campaignProgress,
          },
          delay: 460,
          gameType: activeGame,
          onTap: () => context.push('/home/campaign'),
        ),
      ],
    );
  }

  void _showFriendOptions(BuildContext context, bool isOnline, GameType activeGame) {
    final accent = activeGame.identity.accent;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.borderStrong),
          boxShadow: const [
            BoxShadow(color: Color(0x800A0A0B), blurRadius: 50, offset: Offset(0, -20)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'play_with_friend'.tr(),
              style: GoogleFonts.fraunces(
                fontSize: 22, fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic, color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Two ways to start · no queue',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMute),
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
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIcons.usersFour(PhosphorIconsStyle.regular),
                          color: accent, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('same_device'.tr(),
                            style: GoogleFonts.fraunces(
                              fontSize: 16, fontWeight: FontWeight.w600,
                              color: AppColors.ink, letterSpacing: -0.2)),
                          const SizedBox(height: 2),
                          Text('same_device_subtitle'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.inkMute)),
                        ],
                      ),
                    ),
                    Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                        color: AppColors.inkMute, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Invite by Username option
            GestureDetector(
              onTap: isOnline
                  ? () {
                      Navigator.pop(ctx);
                      context.push('/home/invite');
                    }
                  : () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('no_internet'.tr())));
                    },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Icon(Icons.wifi_rounded,
                            color: accent, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('invite_by_username'.tr(),
                            style: GoogleFonts.fraunces(
                              fontSize: 16, fontWeight: FontWeight.w600,
                              color: AppColors.ink, letterSpacing: -0.2)),
                          const SizedBox(height: 2),
                          Text(
                            isOnline
                                ? 'invite_subtitle'.tr()
                                : 'requires_internet'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isOnline ? AppColors.inkMute : AppColors.error)),
                        ],
                      ),
                    ),
                    Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                        color: AppColors.inkMute, size: 16),
                  ],
                ),
              ),
            ),
            // 2v2 table with friends — domino only (classic partnership play)
            if (activeGame == GameType.domino) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: isOnline
                    ? () {
                        Navigator.pop(ctx);
                        context.push('/home/domino-table');
                      }
                    : () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('no_internet'.tr())));
                      },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Center(
                          child: Icon(
                              PhosphorIcons.usersFour(PhosphorIconsStyle.regular),
                              color: accent, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('2v2 Table',
                              style: GoogleFonts.fraunces(
                                fontSize: 16, fontWeight: FontWeight.w600,
                                color: AppColors.ink, letterSpacing: -0.2)),
                            const SizedBox(height: 2),
                            Text(
                              isOnline
                                  ? 'Invite friends · partners sit across'
                                  : 'requires_internet'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isOnline
                                    ? AppColors.inkMute
                                    : AppColors.error)),
                          ],
                        ),
                      ),
                      Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                          color: AppColors.inkMute, size: 16),
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
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Center(
          child: Icon(icon, color: AppColors.inkDim, size: 16),
        ),
      ),
    );
  }
}

// ── Hero Rating Card ──────────────────────────────────────────────────────────

class _HeroRatingCard extends ConsumerWidget {
  final UserModel user;
  final GameType activeGame;
  const _HeroRatingCard({required this.user, this.activeGame = GameType.chess});

  int get _overallRating => switch (activeGame) {
    GameType.checkers => user.checkersStats.rating,
    GameType.domino   => user.dominoStats.rating,
    GameType.chess    => ((user.bulletStats.rating + user.blitzStats.rating + user.rapidStats.rating) / 3).round(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankField = switch (activeGame) {
      GameType.checkers => 'checkersStats.rating',
      GameType.domino   => 'dominoStats.rating',
      GameType.chess    => 'blitzStats.rating',
    };
    final rankRating = _overallRating;
    final rankAsync    = ref.watch(_globalRankProvider('$rankField:$rankRating'));
    final changeAsync  = ref.watch(_monthlyRatingChangeProvider(user.uid));
    final identity = activeGame.identity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: activeGame == GameType.chess
                ? const [AppColors.cardElevated, AppColors.card]
                : [
                    Color.lerp(identity.gradientColors.first,
                        AppColors.cardElevated, 0.6)!,
                    AppColors.card,
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Game glyph watermark
            Positioned(
              right: -18,
              top: -18,
              bottom: -18,
              child: Opacity(
                opacity: 0.07,
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: activeGame == GameType.chess
                      ? const _MiniBoardWatermark()
                      : Center(
                          child: Text(
                            identity.glyph,
                            style: GoogleFonts.fraunces(
                              fontSize: 100,
                              color: identity.accent,
                              height: 1.0,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeGame.isPointBased
                    ? '${identity.name} ${'Points'.toUpperCase()}'
                    : '${identity.name} ${'overall_rating'.tr()}'.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMute,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatRating(_overallRating),
                    style: GoogleFonts.fraunces(
                      fontSize: 48,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                  ),
                  ...changeAsync.maybeWhen(
                    data: (change) {
                      if (change == null) return const <Widget>[];
                      final pos = change >= 0;
                      return <Widget>[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: pos ? AppColors.winSoft : AppColors.lossSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pos ? '+' : ''}$change',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pos ? AppColors.win : AppColors.loss,
                            ),
                          ),
                        ),
                      ];
                    },
                    orElse: () => const <Widget>[],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Builder(builder: (_) {
                    final (w, d, l) = switch (activeGame) {
                      GameType.checkers => (user.checkersStats.wins, user.checkersStats.draws, user.checkersStats.losses),
                      GameType.domino   => (user.dominoStats.wins, user.dominoStats.draws, user.dominoStats.losses),
                      GameType.chess    => (
                        user.bulletStats.wins + user.blitzStats.wins + user.rapidStats.wins,
                        user.bulletStats.draws + user.blitzStats.draws + user.rapidStats.draws,
                        user.bulletStats.losses + user.blitzStats.losses + user.rapidStats.losses,
                      ),
                    };
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatChip(label: '${w}W'),
                        const _Dot(),
                        _StatChip(label: '${d}D'),
                        const _Dot(),
                        _StatChip(label: '${l}L'),
                      ],
                    );
                  }),
                  const Spacer(),
                  rankAsync.when(
                    data: (rank) => Text(
                      rank > 0 ? '#${_formatRating(rank)} global' : '— global',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: identity.accent,
                      ),
                    ),
                    loading: () => Text(
                      '... global',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: identity.accent.withValues(alpha: 0.5),
                      ),
                    ),
                    error: (_, __) => Text(
                      '— global',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: identity.accent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  String _formatRating(int r) {
    if (r >= 1000) {
      final s = r.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return r.toString();
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.inkDim,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: GoogleFonts.inter(color: AppColors.inkMute, fontSize: 11)),
    );
  }
}

class _MiniBoardWatermark extends StatelessWidget {
  const _MiniBoardWatermark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MiniBoardPainter());
  }
}

class _MiniBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = AppColors.amberDeep;
    final lightPaint = Paint()..color = AppColors.amberSoft;
    final cellW = size.width / 8;
    final cellH = size.height / 8;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH),
          (row + col) % 2 == 1 ? darkPaint : lightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MiniBoardPainter old) => false;
}

// ── Rating Pill ───────────────────────────────────────────────────────────────

class _RatingPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int rating;
  final int trend;
  final int delay;

  const _RatingPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.rating,
    required this.trend,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rating.toString(),
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          if (trend != 0) ...[
            const SizedBox(height: 4),
            Text(
              '${trend > 0 ? '+' : ''}$trend',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: trend > 0 ? AppColors.win : AppColors.loss,
              ),
            ),
          ],
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15);
  }
}

// ── Play vs Bot (amber hero card) ─────────────────────────────────────────────

class _PlayVsBotCard extends StatefulWidget {
  final int delay;
  final VoidCallback onTap;
  final GameType gameType;
  const _PlayVsBotCard({required this.delay, required this.onTap, this.gameType = GameType.chess});

  @override
  State<_PlayVsBotCard> createState() => _PlayVsBotCardState();
}

class _PlayVsBotCardState extends State<_PlayVsBotCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Builder(builder: (context) {
          final identity = widget.gameType.identity;
          final accentDark = Color.lerp(identity.accent, Colors.black, 0.55)!;
          final subtitles = {
            GameType.chess: 'Stockfish · 6 difficulty tiers',
            GameType.checkers: 'Minimax AI · 6 difficulty tiers',
            GameType.domino: 'Smart Bot · Block Domino',
          };
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.centerRight,
                colors: [identity.accent, Color.lerp(identity.accent, Colors.black, 0.3)!],
                stops: const [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: identity.accentSoft,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background glyph
                Positioned(
                  right: 14,
                  bottom: -8,
                  child: Text(
                    identity.glyph,
                    style: GoogleFonts.fraunces(
                      fontSize: 56,
                      color: accentDark,
                      height: 0.8,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accentDark.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIcons.robot(PhosphorIconsStyle.regular),
                          color: accentDark,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'play_vs_bot'.tr(),
                            style: GoogleFonts.fraunces(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: accentDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitles[widget.gameType]!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: accentDark.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                      color: accentDark,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.delay))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15);
  }
}

// ── Mode Card (Matchmaking / Friends) ─────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final int delay;
  final VoidCallback onTap;
  final bool disabled;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.delay,
    required this.onTap,
    this.disabled = false,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      onTapCancel:
          widget.disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: widget.disabled ? 0.55 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.icon, color: AppColors.ink, size: 20),
                const SizedBox(height: 22),
                Text(
                  widget.title,
                  style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.inkDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.delay))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15);
  }
}

// ── Solo Quest / Campaign Card ─────────────────────────────────────────────────

class _SoloQuestCard extends StatefulWidget {
  final int progress;
  final int delay;
  final VoidCallback onTap;
  final GameType gameType;
  const _SoloQuestCard({
    required this.progress,
    required this.delay,
    required this.onTap,
    this.gameType = GameType.chess,
  });

  @override
  State<_SoloQuestCard> createState() => _SoloQuestCardState();
}

class _SoloQuestCardState extends State<_SoloQuestCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Center(
                  child: Icon(
                    PhosphorIcons.mapTrifold(PhosphorIconsStyle.regular),
                    color: AppColors.amber,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.gameType.identity.questTitle,
                          style: GoogleFonts.fraunces(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.progress}/${widget.gameType.identity.questChapters}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.gameType.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: widget.progress / widget.gameType.identity.questChapters,
                          backgroundColor: AppColors.surface,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(widget.gameType.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.delay))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15);
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
      loading: () => const ShimmerList(count: 3, itemHeight: 70),
      error: (_, __) => const SizedBox.shrink(),
      data: (games) {
        if (games.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.regular),
                  color: AppColors.inkMute,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No games yet. Start playing!',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.inkDim),
                ),
              ],
            ),
          );
        }
        return Column(
          children: games
              .map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: g.gameType == 'chess'
                          ? () => context.push(
                                '/home/game-replay/${g.id}',
                                extra: uid)
                          : null, // replay not yet available for checkers/domino
                      child: RecentGameTile(game: g, uid: uid),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

final _recentGamesProvider =
    FutureProvider.family<List<GameModel>, String>((ref, uid) {
  return ref.read(firestoreServiceProvider).getRecentGames(uid);
});

// ── Option Tile (Play with friend sheet) ──────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amberGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(icon, color: AppColors.amber, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.inkDim)),
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
    );
  }
}

// ── Google new-user username setup ────────────────────────────────────────────


class _GoogleUsernameSetup extends ConsumerStatefulWidget {
  final dynamic firebaseUser;
  const _GoogleUsernameSetup({required this.firebaseUser});

  @override
  ConsumerState<_GoogleUsernameSetup> createState() =>
      _GoogleUsernameSetupState();
}

class _GoogleUsernameSetupState extends ConsumerState<_GoogleUsernameSetup> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _countryCode;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _flagEmoji(String code) => UserModel.flagEmoji(code);

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              Text('choose_country'.tr(), style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  itemCount: kCountries.length,
                  itemBuilder: (_, i) {
                    final (code, name) = kCountries[i];
                    return ListTile(
                      leading: Text(_flagEmoji(code),
                          style: const TextStyle(fontSize: 22)),
                      title: Text(name, style: AppTextStyles.bodyMedium),
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
      await ref.read(authServiceProvider).completeGoogleSignUp(
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
          _error = e.toString().contains('already taken')
              ? 'Username already taken'
              : 'Something went wrong. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (countryFlag, countryName) = _countryCode != null
        ? (_flagEmoji(_countryCode!),
            kCountries
                .firstWhere((c) => c.$1 == _countryCode,
                    orElse: () => (_countryCode!, _countryCode!))
                .$2)
        : ('', '');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('♟',
                  style: GoogleFonts.fraunces(
                      fontSize: 48, color: AppColors.amber)),
              const SizedBox(height: 20),
              Text('choose_username'.tr(), style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Text(
                'choose_username_subtitle'.tr(),
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.inkDim),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'username'.tr(),
                  hintText: 'e.g. chess_master',
                  filled: true,
                  fillColor: AppColors.card,
                  errorText: _error,
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
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      if (_countryCode != null) ...[
                        Text(countryFlag,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text(countryName, style: AppTextStyles.bodyMedium),
                      ] else
                        Text('country_optional'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.inkMute)),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: AppColors.inkMute),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A0A0B)),
                        )
                      : Text('verify'.tr(),
                          style: AppTextStyles.buttonLarge
                              .copyWith(color: const Color(0xFF0A0A0B))),
                ),
              ),
            ],
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
          const ShimmerBox(width: double.infinity, height: 110, borderRadius: 18),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 14)),
              const SizedBox(width: 8),
              Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 14)),
              const SizedBox(width: 8),
              Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 28),
          const ShimmerBox(width: 60, height: 12, borderRadius: 4),
          const SizedBox(height: 10),
          const ShimmerBox(width: double.infinity, height: 72, borderRadius: 16),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 100, borderRadius: 14)),
              const SizedBox(width: 10),
              Expanded(child: ShimmerBox(width: double.infinity, height: 100, borderRadius: 14)),
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
                  fontWeight: FontWeight.w700),
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
  return ref.read(chatServiceProvider).watchTotalUnread(uid);
});

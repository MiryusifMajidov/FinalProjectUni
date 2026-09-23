import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/friends_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/services/realtime_game_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/friend_request_model.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../game/widgets/recent_game_tile.dart';
import '../../game/widgets/time_control_selector.dart';
import '../../../core/models/game_type.dart';
import '../../../core/widgets/game_switch.dart';


// StreamProvider — Firestore real-time stream, auto-updates when photoUrl changes
final _profileProvider =
    StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.read(firestoreServiceProvider).watchUser(uid);
});

final _profileGamesProvider =
    FutureProvider.family<List<GameModel>, String>((ref, uid) async {
  // Fetch up to 100 games so the per-game rating charts keep a meaningful
  // history even when the list mixes chess + checkers + domino records.
  return ref.read(firestoreServiceProvider).getRecentGames(uid, limit: 100);
});

final _friendsStreamProvider =
    StreamProvider.autoDispose.family<List<FriendModel>, String>((ref, uid) {
  return ref.read(friendsServiceProvider).watchFriends(uid);
});

final _pendingRequestsProvider =
    StreamProvider.autoDispose.family<List<FriendRequestModel>, String>(
        (ref, uid) {
  return ref.read(friendsServiceProvider).watchIncomingRequests(uid);
});

final _isFriendProvider =
    FutureProvider.autoDispose.family<bool, ({String myUid, String otherUid})>(
        (ref, ids) {
  return ref.read(friendsServiceProvider).areFriends(ids.myUid, ids.otherUid);
});

// ── Font helpers ───────────────────────────────────────────────────────────────

TextStyle _fraunces({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double letterSpacing = 0,
  bool italic = true,
}) =>
    GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color,
      letterSpacing: letterSpacing,
    );

TextStyle _inter({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double letterSpacing = 0,
}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

// ── Report reasons: stored value → translation key ─────────────────────────────
const Map<String, String> _kReportReasons = {
  'spam': 'report_reason_spam',
  'harassment': 'report_reason_harassment',
  'inappropriate': 'report_reason_inappropriate',
  'cheating': 'report_reason_cheating',
  'other': 'report_reason_other',
};

TextStyle _mono({
  double size = 11,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.inkDim,
  double letterSpacing = 0,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

// ── Screen ─────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_profileProvider(uid));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isOwnProfile = currentUid == uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        loading: () => const _ProfileShimmer(),
        error: (e, _) => Center(
          child: Text('Error: $e', style: AppTextStyles.bodyMedium),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          if (!isOwnProfile) {
            final myUser = ref.watch(currentUserProvider).valueOrNull;
            // Mutual block check: either side blocking the other → locked view
            final iBlockedThem =
                myUser?.blockedUsers.contains(user.uid) ?? false;
            final theyBlockedMe =
                user.blockedUsers.contains(currentUid ?? '');
            if (iBlockedThem || theyBlockedMe) {
              return _PrivateProfileView(user: user);
            }
            // Private profile
            if (user.profileVisibility == 'Private') {
              return _PrivateProfileView(user: user);
            }
          }
          return _ProfileContent(
            user: user,
            isOwnProfile: isOwnProfile,
            myUid: currentUid ?? '',
          );
        },
      ),
    );
  }
}

// ── Profile Content ────────────────────────────────────────────────────────────

class _ProfileContent extends ConsumerWidget {
  final UserModel user;
  final bool isOwnProfile;
  final String myUid;

  const _ProfileContent({
    required this.user,
    required this.isOwnProfile,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(_profileGamesProvider(user.uid));

    if (isOwnProfile) {
      return _OwnProfileLayout(user: user, myUid: myUid, gamesAsync: gamesAsync);
    }

    // Friends-only profile: check friendship before showing full content
    if (user.profileVisibility == 'Friends' && myUid.isNotEmpty) {
      final isFriendAsync = ref.watch(
          _isFriendProvider((myUid: myUid, otherUid: user.uid)));
      return isFriendAsync.when(
        loading: () => const _ProfileShimmer(),
        error: (_, __) =>
            _OtherProfileLayout(user: user, myUid: myUid, gamesAsync: gamesAsync),
        data: (isFriend) {
          if (!isFriend) return _PrivateProfileView(user: user);
          return _OtherProfileLayout(user: user, myUid: myUid, gamesAsync: gamesAsync);
        },
      );
    }

    return _OtherProfileLayout(user: user, myUid: myUid, gamesAsync: gamesAsync);
  }
}

// ── Own Profile ────────────────────────────────────────────────────────────────

class _OwnProfileLayout extends ConsumerStatefulWidget {
  final UserModel user;
  final String myUid;
  final AsyncValue<List<GameModel>> gamesAsync;

  const _OwnProfileLayout({
    required this.user,
    required this.myUid,
    required this.gamesAsync,
  });

  @override
  ConsumerState<_OwnProfileLayout> createState() => _OwnProfileLayoutState();
}

class _OwnProfileLayoutState extends ConsumerState<_OwnProfileLayout> {
  bool _isPhotoLoading = false;

  Future<void> _showPhotoOptions() async {
    final hasPhoto = (widget.user.photoUrl ?? '').isNotEmpty;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(PhosphorIcons.camera(PhosphorIconsStyle.regular),
                  color: AppColors.ink),
              title: Text('Take photo',
                  style: _inter(size: 14, weight: FontWeight.w500, color: AppColors.ink)),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIcons.image(PhosphorIconsStyle.regular),
                  color: AppColors.ink),
              title: Text('Choose from gallery',
                  style: _inter(size: 14, weight: FontWeight.w500, color: AppColors.ink)),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickPhoto(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(PhosphorIcons.trash(PhosphorIconsStyle.regular),
                    color: AppColors.error),
                title: Text('Remove photo',
                    style:
                        _inter(size: 14, weight: FontWeight.w500, color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deletePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isPhotoLoading) return;
    setState(() => _isPhotoLoading = true);
    try {
      await ref.read(photoServiceProvider).pickAndUpload(
        widget.myUid,
        source: source,
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: AppColors.error),
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isPhotoLoading = false);
    }
  }

  Future<void> _deletePhoto() async {
    if (_isPhotoLoading) return;
    setState(() => _isPhotoLoading = true);
    try {
      await ref.read(photoServiceProvider).deletePhoto(widget.myUid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove photo. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPhotoLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final myUid = widget.myUid;
    final gamesAsync = widget.gamesAsync;
    final isLargeTablet = context.isLargeTablet;
    final hp = context.hPadding;
    final activeGame = ref.watch(activeGameProvider);

    final (totalWins, totalDraws, totalLosses) = switch (activeGame) {
      GameType.checkers => (user.checkersStats.wins, user.checkersStats.draws, user.checkersStats.losses),
      GameType.domino   => (user.dominoStats.wins, user.dominoStats.draws, user.dominoStats.losses),
      GameType.chess    => (
        user.bulletStats.wins + user.blitzStats.wins + user.rapidStats.wins,
        user.bulletStats.draws + user.blitzStats.draws + user.rapidStats.draws,
        user.bulletStats.losses + user.blitzStats.losses + user.rapidStats.losses,
      ),
    };

    final flag     = UserModel.flagEmoji(user.countryCode);
    final joinDate = DateFormat('MMM yyyy').format(user.createdAt);
    final skill    = user.skillLevel ?? 'Player';

    // ── Local sub-widget builders (close over build-scope vars) ───────────────

    Widget avatarSection() => Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isPhotoLoading ? null : _showPhotoOptions,
            child: Stack(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.amber, AppColors.amberDeep],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: _isPhotoLoading
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF1A1205),
                          ),
                        )
                      : (user.photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CachedNetworkImage(
                                imageUrl: user.photoUrl!, width: 84, height: 84, fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : '?',
                              style: _fraunces(
                                  size: 40,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF1A1205)),
                            )),
                ),
                // Camera badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2.5),
                    ),
                    child: Icon(
                      PhosphorIcons.camera(PhosphorIconsStyle.fill),
                      size: 13,
                      color: const Color(0xFF1A1205),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(user.username,
              style: _fraunces(size: 26, weight: FontWeight.w500, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(
              [
                if (user.countryCode != null && user.countryCode!.isNotEmpty)
                  '$flag ${user.countryCode}',
                skill,
                joinDate,
              ].where((s) => s.isNotEmpty).join(' · '),
              style: _inter(size: 11, color: AppColors.inkMute)),
        ],
      ),
    ).animate().scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.easeOut);

    Widget graphCard() => _RatingGraphCard(
      overallRating: switch (activeGame) {
        GameType.checkers => user.checkersStats.rating,
        GameType.domino   => user.dominoStats.rating,
        GameType.chess    => user.overallRating,
      },
      uid: myUid,
      games: gamesAsync.valueOrNull ?? const [],
      activeGame: activeGame,
    ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.06);

    Widget statPills() {
      if (activeGame == GameType.chess) {
        return Row(
          children: [
            Expanded(child: _StatPillCard(
              label: 'BULLET', rating: user.bulletStats.rating,
              ratingColor: const Color(0xFFF5A462),
              subStats: '${user.bulletStats.wins}W ${user.bulletStats.draws}D ${user.bulletStats.losses}L',
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatPillCard(
              label: 'BLITZ', rating: user.blitzStats.rating,
              ratingColor: const Color(0xFF6FB4E0),
              subStats: '${user.blitzStats.wins}W ${user.blitzStats.draws}D ${user.blitzStats.losses}L',
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatPillCard(
              label: 'RAPID', rating: user.rapidStats.rating,
              ratingColor: AppColors.win,
              subStats: '${user.rapidStats.wins}W ${user.rapidStats.draws}D ${user.rapidStats.losses}L',
            )),
          ],
        ).animate(delay: 120.ms).fadeIn();
      }
      final stats = activeGame == GameType.checkers ? user.checkersStats : user.dominoStats;
      return Row(
        children: [
          Expanded(child: _StatPillCard(
            label: activeGame.identity.name.toUpperCase(),
            rating: stats.rating,
            ratingColor: activeGame.accent,
            subStats: '${stats.wins}W ${stats.draws}D ${stats.losses}L',
          )),
        ],
      ).animate(delay: 120.ms).fadeIn();
    }

    Widget donutCard() => _GamesDonutCard(
      wins: totalWins, draws: totalDraws, losses: totalLosses,
    ).animate(delay: 160.ms).fadeIn();

    Widget friendsSection() => _FriendsSection(
      uid: user.uid, isOwnProfile: true, myUid: myUid,
    ).animate(delay: 200.ms).fadeIn();

    Widget recentGamesLabel() => Text(
      'recent_games'.tr(),
      style: _inter(size: 11, weight: FontWeight.w600, color: AppColors.inkMute, letterSpacing: 0.8),
    ).animate(delay: 240.ms).fadeIn();

    Widget recentGames() => gamesAsync.when(
      loading: () => const ShimmerList(count: 4, itemHeight: 70),
      error: (_, __) => const SizedBox.shrink(),
      data: (games) => Column(
        children: games.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            // Move-by-move replay/analysis exists for chess only —
            // checkers/domino entries are informational.
            onTap: g.gameType == 'chess'
                ? () => context.push('/home/game-replay/${g.id}', extra: myUid)
                : null,
            child: RecentGameTile(game: g, uid: user.uid),
          ),
        )).toList(),
      ),
    ).animate(delay: 260.ms).fadeIn();

    // ── Build ─────────────────────────────────────────────────────────────────

    return CustomScrollView(
      slivers: [
        // ── AppBar ──
        SliverAppBar(
          backgroundColor: AppColors.background,
          automaticallyImplyLeading: false,
          pinned: true,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.regular), color: AppColors.inkDim),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text('Profile',
              style: _inter(size: 13, weight: FontWeight.w600, color: AppColors.inkDim)),
          actions: [
            IconButton(
              icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.regular),
                  color: AppColors.inkDim, size: 20),
              onPressed: () => context.push('/home/settings'),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Amber glow decoration ──
              Positioned(
                top: -100, left: -60,
                child: IgnorePointer(
                  child: Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.amber.withOpacity(0.18), Colors.transparent],
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(hp, 8, hp, 32),
                child: isLargeTablet
                    // ── Large tablet: 2-column ──────────────────────────────
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: avatar + stats + graph + donut + friends
                          Expanded(
                            flex: 55,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                avatarSection(),
                                const SizedBox(height: 20),
                                graphCard(),
                                const SizedBox(height: 12),
                                statPills(),
                                const SizedBox(height: 12),
                                donutCard(),
                                const SizedBox(height: 12),
                                friendsSection(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right: recent games
                          Expanded(
                            flex: 45,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                recentGamesLabel(),
                                const SizedBox(height: 10),
                                recentGames(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ],
                      )
                    // ── Phone / regular tablet: single column ───────────────
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const GameSwitch(),
                          const SizedBox(height: 16),
                          avatarSection(),
                          const SizedBox(height: 20),
                          graphCard(),
                          const SizedBox(height: 12),
                          statPills(),
                          const SizedBox(height: 12),
                          donutCard(),
                          const SizedBox(height: 12),
                          friendsSection(),
                          const SizedBox(height: 20),
                          recentGamesLabel(),
                          const SizedBox(height: 10),
                          recentGames(),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Other Profile ──────────────────────────────────────────────────────────────

// ── Private profile locked view ────────────────────────────────────────────────

class _PrivateProfileView extends StatelessWidget {
  final UserModel user;
  const _PrivateProfileView({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: AppColors.inkDim),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Text(
                    user.username,
                    style: _fraunces(size: 18, weight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Lock icon + message
            Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.regular),
                color: AppColors.inkMute, size: 48),
            const SizedBox(height: 16),
            Text(
              'Private profile',
              style: _fraunces(size: 20, weight: FontWeight.w600,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'This account is private.',
              style: _inter(size: 13, color: AppColors.inkMute),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _OtherProfileLayout extends ConsumerWidget {
  final UserModel user;
  final String myUid;
  final AsyncValue<List<GameModel>> gamesAsync;

  const _OtherProfileLayout({
    required this.user,
    required this.myUid,
    required this.gamesAsync,
  });

  void _showBlockSheet(BuildContext context, WidgetRef ref) {
    final me = ref.read(currentUserProvider).valueOrNull;
    final isBlocked = me?.blockedUsers.contains(user.uid) ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.inkMute,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                  PhosphorIcons.prohibit(PhosphorIconsStyle.regular),
                  color: AppColors.error),
              title: Text(
                isBlocked ? 'Unblock ${user.username}' : 'Block ${user.username}',
                style: _inter(size: 14, weight: FontWeight.w500,
                    color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (myUid.isEmpty) return;
                final fs = ref.read(firestoreServiceProvider);
                if (isBlocked) {
                  await fs.unblockUser(myUid, user.uid);
                } else {
                  await fs.blockUser(myUid, user.uid);
                  // Also remove friendship when blocking
                  try {
                    await ref.read(friendsServiceProvider)
                        .removeFriend(myUid, user.uid);
                  } catch (_) {}
                }
                ref.invalidate(currentUserProvider);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIcons.flag(PhosphorIconsStyle.regular),
                  color: AppColors.amber),
              title: Text(
                'report_user'.tr(),
                style: _inter(size: 14, weight: FontWeight.w500,
                    color: AppColors.ink),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showReportSheet(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.inkMute,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('report_sheet_title'.tr(),
                      style: _inter(size: 15, weight: FontWeight.w600,
                          color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Text('report_sheet_subtitle'.tr(),
                      style: _inter(size: 12, color: AppColors.inkMute)),
                ],
              ),
            ),
            for (final entry in _kReportReasons.entries)
              ListTile(
                title: Text(entry.value.tr(),
                    style: _inter(size: 14, color: AppColors.ink)),
                onTap: () {
                  Navigator.pop(ctx);
                  _submitReport(context, ref, entry.key);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(
      BuildContext context, WidgetRef ref, String reason) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    final isBlocked = me?.blockedUsers.contains(user.uid) ?? false;
    try {
      await ref.read(firestoreServiceProvider).reportUser(
            reportedUid: user.uid,
            reason: reason,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('report_submitted'.tr()),
        duration: const Duration(seconds: 5),
        action: isBlocked
            ? null
            : SnackBarAction(
                label: 'block_user'.tr(),
                textColor: AppColors.amber,
                onPressed: () => _blockAfterReport(context, ref),
              ),
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('report_failed'.tr())),
      );
    }
  }

  Future<void> _blockAfterReport(BuildContext context, WidgetRef ref) async {
    // The snackbar can outlive the route — bail out if it already went away.
    if (myUid.isEmpty || !context.mounted) return;
    await ref.read(firestoreServiceProvider).blockUser(myUid, user.uid);
    try {
      await ref.read(friendsServiceProvider).removeFriend(myUid, user.uid);
    } catch (_) {}
    ref.invalidate(currentUserProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLargeTablet = context.isLargeTablet;
    final hp = context.hPadding;

    // Username masking: if they blocked me, show "Chess User"
    final displayName = user.blockedUsers.contains(myUid) ? 'Chess User' : user.username;

    // ── Local sub-widget builders ─────────────────────────────────────────────

    Widget avatarSection() => Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 84, height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.amber, AppColors.amberDeep],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: user.photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(imageUrl: user.photoUrl!, width: 84, height: 84, fit: BoxFit.cover),
                      )
                    : Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: _fraunces(size: 40, weight: FontWeight.w600, color: const Color(0xFF1A1205)),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(displayName,
              style: _fraunces(size: 22, weight: FontWeight.w500, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('${UserModel.flagEmoji(user.countryCode)} · ${user.skillLevel ?? 'Player'}',
              style: _inter(size: 11, color: AppColors.inkMute)),
        ],
      ),
    ).animate().scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.easeOut);

    final activeGame = ref.watch(activeGameProvider);

    final otherOverallRating = switch (activeGame) {
      GameType.checkers => user.checkersStats.rating,
      GameType.domino   => user.dominoStats.rating,
      GameType.chess    => ((user.bulletStats.rating + user.blitzStats.rating + user.rapidStats.rating) / 3).round(),
    };

    Widget ratingCard() =>
        _OverallRatingCard(rating: otherOverallRating).animate(delay: 80.ms).fadeIn().slideY(begin: 0.06);

    Widget statPills() {
      if (activeGame == GameType.chess) {
        return Row(
          children: [
            Expanded(child: _StatPillCard(
              label: 'BULLET', rating: user.bulletStats.rating,
              ratingColor: const Color(0xFFF5A462),
              subStats: '${user.bulletStats.wins}W ${user.bulletStats.draws}D ${user.bulletStats.losses}L',
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatPillCard(
              label: 'BLITZ', rating: user.blitzStats.rating,
              ratingColor: const Color(0xFF6FB4E0),
              subStats: '${user.blitzStats.wins}W ${user.blitzStats.draws}D ${user.blitzStats.losses}L',
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatPillCard(
              label: 'RAPID', rating: user.rapidStats.rating,
              ratingColor: AppColors.win,
              subStats: '${user.rapidStats.wins}W ${user.rapidStats.draws}D ${user.rapidStats.losses}L',
            )),
          ],
        ).animate(delay: 120.ms).fadeIn();
      }

      // Checkers / Domino → single stat pill
      final stats = activeGame == GameType.checkers ? user.checkersStats : user.dominoStats;
      return Row(
        children: [
          Expanded(child: _StatPillCard(
            label: activeGame.identity.name.toUpperCase(),
            rating: stats.rating,
            ratingColor: activeGame.accent,
            subStats: '${stats.wins}W ${stats.draws}D ${stats.losses}L',
          )),
        ],
      ).animate(delay: 120.ms).fadeIn();
    }

    Widget actionButtons() =>
        _OtherProfileActions(user: user, myUid: myUid).animate(delay: 160.ms).fadeIn();

    Widget friendsSection() => _FriendsSection(
      uid: user.uid, isOwnProfile: false, myUid: myUid,
    ).animate(delay: 200.ms).fadeIn();

    Widget recentGamesLabel() => Text(
      'recent_games'.tr(),
      style: _inter(size: 11, weight: FontWeight.w600, color: AppColors.inkMute, letterSpacing: 0.8),
    ).animate(delay: 240.ms).fadeIn();

    Widget recentGames() => gamesAsync.when(
      loading: () => const ShimmerList(count: 4, itemHeight: 70),
      error: (_, __) => const SizedBox.shrink(),
      data: (games) => Column(
        children: games.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RecentGameTile(game: g, uid: user.uid),
        )).toList(),
      ),
    ).animate(delay: 260.ms).fadeIn();

    // ── Build ─────────────────────────────────────────────────────────────────

    return CustomScrollView(
      slivers: [
        // ── AppBar ──
        SliverAppBar(
          backgroundColor: AppColors.background,
          pinned: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.regular), color: AppColors.inkDim),
            onPressed: () => context.pop(),
          ),
          title: Text(displayName,
              style: _fraunces(size: 18, weight: FontWeight.w600, color: AppColors.ink)),
          actions: [
            IconButton(
              icon: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
                  color: AppColors.inkMute, size: 20),
              onPressed: () => _showBlockSheet(context, ref),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hp, 8, hp, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live banner (always full-width above the columns)
                if (user.currentGameId != null) ...[
                  _WatchLiveBanner(
                    gameId: user.currentGameId!,
                    watchedUid: user.uid,
                  ).animate().fadeIn(),
                  const SizedBox(height: 14),
                ],

                // ── Layout: 2-col on large tablet, single-col otherwise ──
                isLargeTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: avatar + rating + stats + actions + friends
                          Expanded(
                            flex: 55,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                avatarSection(),
                                const SizedBox(height: 18),
                                ratingCard(),
                                const SizedBox(height: 12),
                                statPills(),
                                const SizedBox(height: 12),
                                actionButtons(),
                                const SizedBox(height: 12),
                                friendsSection(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right: recent games
                          Expanded(
                            flex: 45,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                recentGamesLabel(),
                                const SizedBox(height: 10),
                                recentGames(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          avatarSection(),
                          const SizedBox(height: 18),
                          ratingCard(),
                          const SizedBox(height: 12),
                          statPills(),
                          const SizedBox(height: 12),
                          actionButtons(),
                          const SizedBox(height: 12),
                          friendsSection(),
                          const SizedBox(height: 20),
                          recentGamesLabel(),
                          const SizedBox(height: 10),
                          recentGames(),
                          const SizedBox(height: 32),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Overall Rating Card (other profile) ───────────────────────────────────────

class _OverallRatingCard extends StatelessWidget {
  final int rating;
  const _OverallRatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 1.0],
          colors: [AppColors.amberDeep, Color(0xFF5A3A15)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Queen watermark
          Positioned(
            right: -8,
            top: -12,
            child: Text(
              '♛',
              style: TextStyle(
                fontSize: 72,
                color: Colors.white.withOpacity(0.22),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OVERALL RATING',
                style: _mono(
                  size: 10,
                  weight: FontWeight.w500,
                  color: const Color(0xFF1A1205).withOpacity(0.7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$rating',
                style: _fraunces(
                  size: 44,
                  weight: FontWeight.w700,
                  color: const Color(0xFF1A1205),
                  letterSpacing: -1.5,
                ),
              ),
              Text(
                'Top player globally',
                style: _inter(
                  size: 11,
                  color: const Color(0xFF1A1205).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Rating Graph Card ──────────────────────────────────────────────────────────

class _RatingGraphCard extends StatelessWidget {
  final int overallRating;
  final String uid;
  final List<GameModel> games;
  final GameType activeGame;

  const _RatingGraphCard({
    required this.overallRating,
    required this.uid,
    required this.games,
    this.activeGame = GameType.chess,
  });

  /// Builds chronological rating snapshots from real game data.
  ///
  /// Supports two storage layouts:
  ///   • New games — `whiteRatingBefore` stored → exact values used.
  ///   • Legacy games — only `whiteRatingChange` stored → history is
  ///     reconstructed by working backwards from the user's current
  ///     overall rating so the shape of the curve is always accurate.
  ///
  /// Returns (points: rating values, dates: matching timestamps).
  ({List<int> points, List<DateTime> dates}) _buildHistory() {
    final rated = games
        .where((g) =>
            g.mode == GameMode.online &&
            // Only the ACTIVE game feeds the curve — chess ELO and
            // checkers/domino points are separate scales and must never mix.
            g.gameType == activeGame.name &&
            (g.whiteUid == uid || g.blackUid == uid) &&
            g.result != GameResult.ongoing &&
            g.result != GameResult.aborted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (rated.isEmpty) return (points: [], dates: []);

    final points = <int>[];
    final dates  = <DateTime>[];

    for (final g in rated) {
      final isWhite = g.whiteUid == uid;
      final before  = isWhite ? g.whiteRatingBefore : g.blackRatingBefore;
      final change  = isWhite ? g.whiteRatingChange  : g.blackRatingChange;
      // Treat null ratingChange as 0 so games without stored ELO still appear
      final effectiveChange = change ?? 0;

      // Prefer stored 'before' rating; otherwise carry last known point forward
      // or approximate from the current overall rating for the very first game.
      final ratingBefore = before ??
          (points.isNotEmpty ? points.last : overallRating - effectiveChange);

      if (points.isEmpty) {
        // Seed the chart with the rating before the first qualifying game
        points.add(ratingBefore);
        dates.add(g.createdAt);
      }

      points.add(ratingBefore + effectiveChange);
      dates.add(g.endedAt ?? g.createdAt);
    }

    return (points: points, dates: dates);
  }

  @override
  Widget build(BuildContext context) {
    final history  = _buildHistory();
    final data     = history.points;
    final dates    = history.dates;
    final hasData  = data.length >= 2;

    final change   = hasData ? data.last - data.first : 0;
    final peak     = hasData ? data.reduce(math.max) : overallRating;
    final positive = change >= 0;
    final gameCount = data.isEmpty ? 0 : data.length - 1;

    final startLabel = dates.isNotEmpty
        ? DateFormat('MMM d').format(dates.first)
        : '';

    final isPoints = activeGame.isPointBased;
    final scoreWord = activeGame.scoreLabel.toUpperCase();
    final accent = activeGame.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: label + big rating
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasData
                        ? '${activeGame.identity.name.toUpperCase()} · $gameCount GAMES'
                        : '${activeGame.identity.name.toUpperCase()} $scoreWord',
                    style: _mono(
                      size: 10,
                      color: AppColors.inkMute,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$overallRating',
                    style: _fraunces(
                      size: 40,
                      weight: FontWeight.w500,
                      color: AppColors.ink,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Right: change badge + peak (always visible; '—' when no data)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasData
                          ? (positive ? AppColors.winSoft : AppColors.lossSoft)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                      border: hasData
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      hasData ? '${positive ? '+' : ''}$change' : '—',
                      style: _mono(
                        size: 12,
                        weight: FontWeight.w600,
                        color: hasData
                            ? (positive ? AppColors.win : AppColors.loss)
                            : AppColors.inkMute,
                      ),
                    ),
                  ),
                  if (hasData) ...[
                    const SizedBox(height: 6),
                    Text(
                      'peak $peak',
                      style: _mono(size: 9, color: AppColors.inkMute),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            width: double.infinity,
            child: _RatingGraph(
              data: hasData ? data : [overallRating, overallRating],
              isPlaceholder: !hasData,
              accent: accent,
            ),
          ),
          if (hasData) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(startLabel,
                    style: _mono(size: 9, color: AppColors.inkMute)),
                Text('TODAY',
                    style: _mono(size: 9, color: AppColors.inkMute)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Rating Graph (CustomPainter) ───────────────────────────────────────────────

class _RatingGraph extends StatelessWidget {
  final List<int> data;
  final bool isPlaceholder;
  final Color accent;
  const _RatingGraph({required this.data, this.isPlaceholder = false, this.accent = AppColors.amber});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RatingGraphPainter(data: data, isPlaceholder: isPlaceholder, accent: accent),
      size: Size.infinite,
    );
  }
}

class _RatingGraphPainter extends CustomPainter {
  final List<int> data;
  final bool isPlaceholder;
  final Color accent;
  _RatingGraphPainter({required this.data, this.isPlaceholder = false, this.accent = AppColors.amber});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final padding = 4.0;
    final w = size.width;
    final h = size.height;

    // No real data → draw a subtle dashed line at vertical centre
    if (isPlaceholder) {
      final centerY = h / 2;
      final dashPaint = Paint()
        ..color = accent.withOpacity(0.25)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      const dashW = 6.0;
      const gapW  = 4.0;
      var x = padding;
      while (x < w - padding) {
        canvas.drawLine(
          Offset(x, centerY),
          Offset(math.min(x + dashW, w - padding), centerY),
          dashPaint,
        );
        x += dashW + gapW;
      }
      return;
    }

    final minVal = data.reduce(math.min).toDouble();
    final maxVal = data.reduce(math.max).toDouble();
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    double xAt(int i) => padding + (i / (data.length - 1)) * (w - padding * 2);
    double yAt(int v) => h - padding - ((v - minVal) / range) * (h - padding * 2);

    final path = Path();
    path.moveTo(xAt(0), yAt(data[0]));
    for (int i = 1; i < data.length; i++) {
      final x0 = xAt(i - 1), y0 = yAt(data[i - 1]);
      final x1 = xAt(i), y1 = yAt(data[i]);
      final cx = (x0 + x1) / 2;
      path.cubicTo(cx, y0, cx, y1, x1, y1);
    }

    // Fill area
    final fillPath = Path.from(path);
    fillPath.lineTo(xAt(data.length - 1), h);
    fillPath.lineTo(xAt(0), h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withOpacity(0.35),
          accent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Last point dot
    final lx = xAt(data.length - 1);
    final ly = yAt(data.last);
    canvas.drawCircle(
      Offset(lx, ly),
      3.5,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      Offset(lx, ly),
      3.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RatingGraphPainter old) =>
      old.data != data || old.isPlaceholder != isPlaceholder || old.accent != accent;
}

// ── Stat Pill Card ─────────────────────────────────────────────────────────────

class _StatPillCard extends StatelessWidget {
  final String label;
  final int rating;
  final Color ratingColor;
  final String subStats;

  const _StatPillCard({
    required this.label,
    required this.rating,
    required this.ratingColor,
    required this.subStats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _mono(size: 9, color: AppColors.inkMute),
          ),
          const SizedBox(height: 4),
          Text(
            '$rating',
            style: _fraunces(size: 22, weight: FontWeight.w600, color: ratingColor),
          ),
          const SizedBox(height: 2),
          Text(
            subStats,
            style: _mono(size: 10, color: AppColors.inkDim),
          ),
        ],
      ),
    );
  }
}

// ── Games Donut Card ───────────────────────────────────────────────────────────

class _GamesDonutCard extends StatelessWidget {
  final int wins;
  final int draws;
  final int losses;

  const _GamesDonutCard({
    required this.wins,
    required this.draws,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    final total = wins + draws + losses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _WinLossDonut(wins: wins, draws: draws, losses: losses),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DonutLegendRow(
                  color: AppColors.win,
                  label: 'Wins',
                  count: wins,
                ),
                const SizedBox(height: 8),
                _DonutLegendRow(
                  color: AppColors.draw,
                  label: 'Draws',
                  count: draws,
                ),
                const SizedBox(height: 8),
                _DonutLegendRow(
                  color: AppColors.loss,
                  label: 'Losses',
                  count: losses,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _DonutLegendRow({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: _inter(size: 12, color: AppColors.inkDim)),
        ),
        Text(
          '$count',
          style: _mono(size: 12, weight: FontWeight.w600, color: AppColors.ink),
        ),
      ],
    );
  }
}

// ── Win/Loss Donut (CustomPainter) ─────────────────────────────────────────────

class _WinLossDonut extends StatelessWidget {
  final int wins;
  final int draws;
  final int losses;

  const _WinLossDonut({
    required this.wins,
    required this.draws,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _WinLossDonutPainter(wins: wins, draws: draws, losses: losses),
      ),
    );
  }
}

class _WinLossDonutPainter extends CustomPainter {
  final int wins;
  final int draws;
  final int losses;

  _WinLossDonutPainter({
    required this.wins,
    required this.draws,
    required this.losses,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = wins + draws + losses;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 5;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (total > 0) {
      // Win arc
      if (wins > 0) {
        canvas.drawArc(
          rect,
          startAngle,
          (wins / total) * 2 * math.pi,
          false,
          Paint()
            ..color = AppColors.win
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.butt,
        );
      }

      // Loss arc
      if (losses > 0) {
        canvas.drawArc(
          rect,
          startAngle + (wins / total) * 2 * math.pi,
          (losses / total) * 2 * math.pi,
          false,
          Paint()
            ..color = AppColors.loss
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.butt,
        );
      }
    }

    // Center total count text
    final countTP = TextPainter(
      text: TextSpan(
        text: '$total',
        style: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    countTP.paint(
      canvas,
      center - Offset(countTP.width / 2, countTP.height / 2 + 6),
    );

    // "GAMES" label
    final gamesTP = TextPainter(
      text: TextSpan(
        text: 'GAMES',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 7,
          color: AppColors.inkMute,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    gamesTP.paint(
      canvas,
      center + Offset(-gamesTP.width / 2, countTP.height / 2 - 4),
    );
  }

  @override
  bool shouldRepaint(_WinLossDonutPainter old) =>
      old.wins != wins || old.draws != draws || old.losses != losses;
}

// ── Friends section ────────────────────────────────────────────────────────────

class _FriendsSection extends ConsumerWidget {
  final String uid;
  final bool isOwnProfile;
  final String myUid;

  const _FriendsSection({
    required this.uid,
    required this.isOwnProfile,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(_friendsStreamProvider(uid));
    final pendingAsync = isOwnProfile
        ? ref.watch(_pendingRequestsProvider(uid))
        : null;

    final friends = friendsAsync.valueOrNull ?? [];
    final pendingCount = pendingAsync?.valueOrNull?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              GestureDetector(
                onTap: isOwnProfile ? () => context.push('/home/friends') : null,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(PhosphorIcons.users(PhosphorIconsStyle.fill),
                        color: AppColors.amber, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'friends'.tr(),
                      style: _inter(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amberGlow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${friends.length}',
                        style: _mono(size: 10, weight: FontWeight.w600, color: AppColors.amber),
                      ),
                    ),
                    if (isOwnProfile) ...[
                      const SizedBox(width: 4),
                      Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                          color: AppColors.inkMute, size: 12),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // Friend avatar previews
              if (friends.isNotEmpty)
                SizedBox(
                  width: math.min(friends.length, 3) * 22.0 + 8,
                  height: 30,
                  child: Stack(
                    children: [
                      for (int i = 0; i < math.min(friends.length, 3); i++)
                        Positioned(
                          left: i * 22.0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.card, width: 1.5),
                            ),
                            child: ClipOval(
                              child: UserAvatar(
                                username: friends[i].username,
                                photoUrl: friends[i].photoUrl,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              // "+" add chip
              if (isOwnProfile)
                GestureDetector(
                  onTap: () => context.push('/home/friends/search'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.amberGlow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                    ),
                    child: Text(
                      '+ Add',
                      style: _inter(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                ),
              // Pending requests badge
              if (isOwnProfile && pendingCount > 0) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => context.push('/home/friends'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.lossSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$pendingCount new',
                      style: _inter(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.loss,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal friend strip
          if (friendsAsync.isLoading)
            const SizedBox(
              height: 70,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (friends.isEmpty && !isOwnProfile)
            Text(
              'No friends yet',
              style: _inter(size: 12, color: AppColors.inkMute),
            )
          else
            SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: friends.length + (isOwnProfile ? 1 : 0),
                itemBuilder: (_, i) {
                  if (isOwnProfile && i == friends.length) {
                    return _AddFriendChip(
                      onTap: () => context.push('/home/friends/search'),
                    );
                  }
                  final f = friends[i];
                  return _FriendChip(
                    friend: f,
                    onTap: () => context.push('/home/profile/${f.uid}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendChip extends ConsumerWidget {
  final FriendModel friend;
  final VoidCallback onTap;
  const _FriendChip({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_profileProvider(friend.uid));
    final userModel = userAsync.valueOrNull;
    final photoUrl = userModel?.photoUrl ?? friend.photoUrl;

    // Respect the friend's showOnlineStatus and invisibleMode prefs
    final canShowOnline =
        (userModel?.showOnlineStatus ?? true) &&
        !(userModel?.invisibleMode ?? false);
    final isOnline = canShowOnline && friend.isOnline;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                UserAvatar(
                  username: friend.username,
                  photoUrl: photoUrl,
                  size: 52,
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.win : AppColors.inkMute,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              friend.username,
              style: _inter(size: 10, color: AppColors.inkDim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFriendChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFriendChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.amberGlow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.amber.withOpacity(0.4),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Icon(Icons.person_add_rounded,
                  color: AppColors.amber, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              'add'.tr(),
              style: _inter(size: 10, color: AppColors.amber),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action buttons for other user's profile ────────────────────────────────────

class _OtherProfileActions extends ConsumerStatefulWidget {
  final UserModel user;
  final String myUid;

  const _OtherProfileActions({required this.user, required this.myUid});

  @override
  ConsumerState<_OtherProfileActions> createState() =>
      _OtherProfileActionsState();
}

class _OtherProfileActionsState extends ConsumerState<_OtherProfileActions> {
  bool _loading = false;

  bool _waitingChallenge = false;
  String? _challengeInviteKey;
  StreamSubscription? _challengeSub;
  Timer? _challengeTimeout;

  @override
  void dispose() {
    _challengeSub?.cancel();
    _challengeTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.myUid.isEmpty) return const SizedBox.shrink();

    final isFriendAsync = ref.watch(
        _isFriendProvider((myUid: widget.myUid, otherUid: widget.user.uid)));

    return isFriendAsync.when(
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox.shrink(),
      data: (isFriend) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Message button — amber bg, dark text
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/home/chat/${widget.user.uid}'),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Message',
                      style: _inter(
                        size: 13,
                        weight: FontWeight.w700,
                        color: const Color(0xFF1A1205),
                      ),
                    ),
                  ),
                ),
              ),
              if (isFriend || widget.user.friendRequestPrivacy != 'nobody') ...[
                const SizedBox(width: 10),
                // Add / Remove Friend
                Expanded(
                  child: _loading
                      ? Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : GestureDetector(
                          onTap: isFriend ? _removeFriend : _addFriend,
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              isFriend ? 'Friends' : 'Add Friend',
                              style: _inter(
                                size: 13,
                                weight: FontWeight.w700,
                                color: isFriend ? AppColors.inkDim : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
          // Challenge button
          if (widget.user.currentGameId == null) ...[
            const SizedBox(height: 10),
            _waitingChallenge
                ? _ChallengeWaitingTile(onCancel: _cancelChallenge)
                : AbsorbPointer(
                    absorbing: widget.user.challengePrivacy == 'nobody',
                    child: Opacity(
                      opacity: widget.user.challengePrivacy == 'nobody' ? 0.4 : 1.0,
                      child: GestureDetector(
                        onTap: () => _showChallengeSheet(context),
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.amberGlow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.amber.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('♟', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                'Challenge',
                                style: _inter(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppColors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Future<void> _showChallengeSheet(BuildContext context) async {
    // Respect target user's challenge privacy
    final privacy = widget.user.challengePrivacy;
    if (privacy == 'nobody') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${widget.user.username} is not accepting challenges.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (privacy == 'friends') {
      final isFriend = await ref.read(
          _isFriendProvider((myUid: widget.myUid, otherUid: widget.user.uid))
              .future);
      if (!mounted) return;
      if (!isFriend) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.user.username} only accepts challenges from friends.'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChallengeSheet(
        opponent: widget.user,
        onSend: (tc, color) async {
          Navigator.pop(ctx);
          await _sendChallenge(tc, color, context);
        },
      ),
    );
  }

  Future<void> _sendChallenge(
    TimeControl tc,
    String color,
    BuildContext context,
  ) async {
    setState(() {
      _waitingChallenge = true;
    });

    try {
      final me = await ref.read(currentUserProvider.future);
      if (me == null || !mounted) return;

      final isWhite = switch (color) {
        'white' => true,
        'black' => false,
        _ => DateTime.now().millisecondsSinceEpoch % 2 == 0,
      };

      final toUid = widget.user.uid;

      final gt = ref.read(activeGameProvider);
      final inviteKey = await ref.read(realtimeGameServiceProvider).sendInvite(
        fromUid: me.uid,
        fromUsername: me.username,
        toUid: toUid,
        timeControlLabel: tc.label,
        isWhite: isWhite,
        gameType: gt.name,
      );

      try {
        await ref.read(firestoreServiceProvider).createGameInviteNotification(
          toUid: toUid,
          fromUid: me.uid,
          fromUsername: me.username,
          timeControlLabel: tc.label,
          isWhite: isWhite,
          gameType: gt.name,
        );
      } catch (_) {}

      if (!mounted) return;
      _challengeInviteKey = inviteKey;

      _challengeSub?.cancel();
      _challengeSub = ref
          .read(realtimeGameServiceProvider)
          .watchInviteStatus(toUid, inviteKey)
          .listen((event) {
        if (!mounted) return;
        final raw = event.snapshot.value;
        if (raw == null) return;
        final data = Map<String, dynamic>.from(raw as Map);
        final status = data['status'] as String? ?? '';

        if (status == 'accepted') {
          final gameId = data['gameId'] as String?;
          if (gameId == null) return;
          _challengeSub?.cancel();
          _challengeTimeout?.cancel();
          if (!mounted) return;
          setState(() => _waitingChallenge = false);
          final gt = ref.read(activeGameProvider);
          context.push(gt.gameRoute(gameId), extra: {
            'mode': GameMode.online.name,
            'gameType': gt.name,
            'timeControl': tc.toMap(),
            'playerIsWhite': isWhite,
            'isRated': true,
            'gameId': gameId,
            'myUsername': me.username,
            'opponentUsername': widget.user.username,
            'opponentUid': toUid,
          });
        } else if (status == 'declined') {
          _challengeSub?.cancel();
          _challengeTimeout?.cancel();
          if (!mounted) return;
          setState(() => _waitingChallenge = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.user.username} declined the challenge.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });

      _challengeTimeout?.cancel();
      _challengeTimeout = Timer(const Duration(seconds: 60), () {
        if (mounted) _cancelChallenge();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _waitingChallenge = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send challenge: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelChallenge() async {
    _challengeSub?.cancel();
    _challengeTimeout?.cancel();
    final toUid = widget.user.uid;
    final key = _challengeInviteKey;
    if (mounted) setState(() { _waitingChallenge = false; _challengeInviteKey = null; });
    if (key != null) {
      try {
        await ref.read(realtimeGameServiceProvider).deleteInvite(toUid, key);
      } catch (_) {}
    }
  }

  Future<void> _addFriend() async {
    // Respect target user's friend request privacy
    if (widget.user.friendRequestPrivacy == 'nobody') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${widget.user.username} is not accepting friend requests.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      final me = ref.read(currentUserProvider).valueOrNull;
      if (me == null) return;
      await ref.read(friendsServiceProvider).sendRequest(
            fromUid: widget.myUid,
            fromUsername: me.username,
            toUid: widget.user.uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to ${widget.user.username}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        ref.invalidate(
            _isFriendProvider((myUid: widget.myUid, otherUid: widget.user.uid)));
      }
    }
  }

  Future<void> _removeFriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('remove_friend'.tr(), style: AppTextStyles.titleMedium),
        content: Text('Remove ${widget.user.username} from friends?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr(),
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(friendsServiceProvider)
          .removeFriend(widget.myUid, widget.user.uid);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        ref.invalidate(
            _isFriendProvider((myUid: widget.myUid, otherUid: widget.user.uid)));
      }
    }
  }
}

// ── Watch Live Game banner ─────────────────────────────────────────────────────

class _WatchLiveBanner extends StatelessWidget {
  final String gameId;
  final String watchedUid;
  const _WatchLiveBanner({required this.gameId, required this.watchedUid});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/spectate/$gameId', extra: watchedUid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.withOpacity(0.18),
              Colors.red.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Playing live now',
                style: _inter(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Watch',
                style: _inter(
                  size: 12,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Shimmer ────────────────────────────────────────────────────────────

class _ProfileShimmer extends StatelessWidget {
  const _ProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 80),
          const Center(
            child: ShimmerBox(width: 84, height: 84, borderRadius: 24),
          ),
          const SizedBox(height: 16),
          const Center(
            child: ShimmerBox(width: 120, height: 22, borderRadius: 6),
          ),
          const SizedBox(height: 8),
          const Center(
            child: ShimmerBox(width: 180, height: 14, borderRadius: 4),
          ),
          const SizedBox(height: 32),
          const ShimmerBox(width: double.infinity, height: 160, borderRadius: 16),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 80, borderRadius: 12)),
              const SizedBox(width: 8),
              Expanded(child: ShimmerBox(width: double.infinity, height: 80, borderRadius: 12)),
              const SizedBox(width: 8),
              Expanded(child: ShimmerBox(width: double.infinity, height: 80, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
        ],
      ),
    );
  }
}

// ── Challenge Waiting Tile ─────────────────────────────────────────────────────

class _ChallengeWaitingTile extends StatelessWidget {
  final VoidCallback onCancel;
  const _ChallengeWaitingTile({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amberGlow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'waiting_for_response'.tr(),
              style: _inter(size: 13, weight: FontWeight.w500, color: AppColors.amber),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkDim),
          ),
        ],
      ),
    );
  }
}

// ── Challenge Sheet ────────────────────────────────────────────────────────────

class _ChallengeSheet extends ConsumerStatefulWidget {
  final UserModel opponent;
  final void Function(TimeControl tc, String color) onSend;
  const _ChallengeSheet({required this.opponent, required this.onSend});

  @override
  ConsumerState<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends ConsumerState<_ChallengeSheet> {
  TimeControl _tc = TimeControls.blitz5;
  String _color = 'random';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              UserAvatar(
                username: widget.opponent.username,
                photoUrl: widget.opponent.photoUrl,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('challenge'.tr(), style: AppTextStyles.titleMedium),
                    Text(
                      widget.opponent.username,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'time_control'.tr(),
            style: _inter(size: 11, weight: FontWeight.w600, color: AppColors.inkMute, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          TimeControlSelector(selected: _tc, onSelect: (t) => setState(() => _tc = t)),
          const SizedBox(height: 20),
          Text(
            'You play as',
            style: _inter(size: 11, weight: FontWeight.w600, color: AppColors.inkMute, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final opt in [('white', '♔ White'), ('random', '⚄ Random'), ('black', '♚ Black')]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _color = opt.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _color == opt.$1
                            ? AppColors.amberGlow
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _color == opt.$1
                              ? AppColors.amber
                              : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          opt.$2,
                          style: _inter(
                            size: 12,
                            weight: _color == opt.$1 ? FontWeight.w700 : FontWeight.w400,
                            color: _color == opt.$1 ? AppColors.amber : AppColors.inkDim,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                if (opt.$1 != 'black') const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Send Challenge',
            onTap: () => widget.onSend(_tc, _color),
          ),
        ],
      ),
    );
  }
}

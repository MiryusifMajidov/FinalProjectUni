import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/bot_badge.dart';
import '../../../core/services/bot_pool.dart';
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


import '../../../core/widgets/game_icon.dart';
import '../../../core/widgets/route_settled.dart';
import '../../../core/theme/app_fonts.dart';
/// Live user document of another player (your own comes from
/// [currentUserProvider], which is already loaded). Released when nobody
/// shows that player any more, so visited profiles and friend chips do not
/// keep Firestore listeners open for the rest of the session.
final _profileProvider =
    StreamProvider.autoDispose.family<UserModel?, String>((ref, uid) {
  return ref.read(firestoreServiceProvider).watchUser(uid);
});

/// Up to 100 recent games of a player, for the rating chart and game list.
///
/// Keyed on the newest entry of the player's `recentGameIds`, which every
/// finished game appends to: opening the profile again reuses the result
/// (no Firestore reads), and a newly finished game fetches it again. Kept
/// for a while after the profile closes so going back and forth is free.
final _profileGamesProvider = FutureProvider.autoDispose
    .family<List<GameModel>, ({String uid, String? newest})>((ref, key) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);
  return ref
      .read(firestoreServiceProvider)
      .getRecentGames(key.uid, limit: 100);
});

/// Most game rows the two-column tablet layout shows (the phone list is lazy
/// and shows them all); the chart always uses every fetched game.
const _kTabletRecentGames = 30;

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

/// Headings and large numbers: Inter, a step bolder than body text. (This was
/// an italic serif — Fraunces — which read as decoration, not as a product.)
TextStyle _display({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.ink,
  double letterSpacing = 0,
}) =>
    AppFonts.ui(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing != 0 ? letterSpacing : (size >= 20 ? -0.4 : 0),
    );

TextStyle _inter({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double letterSpacing = 0,
}) =>
    AppFonts.ui(
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
    AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

// ── Screen ─────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  final String uid;

  /// Your own profile shown as the home screen's Profile tab: no back
  /// arrow, the navigation bar stays below it.
  final bool asTab;
  const ProfileScreen({super.key, required this.uid, this.asTab = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilt when the selected game changes: the page wears its colour
    // (AppColors.accent).
    ref.watch(activeGameProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isOwnProfile = currentUid == uid;
    // Your own document is already streaming for the home screen, so the
    // profile opens with data instead of a shimmer.
    final userAsync = isOwnProfile
        ? ref.watch(currentUserProvider)
        : ref.watch(_profileProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        loading: () => const _ProfileShimmer(),
        error: (e, _) => Center(
          child: Text('profile_load_failed'.tr(), style: AppTextStyles.bodyMedium),
        ),
        data: (user) {
          if (user == null) {
            return Center(child: Text('user_not_found'.tr()));
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
            asTab: asTab,
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
  final bool asTab;

  const _ProfileContent({
    required this.user,
    required this.isOwnProfile,
    required this.myUid,
    this.asTab = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOwnProfile) {
      return _OwnProfileLayout(user: user, myUid: myUid, asTab: asTab);
    }

    // Friends-only profile: check friendship before showing full content
    if (user.profileVisibility == 'Friends' && myUid.isNotEmpty) {
      final isFriendAsync = ref.watch(
          _isFriendProvider((myUid: myUid, otherUid: user.uid)));
      return isFriendAsync.when(
        loading: () => const _ProfileShimmer(),
        error: (_, __) => _OtherProfileLayout(user: user, myUid: myUid),
        data: (isFriend) {
          if (!isFriend) return _PrivateProfileView(user: user);
          return _OtherProfileLayout(user: user, myUid: myUid);
        },
      );
    }

    return _OtherProfileLayout(user: user, myUid: myUid);
  }
}

// ── Own Profile ────────────────────────────────────────────────────────────────

class _OwnProfileLayout extends ConsumerStatefulWidget {
  final UserModel user;
  final String myUid;

  /// Shown as the Profile tab (no back arrow).
  final bool asTab;

  const _OwnProfileLayout({
    required this.user,
    required this.myUid,
    this.asTab = false,
  });

  @override
  ConsumerState<_OwnProfileLayout> createState() => _OwnProfileLayoutState();
}

class _OwnProfileLayoutState extends ConsumerState<_OwnProfileLayout>
    with RouteSettledMixin<_OwnProfileLayout> {
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
              title: Text('take_photo'.tr(),
                  style: _inter(size: 14, weight: FontWeight.w500, color: AppColors.ink)),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIcons.image(PhosphorIconsStyle.regular),
                  color: AppColors.ink),
              title: Text('choose_from_gallery'.tr(),
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
                title: Text('remove_photo'.tr(),
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
          SnackBar(
            content: Text('photo_remove_failed'.tr()),
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
    final isLargeTablet = context.isLargeTablet;
    final hp = context.hPadding;
    final activeGame = ref.watch(activeGameProvider);

    // Games are fetched only once the page has finished sliding in; until
    // then, and while they load, the chart and the list show a loading state.
    final gamesAsync = routeSettled
        ? ref.watch(_profileGamesProvider(
            (uid: user.uid, newest: user.recentGameIds.lastOrNull)))
        : const AsyncValue<List<GameModel>>.loading();

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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.accent, AppColors.accent],
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
                            color: Color(0xFF241703),
                          ),
                        )
                      : (user.photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CachedNetworkImage(
                                imageUrl: user.photoUrl!,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                // Decode at display size, not the upload's.
                                memCacheWidth: _avatarCachePx(context),
                              ),
                            )
                          : Text(
                              user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : '?',
                              style: _display(
                                  size: 40,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF241703)),
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
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2.5),
                    ),
                    child: Icon(
                      PhosphorIcons.camera(PhosphorIconsStyle.fill),
                      size: 13,
                      color: const Color(0xFF241703),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(user.username,
              style: _display(size: 26, weight: FontWeight.w600, color: AppColors.ink)),
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
    );

    Widget graphCard() => _RatingGraphCard(
      overallRating: switch (activeGame) {
        GameType.checkers => user.checkersStats.rating,
        GameType.domino   => user.dominoStats.rating,
        GameType.chess    => user.overallRating,
      },
      uid: myUid,
      games: gamesAsync.valueOrNull ?? const [],
      loading: !gamesAsync.hasValue && !gamesAsync.hasError,
      activeGame: activeGame,
    );

    Widget statPills() => _StatPillsRow(user: user, activeGame: activeGame);

    Widget donutCard() => _GamesDonutCard(
      wins: totalWins, draws: totalDraws, losses: totalLosses,
    );

    Widget friendsSection() => _FriendsSection(
      uid: user.uid, isOwnProfile: true, myUid: myUid, live: routeSettled,
    );

    Widget recentGamesLabel() => Text(
      'recent_games'.tr(),
      style: _inter(size: 11, weight: FontWeight.w600, color: AppColors.inkMute, letterSpacing: 0.8),
    );

    Widget gameRow(GameModel g) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        // Move-by-move replay exists for chess only —
        // checkers/domino entries are informational.
        onTap: g.gameType == 'chess'
            ? () => context.push('/home/game-replay/${g.id}', extra: myUid)
            : null,
        child: RecentGameTile(game: g, uid: user.uid),
      ),
    );

    // ── Build ─────────────────────────────────────────────────────────────────

    final appBar = SliverAppBar(
      backgroundColor: AppColors.background,
      automaticallyImplyLeading: false,
      pinned: true,
      elevation: 0,
      // As the Profile tab there is nothing to go back to.
      leading: widget.asTab
          ? null
          : IconButton(
              icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                  color: AppColors.inkDim),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
      title: Text('profile'.tr(),
          style: _inter(size: 13, weight: FontWeight.w600, color: AppColors.inkDim)),
      actions: [
        IconButton(
          icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.regular),
              color: AppColors.inkDim, size: 20),
          tooltip: 'account'.tr(),
          onPressed: () => context.push('/home/settings/account'),
        ),
      ],
    );

    // ── Large tablet: 2-column ──────────────────────────────────────────────
    if (isLargeTablet) {
      return CustomScrollView(
        slivers: [
          appBar,
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hp, 8, hp, 32),
              child: Row(
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
                        _RecentGamesColumn(gamesAsync: gamesAsync, row: gameRow),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── Phone / regular tablet: single column ───────────────────────────────
    return CustomScrollView(
      slivers: [
        appBar,
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hp, 8, hp, 0),
          sliver: SliverList.list(
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
            ],
          ),
        ),
        _recentGamesSliver(gamesAsync: gamesAsync, hp: hp, row: gameRow),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

/// Pixel width to decode an 84 pt avatar at on this screen.
int _avatarCachePx(BuildContext context) =>
    (84 * MediaQuery.devicePixelRatioOf(context)).round();

/// The recent-games list as a lazy sliver: only the rows on screen are built,
/// not every fetched game in one frame.
Widget _recentGamesSliver({
  required AsyncValue<List<GameModel>> gamesAsync,
  required double hp,
  required Widget Function(GameModel game) row,
}) {
  final games = gamesAsync.valueOrNull;
  final padding = EdgeInsets.symmetric(horizontal: hp);
  if (games == null || games.isEmpty) {
    return SliverPadding(
      padding: padding,
      sliver: SliverToBoxAdapter(
        child: games != null
            ? const _NoGamesYet()
            : gamesAsync.hasError
                ? const SizedBox.shrink()
                : const ShimmerList(count: 4, itemHeight: 70),
      ),
    );
  }
  return SliverPadding(
    padding: padding,
    sliver: SliverList.builder(
      itemCount: games.length,
      itemBuilder: (_, i) => row(games[i]),
    ),
  );
}

/// The recent-games list inside the two-column tablet layout, where it
/// cannot be a sliver — so it is capped instead.
class _RecentGamesColumn extends StatelessWidget {
  final AsyncValue<List<GameModel>> gamesAsync;
  final Widget Function(GameModel game) row;
  const _RecentGamesColumn({required this.gamesAsync, required this.row});

  @override
  Widget build(BuildContext context) {
    final games = gamesAsync.valueOrNull;
    if (games == null) {
      return gamesAsync.hasError
          ? const SizedBox.shrink()
          : const ShimmerList(count: 4, itemHeight: 70);
    }
    if (games.isEmpty) return const _NoGamesYet();
    return Column(
      children: [for (final g in games.take(_kTabletRecentGames)) row(g)],
    );
  }
}

/// Rating pills under the chart: bullet / blitz / rapid for chess, one pill
/// for checkers and domino.
class _StatPillsRow extends StatelessWidget {
  final UserModel user;
  final GameType activeGame;
  const _StatPillsRow({required this.user, required this.activeGame});

  @override
  Widget build(BuildContext context) {
    if (activeGame == GameType.chess) {
      return Row(
        children: [
          Expanded(child: _StatPillCard(
            label: 'BULLET', rating: user.bulletStats.rating,
            ratingColor: AppColors.bullet,
            subStats: '${user.bulletStats.wins}W ${user.bulletStats.draws}D ${user.bulletStats.losses}L',
          )),
          const SizedBox(width: 8),
          Expanded(child: _StatPillCard(
            label: 'BLITZ', rating: user.blitzStats.rating,
            ratingColor: AppColors.blitz,
            subStats: '${user.blitzStats.wins}W ${user.blitzStats.draws}D ${user.blitzStats.losses}L',
          )),
          const SizedBox(width: 8),
          Expanded(child: _StatPillCard(
            label: 'RAPID', rating: user.rapidStats.rating,
            ratingColor: AppColors.rapid,
            subStats: '${user.rapidStats.wins}W ${user.rapidStats.draws}D ${user.rapidStats.losses}L',
          )),
        ],
      );
    }
    final stats = activeGame == GameType.checkers ? user.checkersStats : user.dominoStats;
    return Row(
      children: [
        Expanded(child: _StatPillCard(
          label: activeGame.name.tr(),
          rating: stats.rating,
          ratingColor: activeGame.accent,
          subStats: '${stats.wins}W ${stats.draws}D ${stats.losses}L',
        )),
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
                    style: _display(size: 18, weight: FontWeight.w700,
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
              style: _display(size: 20, weight: FontWeight.w700,
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

class _OtherProfileLayout extends ConsumerStatefulWidget {
  final UserModel user;
  final String myUid;

  const _OtherProfileLayout({
    required this.user,
    required this.myUid,
  });

  @override
  ConsumerState<_OtherProfileLayout> createState() =>
      _OtherProfileLayoutState();
}

class _OtherProfileLayoutState extends ConsumerState<_OtherProfileLayout>
    with RouteSettledMixin<_OtherProfileLayout> {
  UserModel get user => widget.user;
  String get myUid => widget.myUid;

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
                '${(isBlocked ? 'unblock_user' : 'block_user').tr()} ${user.username}',
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
                  color: AppColors.accent),
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
                textColor: AppColors.accent,
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
  Widget build(BuildContext context) {
    final isLargeTablet = context.isLargeTablet;
    final hp = context.hPadding;

    // Fetched only once the page has finished sliding in (see the own
    // profile); the list shows a loading state until then.
    final gamesAsync = routeSettled
        ? ref.watch(_profileGamesProvider(
            (uid: user.uid, newest: user.recentGameIds.lastOrNull)))
        : const AsyncValue<List<GameModel>>.loading();

    // Username masking: if they blocked me, show "Chess User"
    final displayName = user.blockedUsers.contains(myUid) ? 'Chess User' : user.username;

    // ── Local sub-widget builders ─────────────────────────────────────────────

    Widget avatarSection() => Center(
      child: Column(
        children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: user.photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(
                      imageUrl: user.photoUrl!,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      memCacheWidth: _avatarCachePx(context),
                    ),
                  )
                : Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: _display(size: 40, weight: FontWeight.w700, color: const Color(0xFF241703)),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(displayName,
                    overflow: TextOverflow.ellipsis,
                    style: _display(size: 22, weight: FontWeight.w600, color: AppColors.ink)),
              ),
              if (BotPool.isLabelledUid(user.uid)) ...[
                const SizedBox(width: 8),
                const BotBadge(),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text([
                UserModel.flagEmoji(user.countryCode),
                user.skillLevel ?? 'Player',
              ].where((part) => part.isNotEmpty).join(' · '),
              style: _inter(size: 11, color: AppColors.inkMute)),
        ],
      ),
    );

    final activeGame = ref.watch(activeGameProvider);

    final otherOverallRating = switch (activeGame) {
      GameType.checkers => user.checkersStats.rating,
      GameType.domino   => user.dominoStats.rating,
      GameType.chess    => ((user.bulletStats.rating + user.blitzStats.rating + user.rapidStats.rating) / 3).round(),
    };

    Widget ratingCard() => _OverallRatingCard(rating: otherOverallRating);

    Widget statPills() => _StatPillsRow(user: user, activeGame: activeGame);

    Widget actionButtons() => _OtherProfileActions(user: user, myUid: myUid);

    Widget friendsSection() => _FriendsSection(
      uid: user.uid, isOwnProfile: false, myUid: myUid, live: routeSettled,
    );

    Widget recentGamesLabel() => Text(
      'recent_games'.tr(),
      style: _inter(size: 11, weight: FontWeight.w600, color: AppColors.inkMute, letterSpacing: 0.8),
    );

    Widget gameRow(GameModel g) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RecentGameTile(game: g, uid: user.uid),
    );

    // ── Build ─────────────────────────────────────────────────────────────────

    final appBar = SliverAppBar(
      backgroundColor: AppColors.background,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold), color: AppColors.inkDim),
        onPressed: () => context.pop(),
      ),
      title: Text(displayName,
          style: _display(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      actions: [
        IconButton(
          icon: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
              color: AppColors.inkMute, size: 20),
          onPressed: () => _showBlockSheet(context, ref),
        ),
      ],
    );

    // Live banner (always full-width above the columns)
    final liveBanner = <Widget>[
      if (user.currentGameId != null) ...[
        _WatchLiveBanner(
          gameId: user.currentGameId!,
          watchedUid: user.uid,
        ),
        const SizedBox(height: 14),
      ],
    ];

    // ── Large tablet: 2-column ──────────────────────────────────────────────
    if (isLargeTablet) {
      return CustomScrollView(
        slivers: [
          appBar,
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hp, 8, hp, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...liveBanner,
                  Row(
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
                            _RecentGamesColumn(gamesAsync: gamesAsync, row: gameRow),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── Phone / regular tablet: single column ───────────────────────────────
    return CustomScrollView(
      slivers: [
        appBar,
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hp, 8, hp, 0),
          sliver: SliverList.list(
            children: [
              ...liveBanner,
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
            ],
          ),
        ),
        _recentGamesSliver(gamesAsync: gamesAsync, hp: hp, row: gameRow),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
          colors: [AppColors.cardElevated, AppColors.cardElevated],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OVERALL RATING',
                style: _mono(
                  size: 10,
                  weight: FontWeight.w500,
                  color: const Color(0xFF241703).withOpacity(0.7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$rating',
                style: _display(
                  size: 44,
                  weight: FontWeight.w700,
                  color: const Color(0xFF241703),
                  letterSpacing: -1.5,
                ),
              ),
              Text(
                'Top player globally',
                style: _inter(
                  size: 11,
                  color: const Color(0xFF241703).withOpacity(0.6),
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

  /// Games are still on their way: the card keeps its size and shows a
  /// spinner where the chart goes.
  final bool loading;

  const _RatingGraphCard({
    required this.overallRating,
    required this.uid,
    required this.games,
    this.activeGame = GameType.chess,
    this.loading = false,
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
    final history  = loading
        ? (points: const <int>[], dates: const <DateTime>[])
        : _buildHistory();
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

    final scoreWord = (activeGame.isPointBased ? 'points_label' : 'rating').tr();
    final accent = activeGame.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
                        ? '${activeGame.name.tr()} · ${'games_n'.tr(args: ['$gameCount'])}'
                        : '${activeGame.name.tr()} · $scoreWord',
                    style: _mono(
                      size: 13,
                      color: AppColors.inkMute,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$overallRating',
                    style: _display(
                      size: 40,
                      weight: FontWeight.w600,
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
                      'peak_n'.tr(args: ['$peak']),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.inkMute,
                        ),
                      ),
                    )
                  : _RatingGraph(
                      key: const ValueKey('chart'),
                      data: hasData ? data : [overallRating, overallRating],
                      isPlaceholder: !hasData,
                      accent: accent,
                    ),
            ),
          ),
          // The date row is always laid out, so the card does not grow when
          // the games arrive.
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(hasData ? startLabel : '',
                  style: _mono(size: 9, color: AppColors.inkMute)),
              Text(hasData ? 'today'.tr() : '',
                  style: _mono(size: 9, color: AppColors.inkMute)),
            ],
          ),
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
  _RatingGraph({super.key, required this.data, this.isPlaceholder = false, Color? accent}) : accent = accent ?? AppColors.accent;

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
  _RatingGraphPainter({required this.data, this.isPlaceholder = false, Color? accent}) : accent = accent ?? AppColors.accent;

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
      !listEquals(old.data, data) ||
      old.isPlaceholder != isPlaceholder ||
      old.accent != accent;
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
            style: _display(size: 22, weight: FontWeight.w700, color: ratingColor),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
                  label: 'wins'.tr(),
                  count: wins,
                ),
                const SizedBox(height: 8),
                _DonutLegendRow(
                  color: AppColors.draw,
                  label: 'draws'.tr(),
                  count: draws,
                ),
                const SizedBox(height: 8),
                _DonutLegendRow(
                  color: AppColors.loss,
                  label: 'losses'.tr(),
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
        painter: _WinLossDonutPainter(
          wins: wins,
          draws: draws,
          losses: losses,
          label: 'games'.tr(),
        ),
      ),
    );
  }
}

class _WinLossDonutPainter extends CustomPainter {
  final int wins;
  final int draws;
  final int losses;

  /// Word under the total ("GAMES"), already translated.
  final String label;

  _WinLossDonutPainter({
    required this.wins,
    required this.draws,
    required this.losses,
    required this.label,
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
        style: AppFonts.ui(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
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
        text: label,
        style: AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
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
      old.wins != wins ||
      old.draws != draws ||
      old.losses != losses ||
      old.label != label;
}

// ── Friends section ────────────────────────────────────────────────────────────

class _FriendsSection extends ConsumerWidget {
  final String uid;
  final bool isOwnProfile;
  final String myUid;

  /// False while the page is still sliding in: the section shows its
  /// loading state and opens no Firestore listeners yet.
  final bool live;

  const _FriendsSection({
    required this.uid,
    required this.isOwnProfile,
    required this.myUid,
    this.live = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = live
        ? ref.watch(_friendsStreamProvider(uid))
        : const AsyncValue<List<FriendModel>>.loading();
    final pendingAsync = isOwnProfile && live
        ? ref.watch(_pendingRequestsProvider(uid))
        : null;

    final friends = friendsAsync.valueOrNull ?? [];
    final pendingCount = pendingAsync?.valueOrNull?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
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
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'friends'.tr(),
                      style: _inter(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    ),
                    // Count only once known — not a "0" that jumps.
                    if (friendsAsync.hasValue) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGlow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${friends.length}',
                          style: _mono(size: 10, weight: FontWeight.w600, color: AppColors.accent),
                        ),
                      ),
                    ],
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
                      color: AppColors.accentGlow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      '+ ${'add'.tr()}',
                      style: _inter(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.accent,
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
                      'n_new'.tr(args: ['$pendingCount']),
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

          // Horizontal friend strip (same height loading or loaded, so the
          // page below does not jump)
          if (friendsAsync.isLoading)
            const SizedBox(
              height: 76,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.inkMute),
                ),
              ),
            )
          else if (friends.isEmpty && !isOwnProfile)
            Text(
              'no_friends_yet'.tr(),
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
                color: AppColors.accentGlow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.4),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(Icons.person_add_rounded,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              'add'.tr(),
              style: _inter(size: 10, color: AppColors.accent),
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
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Message',
                      style: _inter(
                        size: 13,
                        weight: FontWeight.w700,
                        color: const Color(0xFF241703),
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
                            color: AppColors.accentGlow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIcons.sword(PhosphorIconsStyle.bold),
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(
                                'Challenge',
                                style: _inter(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppColors.accent,
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
            content: Text('challenge_send_failed'.tr()),
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
            content: Text('friend_request_sent_to'.tr(args: [widget.user.username])),
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
        content: Text('remove_friend_confirm'.tr(args: [widget.user.username]),
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
            child: Text('remove_friend'.tr(),
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
        color: AppColors.accentGlow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'waiting_for_response'.tr(),
              style: _inter(size: 13, weight: FontWeight.w500, color: AppColors.accent),
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
              for (final opt in [('white', 'White'), ('random', 'Random'), ('black', 'Black')]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _color = opt.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _color == opt.$1
                            ? AppColors.accentGlow
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _color == opt.$1
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (opt.$1 != 'random') ...[
                            PieceIcon(opt.$1 == 'white' ? 'wK' : 'bK', size: 18),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            opt.$2,
                            style: _inter(
                              size: 12,
                              weight: _color == opt.$1 ? FontWeight.w700 : FontWeight.w400,
                              color: _color == opt.$1 ? AppColors.accent : AppColors.inkDim,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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

/// Shown instead of an empty "Recent games" header with nothing under it.
class _NoGamesYet extends StatelessWidget {
  const _NoGamesYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.regular),
              size: 20, color: AppColors.inkMute),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'no_games_start_playing'.tr(),
              style: AppFonts.ui(fontSize: 14, color: AppColors.inkDim),
            ),
          ),
        ],
      ),
    );
  }
}

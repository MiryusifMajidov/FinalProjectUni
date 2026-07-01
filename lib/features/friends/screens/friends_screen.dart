import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/friends_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/friend_request_model.dart';
import '../../../core/widgets/user_avatar.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg      = AppColors.background;
const _kCard    = AppColors.card;
const _kSurface = AppColors.surface;
const _kAmber   = AppColors.amber;
const _kAmberDeep = AppColors.amberDeep;
const _kAmberGlow = AppColors.amberGlow;
const _kInk     = AppColors.ink;
const _kInkDim  = AppColors.inkDim;
const _kInkMute = AppColors.inkMute;
const _kBorder  = AppColors.border;
const _kWin     = AppColors.win;
const _kWinSoft = AppColors.winSoft;
const _kLoss    = AppColors.loss;
const _kLossSoft = AppColors.lossSoft;

/// Live user stream for friend tiles.
final _friendUserProvider =
    StreamProvider.autoDispose.family<UserModel?, String>((ref, uid) {
  return ref.read(firestoreServiceProvider).watchUser(uid);
});

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;

    if (myUid == null) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kAmber)),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Icon(
                          PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                          color: _kInkDim, size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'friends'.tr(),
                        style: GoogleFonts.fraunces(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: _kInk,
                        ),
                      ),
                    ),
                    // Add friend button
                    GestureDetector(
                      onTap: () => context.push('/home/friends/search'),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kAmberGlow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kAmber.withOpacity(0.4)),
                        ),
                        child: Icon(
                          PhosphorIcons.userPlus(PhosphorIconsStyle.regular),
                          color: _kAmber, size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Custom Tabs ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kAmber, _kAmberDeep],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: const Color(0xFF1A1205),
                    unselectedLabelColor: _kInkMute,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'friends'.tr()),
                      Tab(
                        child: _RequestsTabLabel(myUid: myUid),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tab Content ──────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    _FriendsTab(myUid: myUid),
                    _RequestsTab(myUid: myUid),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Requests tab label with badge ─────────────────────────────────────────────

class _RequestsTabLabel extends ConsumerWidget {
  final String myUid;
  const _RequestsTabLabel({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: ref.read(friendsServiceProvider).watchIncomingRequests(myUid),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('friend_requests'.tr()),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _kLoss,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Friends tab ───────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  final String myUid;
  const _FriendsTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<FriendModel>>(
      stream: ref.read(friendsServiceProvider).watchFriends(myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kAmber),
          );
        }
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: _kAmberGlow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    PhosphorIcons.users(PhosphorIconsStyle.regular),
                    size: 30, color: _kAmber,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'no_friends_yet'.tr(),
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'search_players'.tr(),
                  style: GoogleFonts.inter(fontSize: 13, color: _kInkMute),
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FriendTile(friend: friends[i], myUid: myUid),
                  childCount: friends.length,
                ),
              ),
            ),
            // ── Suggestions ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SuggestionsSection(myUid: myUid, friendUids: friends.map((f) => f.uid).toList()),
            ),
          ],
        );
      },
    );
  }
}

// ── Friend tile ───────────────────────────────────────────────────────────────

class _FriendTile extends ConsumerWidget {
  final FriendModel friend;
  final String myUid;
  const _FriendTile({required this.friend, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveUser = ref.watch(_friendUserProvider(friend.uid));
    final photoUrl = liveUser.valueOrNull?.photoUrl ?? friend.photoUrl;

    return GestureDetector(
      onLongPress: () => _confirmRemove(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  username: friend.username,
                  photoUrl: photoUrl,
                  size: 44,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 11, height: 11,
                    decoration: BoxDecoration(
                      color: friend.isOnline
                          ? _kWin
                          : _kInkMute.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBg, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.username,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend.isOnline
                        ? '${'online'.tr()} · ${friend.rating} ELO'
                        : '${friend.rating} ELO · ${'offline'.tr()}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: friend.isOnline ? _kWin : _kInkMute,
                      fontWeight: friend.isOnline
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Chat button
            GestureDetector(
              onTap: () => context.push('/home/chat/${friend.uid}'),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kAmberGlow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kAmber.withOpacity(0.2)),
                ),
                child: Icon(
                  PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                  color: _kAmber, size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Quick-play button
            GestureDetector(
              onTap: () => context.push('/home/invite-friend'),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Icon(
                  PhosphorIcons.lightning(PhosphorIconsStyle.regular),
                  color: _kInkDim, size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'remove_friend'.tr(),
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: _kInk,
          ),
        ),
        content: Text(
          'Remove ${friend.username} from your friends list?',
          style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(),
              style: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kLoss,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(friendsServiceProvider).removeFriend(myUid, friend.uid);
    }
  }
}

// ── Requests tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends ConsumerWidget {
  final String myUid;
  const _RequestsTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: ref.read(friendsServiceProvider).watchIncomingRequests(myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kAmber),
          );
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(
                    PhosphorIcons.bellSimple(PhosphorIconsStyle.regular),
                    size: 30, color: _kInkMute,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: requests.length,
          itemBuilder: (_, i) =>
              _RequestTile(request: requests[i], myUid: myUid),
        );
      },
    );
  }
}

// ── Request tile ──────────────────────────────────────────────────────────────

class _RequestTile extends ConsumerWidget {
  final FriendRequestModel request;
  final String myUid;
  const _RequestTile({required this.request, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _kSurface,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: Icon(
              PhosphorIcons.user(PhosphorIconsStyle.regular),
              color: _kInkMute, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromUsername,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Wants to be your friend',
                  style: GoogleFonts.inter(fontSize: 12, color: _kInkMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Accept
          GestureDetector(
            onTap: () => _accept(ref),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kWinSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: _kWin, size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Decline
          GestureDetector(
            onTap: () => _decline(ref),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kLossSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                PhosphorIcons.xCircle(PhosphorIconsStyle.regular),
                color: _kLoss, size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(WidgetRef ref) async {
    try {
      final me = ref.read(currentUserProvider).valueOrNull;
      if (me == null) return;
      await ref.read(friendsServiceProvider).acceptRequest(
        fromUid: request.fromUid,
        fromUsername: request.fromUsername,
        fromRating: 1200,
        toUid: myUid,
        toUsername: me.username,
        toRating: me.overallRating,
        toAvatarId: me.avatarId,
        toPhotoUrl: me.photoUrl,
      );
    } catch (_) {}
  }

  Future<void> _decline(WidgetRef ref) async {
    await ref.read(friendsServiceProvider).declineRequest(
      request.toUid,
      request.fromUid,
    );
  }
}

// ── Suggestions section ───────────────────────────────────────────────────────

class _SuggestionsSection extends ConsumerWidget {
  final String myUid;
  final List<String> friendUids;
  const _SuggestionsSection({required this.myUid, required this.friendUids});

  static const _reasons = ['Similar rating', 'Active player', 'Popular'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUser = ref.watch(currentUserProvider).valueOrNull;
    if (myUser == null) return const SizedBox.shrink();

    return FutureBuilder<List<UserModel>>(
      future: ref.read(firestoreServiceProvider).getSuggestedFriends(
        myRating: myUser.overallRating,
        excludeUids: [myUid, ...friendUids],
      ),
      builder: (context, snap) {
        final suggestions = snap.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'SUGGESTIONS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kInkMute,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...suggestions.asMap().entries.map((e) {
              final user = e.value;
              final reason = _reasons[e.key % _reasons.length];
              return _SuggestionTile(user: user, reason: reason, myUid: myUid);
            }),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _SuggestionTile extends ConsumerWidget {
  final UserModel user;
  final String reason;
  final String myUid;
  const _SuggestionTile({required this.user, required this.reason, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          UserAvatar(
            username: user.username,
            photoUrl: user.photoUrl,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
                Text(
                  '${user.overallRating} ELO · $reason',
                  style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              try {
                await ref.read(friendsServiceProvider).sendRequest(
                  fromUid: myUid,
                  fromUsername: ref
                      .read(currentUserProvider)
                      .valueOrNull
                      ?.username ?? '',
                  toUid: user.uid,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Request sent to ${user.username}'),
                      backgroundColor: _kCard,
                    ),
                  );
                }
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kAmberGlow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kAmber.withOpacity(0.33)),
              ),
              child: Text(
                '+ Add',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAmber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

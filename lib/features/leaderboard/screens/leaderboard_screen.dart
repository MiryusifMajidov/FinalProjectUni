import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/game_switch.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = AppColors.background;
const _kSurface      = AppColors.surface;
const _kCard         = AppColors.card;
const _kAmber        = AppColors.amber;
const _kAmberDeep    = AppColors.amberDeep;
const _kAmberGlow    = AppColors.amberGlow;
const _kInk          = AppColors.ink;
const _kInkDim       = AppColors.inkDim;
const _kInkMute      = AppColors.inkMute;
const _kBorder       = AppColors.border;

// ── Chess Providers ────────────────────────────────────────────────────────────

final _bulletLeaderboardProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('bulletStats.rating', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => UserModel.fromMap(d.data())).toList());
});

final _blitzLeaderboardProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('blitzStats.rating', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => UserModel.fromMap(d.data())).toList());
});

final _rapidLeaderboardProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('rapidStats.rating', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => UserModel.fromMap(d.data())).toList());
});

// ── Checkers Provider ─────────────────────────────────────────────────────────
// Fetch all users and sort client-side. Firestore orderBy on nested fields
// requires the field to exist in every document — legacy accounts registered
// before checkers/domino were added don't have it. Client-side sort is safe
// because UserModel.fromMap defaults missing stats to RatingStats(rating: 1200).

final _checkersLeaderboardProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .limit(200)
      .snapshots()
      .map((s) {
        final users = s.docs.map((d) => UserModel.fromMap(d.data())).toList();
        users.sort((a, b) => b.checkersStats.rating.compareTo(a.checkersStats.rating));
        return users.take(100).toList();
      });
});

// ── Domino Provider ───────────────────────────────────────────────────────────

final _dominoLeaderboardProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .limit(200)
      .snapshots()
      .map((s) {
        final users = s.docs.map((d) => UserModel.fromMap(d.data())).toList();
        users.sort((a, b) => b.dominoStats.rating.compareTo(a.dominoStats.rating));
        return users.take(100).toList();
      });
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;
    final activeGame = ref.watch(activeGameProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: _kInkDim,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'leaderboard'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Game switcher ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: GameSwitch(),
            ),

            const SizedBox(height: 12),

            // ── Tab Bar (chess-only, hidden for checkers/domino) ──
            if (activeGame == GameType.chess) ...[
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _kBorder)),
                ),
                child: Row(
                  children: [
                    _Tab(label: 'bullet'.tr(), index: 0, ctrl: _tabCtrl, accent: activeGame.accent),
                    _Tab(label: 'blitz'.tr(),  index: 1, ctrl: _tabCtrl, accent: activeGame.accent),
                    _Tab(label: 'rapid'.tr(),  index: 2, ctrl: _tabCtrl, accent: activeGame.accent),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _LeaderboardTab(
                      provider: _bulletLeaderboardProvider,
                      myUid: myUid,
                      ratingGetter: (u) => u.bulletStats.rating,
                      accent: activeGame.accent,
                    ),
                    _LeaderboardTab(
                      provider: _blitzLeaderboardProvider,
                      myUid: myUid,
                      ratingGetter: (u) => u.blitzStats.rating,
                      accent: activeGame.accent,
                    ),
                    _LeaderboardTab(
                      provider: _rapidLeaderboardProvider,
                      myUid: myUid,
                      ratingGetter: (u) => u.rapidStats.rating,
                      accent: activeGame.accent,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Checkers / Domino: single overall leaderboard (no sub-tabs)
              Expanded(
                child: _LeaderboardTab(
                  provider: activeGame == GameType.checkers
                      ? _checkersLeaderboardProvider
                      : _dominoLeaderboardProvider,
                  myUid: myUid,
                  ratingGetter: activeGame == GameType.checkers
                      ? (u) => u.checkersStats.rating
                      : (u) => u.dominoStats.rating,
                  accent: activeGame.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tab widget ─────────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final TabController ctrl;
  final Color accent;
  const _Tab({required this.label, required this.index, required this.ctrl, this.accent = _kAmber});

  @override
  Widget build(BuildContext context) {
    final selected = ctrl.index == index;
    return GestureDetector(
      onTap: () => ctrl.animateTo(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? accent : _kInkMute,
          ),
        ),
      ),
    );
  }
}

// ── Tab content ────────────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<UserModel>>> provider;
  final String? myUid;
  final int Function(UserModel) ratingGetter;
  final Color accent;

  const _LeaderboardTab({
    required this.provider,
    required this.myUid,
    required this.ratingGetter,
    this.accent = _kAmber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kAmber)),
      error: (e, _) => Center(
        child: Text(
          'Error loading leaderboard',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.error),
        ),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              'No players yet',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: _kInkMute,
              ),
            ),
          );
        }

        // Find own rank
        final myIndex = myUid != null
            ? users.indexWhere((u) => u.uid == myUid)
            : -1;
        final myRank = myIndex + 1;
        final myUser = myIndex >= 0 ? users[myIndex] : null;

        return Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.only(
                top: 0,
                bottom: myUser != null ? 72 : 20,
              ),
              itemCount: users.length + 1, // +1 for podium
              itemBuilder: (_, i) {
                if (i == 0) {
                  // Podium
                  return _Podium(
                    users: users,
                    ratingGetter: ratingGetter,
                  );
                }
                final rank = i; // ranks 1..N map to list index i-1
                final user = users[rank - 1];
                if (rank <= 3) return const SizedBox.shrink(); // shown in podium
                return _LeaderboardRow(
                  rank: rank,
                  user: user,
                  rating: ratingGetter(user),
                  isMe: user.uid == myUid,
                );
              },
            ),

            // ── Sticky own rank ──
            if (myUser != null && myRank > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _StickyOwnRank(
                  rank: myRank,
                  user: myUser,
                  rating: ratingGetter(myUser),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Podium ─────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<UserModel> users;
  final int Function(UserModel) ratingGetter;
  const _Podium({required this.users, required this.ratingGetter});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    final first  = users.isNotEmpty      ? users[0] : null;
    final second = users.length > 1      ? users[1] : null;
    final third  = users.length > 2      ? users[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: SizedBox(
        height: 290,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd place
            Expanded(
              child: _PodiumSlot(
                rank: 2,
                user: second,
                rating: second != null ? ratingGetter(second) : 0,
                podiumHeight: 96,
                avatarSize: 52,
                crownSize: 0,
                medalColor: const Color(0xFFA8A8B0),
                medalLabel: '2',
              ),
            ),
            const SizedBox(width: 8),
            // 1st place — center, tallest
            Expanded(
              child: _PodiumSlot(
                rank: 1,
                user: first,
                rating: first != null ? ratingGetter(first) : 0,
                podiumHeight: 128,
                avatarSize: 64,
                crownSize: 18,
                medalColor: _kAmber,
                medalLabel: '1',
              ),
            ),
            const SizedBox(width: 8),
            // 3rd place
            Expanded(
              child: _PodiumSlot(
                rank: 3,
                user: third,
                rating: third != null ? ratingGetter(third) : 0,
                podiumHeight: 76,
                avatarSize: 48,
                crownSize: 0,
                medalColor: const Color(0xFFB07A55),
                medalLabel: '3',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final int rank;
  final UserModel? user;
  final int rating;
  final double podiumHeight;
  final double avatarSize;
  final double crownSize;
  final Color medalColor;
  final String medalLabel;

  const _PodiumSlot({
    required this.rank,
    required this.user,
    required this.rating,
    required this.podiumHeight,
    required this.avatarSize,
    required this.crownSize,
    required this.medalColor,
    required this.medalLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/home/profile/${user!.uid}'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Crown (only for 1st)
          if (crownSize > 0) ...[
            Text('♛', style: TextStyle(fontSize: crownSize, color: _kAmber)),
            const SizedBox(height: 2),
          ],

          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarSize + 6,
                height: avatarSize + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: rank == 1
                        ? [_kAmber, _kAmberDeep]
                        : [medalColor.withValues(alpha:0.6), medalColor.withValues(alpha:0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              ClipOval(
                child: UserAvatar(
                  username: user!.username,
                  photoUrl: user!.photoUrl,
                  size: avatarSize,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Username
          Text(
            user!.username,
            style: GoogleFonts.inter(
              fontSize: rank == 1 ? 12 : 11,
              fontWeight: FontWeight.w600,
              color: rank == 1 ? _kInk : _kInkDim,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 2),

          // Rating
          Text(
            '$rating',
            style: GoogleFonts.jetBrainsMono(
              fontSize: rank == 1 ? 13 : 11,
              fontWeight: FontWeight.w700,
              color: rank == 1 ? _kAmber : medalColor,
            ),
          ),

          const SizedBox(height: 8),

          // Podium block
          Container(
            height: podiumHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: rank == 1
                    ? [_kAmber.withValues(alpha:0.25), _kAmber.withValues(alpha:0.08)]
                    : [medalColor.withValues(alpha:0.15), medalColor.withValues(alpha:0.04)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                top: BorderSide(
                  color: rank == 1 ? _kAmber.withValues(alpha:0.5) : medalColor.withValues(alpha:0.3),
                  width: 1.5,
                ),
                left: BorderSide(
                  color: rank == 1 ? _kAmber.withValues(alpha:0.2) : medalColor.withValues(alpha:0.15),
                ),
                right: BorderSide(
                  color: rank == 1 ? _kAmber.withValues(alpha:0.2) : medalColor.withValues(alpha:0.15),
                ),
              ),
            ),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: medalColor.withValues(alpha:0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: medalColor.withValues(alpha:0.6), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    medalLabel,
                    style: GoogleFonts.fraunces(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: medalColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard Row ────────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final UserModel user;
  final int rating;
  final bool isMe;

  const _LeaderboardRow({
    required this.rank,
    required this.user,
    required this.rating,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final flag = UserModel.flagEmoji(user.countryCode);

    return GestureDetector(
      onTap: () => context.push('/home/profile/${user.uid}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _kAmberGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isMe
              ? Border.all(color: _kAmber.withValues(alpha:0.3))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isMe ? _kAmber : _kInkMute,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),

            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: UserAvatar(
                username: user.username,
                photoUrl: user.photoUrl,
                size: 36,
              ),
            ),
            const SizedBox(width: 12),

            // Name + flag
            Expanded(
              child: Row(
                children: [
                  if (flag.isNotEmpty) ...[
                    Text(flag, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      user.username,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                        color: isMe ? _kInk : _kInkDim,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Rating
            Text(
              '$rating',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isMe ? _kAmber : _kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sticky Own Rank ────────────────────────────────────────────────────────────

class _StickyOwnRank extends StatelessWidget {
  final int rank;
  final UserModel user;
  final int rating;

  const _StickyOwnRank({
    required this.rank,
    required this.user,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final flag = UserModel.flagEmoji(user.countryCode);

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: const Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // "YOUR RANK" label
          Text(
            'YOUR RANK',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: _kInkMute,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 10),

          // Rank badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kAmberGlow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAmber.withValues(alpha:0.4)),
            ),
            child: Text(
              '#$rank',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kAmber,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: UserAvatar(
              username: user.username,
              photoUrl: user.photoUrl,
              size: 32,
            ),
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Row(
              children: [
                if (flag.isNotEmpty) ...[
                  Text(flag, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    user.username,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Rating
          Text(
            '$rating',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kAmber,
            ),
          ),
        ],
      ),
    );
  }
}

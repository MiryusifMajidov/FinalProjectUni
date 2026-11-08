import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/models/game_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/group_service.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/models/group_model.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/keyed_stream_builder.dart';
import '../../../core/theme/app_fonts.dart';

// ── Design tokens (local) ──────────────────────────────────────────────────────
const _kBg            = AppColors.background;
const _kCard          = AppColors.card;
Color get _kAmber => AppColors.accent;
Color get _kAmberGlow => AppColors.accentGlow;
const _kWin           = AppColors.win;
const _kInk           = AppColors.ink;
const _kInkDim        = AppColors.inkDim;
const _kInkMute       = AppColors.inkMute;
const _kBorder        = AppColors.border;

// ── Shared chats stream provider ───────────────────────────────────────────────
//
// autoDispose.family: one Firestore listener per UID, shared across all widgets
// on this screen. Disposed automatically when the screen leaves the tree.
final _chatsProvider =
    StreamProvider.autoDispose.family<List<ChatModel>, String>(
  (ref, uid) {
    // Watched, not read: blocking someone should take their conversation off
    // the list straight away rather than at the next cold start.
    final blocked =
        ref.watch(currentUserProvider).valueOrNull?.blockedUsers ??
            const <String>[];
    return ref.watch(chatServiceProvider).watchChats(uid, blockedUids: blocked);
  },
);

// ── Screen ─────────────────────────────────────────────────────────────────────

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt when the selected game changes: this tab wears its colour
    // (AppColors.accent).
    ref.watch(activeGameProvider);
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;
    if (myUid == null) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kAmber)),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(myUid: myUid),
            _TabBar(tabCtrl: _tabCtrl, myUid: myUid),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ChatsTab(myUid: myUid),
                  _GroupsTab(myUid: myUid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String myUid;
  const _Header({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(_chatsProvider(myUid)).valueOrNull ?? [];
    final totalUnread = chats.fold<int>(
      0,
      (sum, c) => sum + (c.unreadCount[myUid] ?? 0),
    );

    final hp = context.hPadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, 20, hp - 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages',
                style: AppFonts.ui(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                  height: 1.1,
                ),
              ),
              if (totalUnread > 0)
                Text(
                  '$totalUnread unread',
                  style: AppFonts.ui(
                    fontSize: 12,
                    color: _kInkMute,
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Find someone to message (this button did nothing before).
          _IconBtn(
            icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular),
            onTap: () => context.push('/home/friends/search'),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: PhosphorIcons.usersThree(PhosphorIconsStyle.regular),
            onTap: () => context.push('/home/groups/create'),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _kInkDim, size: 17),
      ),
    );
  }
}

// ── Tab Bar ────────────────────────────────────────────────────────────────────

class _TabBar extends ConsumerWidget {
  final TabController tabCtrl;
  final String myUid;
  const _TabBar({required this.tabCtrl, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(_chatsProvider(myUid)).valueOrNull ?? [];
    final totalUnread = chats.fold<int>(
      0,
      (sum, c) => sum + (c.unreadCount[myUid] ?? 0),
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'chat'.tr(),
            index: 0,
            tabCtrl: tabCtrl,
            badge: totalUnread > 0 ? totalUnread : null,
          ),
          _Tab(
            label: 'groups'.tr(),
            index: 1,
            tabCtrl: tabCtrl,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final TabController tabCtrl;
  final int? badge;

  const _Tab({
    required this.label,
    required this.index,
    required this.tabCtrl,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final selected = tabCtrl.index == index;

    return GestureDetector(
      onTap: () => tabCtrl.animateTo(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? _kAmber : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppFonts.ui(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? _kAmber : _kInkMute,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAmber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge! > 99 ? '99+' : '$badge',
                  style: AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kBg,
                    height: 1.2,
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

// ── Chats Tab ──────────────────────────────────────────────────────────────────

class _ChatsTab extends ConsumerWidget {
  final String myUid;
  const _ChatsTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(_chatsProvider(myUid));

    return chatsAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: _kAmber)),
      error: (_, __) => _emptyState(),
      data: (chats) {
        if (chats.isEmpty) return _emptyState();
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (_, i) => _ChatTile(chat: chats[i], myUid: myUid),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
            size: 52,
            color: _kInkMute,
          ),
          const SizedBox(height: 16),
          Text(
            'no_messages_yet'.tr(),
            style: AppFonts.ui(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _kInkDim,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visit a profile to start a conversation',
            style: AppFonts.ui(fontSize: 13, color: _kInkMute),
          ),
        ],
      ),
    );
  }
}

// ── Chat Tile ──────────────────────────────────────────────────────────────────

class _ChatTile extends ConsumerWidget {
  final ChatModel chat;
  final String myUid;
  const _ChatTile({required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUid = chat.participants.firstWhere(
      (id) => id != myUid,
      orElse: () => '',
    );
    final unread = chat.unreadCount[myUid] ?? 0;
    final hasUnread = unread > 0;

    final user = ref.watch(userOnceProvider(otherUid)).valueOrNull;
    return Builder(
      builder: (context) {
        final username = user?.username ?? otherUid;
        final isOnline = user?.lastSeen != null &&
            DateTime.now().difference(user!.lastSeen!).inMinutes < 5;

        return GestureDetector(
          onTap: () => context.push('/home/chat/$otherUid'),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Avatar with online dot
                _AvatarWithDot(
                  username: username,
                  photoUrl: user?.photoUrl,
                  size: 48,
                  isOnline: isOnline,
                ),
                const SizedBox(width: 12),
                // Name + last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: AppFonts.ui(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chat.lastMessage ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.ui(
                          fontSize: 12.5,
                          color: _kInkMute,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Time + unread badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chat.lastMessageAt != null)
                      Text(
                        _formatTime(chat.lastMessageAt!),
                        style: AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                          color: hasUnread ? _kAmber : _kInkMute,
                        ),
                      ),
                    if (hasUnread) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _kAmber,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _kBg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return DateFormat('HH:mm').format(dt);
    final yesterday = today.subtract(const Duration(days: 1));
    if (msgDay == yesterday) return 'Yesterday';
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}

// ── Avatar With Online Dot ─────────────────────────────────────────────────────

class _AvatarWithDot extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final double size;
  final bool isOnline;

  const _AvatarWithDot({
    required this.username,
    required this.size,
    this.photoUrl,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _SquircleAvatar(
          username: username,
          photoUrl: photoUrl,
          size: size,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _kWin,
                shape: BoxShape.circle,
                border: Border.all(color: _kBg, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Squircle Avatar ────────────────────────────────────────────────────────────

class _SquircleAvatar extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final double size;

  const _SquircleAvatar({
    required this.username,
    required this.size,
    this.photoUrl,
  });

  // Deterministic gradient per user based on first char
  LinearGradient _gradient(String username) {
    final code = username.isNotEmpty ? username.codeUnitAt(0) : 65;
    final hue = (code * 37.0) % 360.0;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1, hue, 0.55, 0.58).toColor(),
        HSLColor.fromAHSL(1, (hue + 30) % 360, 0.65, 0.38).toColor(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 3);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: UserAvatar(
          username: username,
          photoUrl: photoUrl,
          size: size,
          squircle: true,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _gradient(username),
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          initial,
          style: AppFonts.ui(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ── Groups Tab ─────────────────────────────────────────────────────────────────

class _GroupsTab extends ConsumerWidget {
  final String myUid;
  const _GroupsTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KeyedStreamBuilder<List<GroupModel>>(
      cacheKey: myUid,
      create: () => ref.read(groupServiceProvider).watchMyGroups(myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _kAmber));
        }
        final groups = snap.data ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIcons.usersThree(PhosphorIconsStyle.regular),
                  size: 52,
                  color: _kInkMute,
                ),
                const SizedBox(height: 16),
                Text(
                  'No groups yet',
                  style: AppFonts.ui(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kInkDim,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create or join a group to get started',
                  style: AppFonts.ui(fontSize: 13, color: _kInkMute),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => context.push('/home/groups/create'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kAmberGlow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kAmber, width: 1),
                    ),
                    child: Text(
                      'create_group'.tr(),
                      style: AppFonts.ui(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kAmber,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (_, i) => _GroupTile(group: groups[i], myUid: myUid),
        );
      },
    );
  }
}

// ── Group Tile ─────────────────────────────────────────────────────────────────

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final String myUid;
  const _GroupTile({required this.group, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final unread = group.unreadFor(myUid);
    final hasUnread = unread > 0;

    Widget avatar;
    if (group.photoUrl != null && group.photoUrl!.isNotEmpty) {
      avatar = _SquircleAvatar(
        username: group.name,
        photoUrl: group.photoUrl,
        size: 48,
      );
    } else {
      avatar = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _kAmberGlow,
          borderRadius: BorderRadius.circular(48 / 3),
        ),
        child: Center(
          child: Text(
            group.avatarEmoji,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/home/groups/${group.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppFonts.ui(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group.lastMessage ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.ui(
                      fontSize: 12.5,
                      color: _kInkMute,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (group.lastMessageAt != null)
                  Text(
                    _formatTime(group.lastMessageAt!),
                    style: AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                      color: hasUnread ? _kAmber : _kInkMute,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _kBg,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return DateFormat('HH:mm').format(dt);
    final yesterday = today.subtract(const Duration(days: 1));
    if (msgDay == yesterday) return 'Yesterday';
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/group_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/models/group_model.dart';
import '../../../core/widgets/user_avatar.dart';

/// Live user stream for message bubble avatars — auto-disposes per sender.
final _senderPhotoProvider =
    StreamProvider.autoDispose.family<UserModel?, String>((ref, uid) {
  return ref.read(firestoreServiceProvider).watchUser(uid);
});

class GroupScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  GroupMessage? _replyTo;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  Future<void> _changeGroupPhoto() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await ref
          .read(photoServiceProvider)
          .pickAndUploadGroupPhoto(widget.groupId);
      if (url != null) {
        await ref
            .read(groupServiceProvider)
            .updateGroupPhoto(widget.groupId, url);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _setReply(GroupMessage msg) {
    setState(() => _replyTo = msg);
  }

  void _cancelReply() {
    setState(() => _replyTo = null);
  }

  Future<void> _sendMessage(GroupModel group) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;

    final reply = _replyTo;
    _cancelReply();

    await ref.read(groupServiceProvider).sendMessage(
          groupId: widget.groupId,
          senderUid: me.uid,
          senderUsername: me.username,
          text: text,
          memberIds: group.memberIds,
          replyToId: reply?.id,
          replyToText: reply?.text,
          replyToSenderName: reply?.senderUid == me.uid
              ? 'You'
              : reply?.senderUsername,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleMute(GroupModel group, String myUid) async {
    final svc = ref.read(groupServiceProvider);
    if (group.isMuted(myUid)) {
      await svc.unmuteGroup(widget.groupId, myUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Group unmuted'),
              duration: Duration(seconds: 2)),
        );
      }
    } else {
      await svc.muteGroup(widget.groupId, myUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Group muted'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  void _showMessageMenu(
    BuildContext context,
    GroupMessage msg,
    bool isMe,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.reply_rounded, color: AppColors.primary),
              title: Text('reply'.tr(), style: AppTextStyles.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                _setReply(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded,
                  color: AppColors.textSecondary),
              title: Text('copy'.tr(), style: AppTextStyles.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('copied'.tr()),
                      duration: const Duration(seconds: 2)),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid ?? '';

    return StreamBuilder<GroupModel?>(
      stream: ref.read(groupServiceProvider).watchGroup(widget.groupId),
      builder: (context, groupSnap) {
        final group = groupSnap.data;
        final isAdmin = group?.isAdmin(myUid) ?? false;
        final canSend = group?.whoCanSend == 'everyone' || isAdmin;

        // Reset unread counter whenever this screen is visible and group loads
        if (group != null && myUid.isNotEmpty && group.unreadFor(myUid) > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(groupServiceProvider).markGroupRead(widget.groupId, myUid);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                            color: AppColors.inkDim, size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (group != null) ...[
                        GestureDetector(
                          onTap: _changeGroupPhoto,
                          child: Stack(
                            children: [
                              _GroupAvatar(group: group, size: 34),
                              if (_uploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              group?.name ?? 'Group',
                              style: GoogleFonts.fraunces(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (group != null)
                              Text(
                                '${group.memberCount} members',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (group != null)
                        GestureDetector(
                          onTap: () => _toggleMute(group, myUid),
                          child: Icon(
                            group.isMuted(myUid)
                                ? Icons.notifications_off_outlined
                                : Icons.notifications_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => context.push(
                            '/home/groups/${widget.groupId}/settings'),
                        child: Icon(
                          PhosphorIcons.gear(PhosphorIconsStyle.regular),
                          color: AppColors.textSecondary, size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Custom TabBar ────────────────────────────────────────
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Chat'),
                    Tab(text: 'Members'),
                  ],
                ),
                // ── Body ─────────────────────────────────────────────────
                Expanded(child: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── Chat tab ──────────────────────────────────────────────────
              Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<GroupMessage>>(
                      stream: ref
                          .read(groupServiceProvider)
                          .watchMessages(widget.groupId),
                      builder: (context, snap) {
                        final messages = snap.data ?? [];
                        if (snap.connectionState ==
                                ConnectionState.waiting &&
                            messages.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (messages.isEmpty) {
                          return _EmptyChat(groupId: widget.groupId);
                        }

                        // Mark as read whenever messages update while screen is open.
                        if (myUid.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              ref.read(groupServiceProvider)
                                  .markGroupRead(widget.groupId, myUid);
                            }
                          });
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollCtrl.hasClients &&
                              _scrollCtrl.position.maxScrollExtent >
                                  _scrollCtrl.offset) {
                            _scrollCtrl.jumpTo(
                                _scrollCtrl.position.maxScrollExtent);
                          }
                        });
                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final msg = messages[i];
                            final isMe = msg.senderUid == myUid;
                            final prevSender =
                                i > 0 ? messages[i - 1].senderUid : null;
                            final showSender =
                                !isMe && msg.senderUid != prevSender;

                            // Date separator
                            Widget? separator;
                            if (i == 0) {
                              separator = _DateSeparator(date: msg.createdAt);
                            } else {
                              final prev = messages[i - 1];
                              final d1 = DateTime(msg.createdAt.year,
                                  msg.createdAt.month, msg.createdAt.day);
                              final d2 = DateTime(prev.createdAt.year,
                                  prev.createdAt.month, prev.createdAt.day);
                              if (d1 != d2) {
                                separator =
                                    _DateSeparator(date: msg.createdAt);
                              }
                            }

                            return Column(
                              children: [
                                if (separator != null) separator,
                                Dismissible(
                                  key: ValueKey('group_dismiss_${msg.id}'),
                                  direction: DismissDirection.startToEnd,
                                  confirmDismiss: (_) async {
                                    _setReply(msg);
                                    return false;
                                  },
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 16),
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    child: const Icon(Icons.reply_rounded,
                                        color: AppColors.primary),
                                  ),
                                  child: GestureDetector(
                                    onLongPress: () => _showMessageMenu(
                                        context, msg, isMe),
                                    child: _GroupChatBubble(
                                      message: msg,
                                      isMe: isMe,
                                      showSender: showSender,
                                      group: group,
                                      myUid: myUid,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Reply bar
                  if (_replyTo != null)
                    _GroupReplyBar(
                      replyTo: _replyTo!,
                      myUid: myUid,
                      onCancel: _cancelReply,
                    ),
                  // Input area
                  if (group != null && canSend)
                    _GroupInputBar(
                      ctrl: _msgCtrl,
                      onSend: () => _sendMessage(group),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        border: Border(
                            top: BorderSide(
                                color: context.appColors.divider)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Text(
                          'Only admins can send messages',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textHint),
                        ),
                      ),
                    ),
                ],
              ),
              // ── Members tab ───────────────────────────────────────────────
              group == null
                  ? const Center(child: CircularProgressIndicator())
                  : _MembersTab(
                      group: group,
                      myUid: myUid,
                      groupId: widget.groupId,
                    ),
            ],
          )),            // close TabBarView + Expanded
              ],         // close Column children
            ),           // close Column
          ),             // close SafeArea
        );               // close Scaffold
      },
    );
  }
}

// ── Empty Chat State ──────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String groupId;
  const _EmptyChat({required this.groupId});

  static const _prompts = [
    '👋 Salam',
    '♟ Anyone up for 5+0?',
    '🏆 Tonight\'s arena?',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Icon circle
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                    size: 32,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Break the silence',
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: AppColors.ink,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to say hi. Share a game, drop a puzzle, or just say salam.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.inkMute,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Quick-prompt chips
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: _prompts.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  p,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.inkDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Separator ────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    String label;
    if (dateDay == today) {
      label = 'Today';
    } else if (dateDay == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, y').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              child:
                  Divider(color: AppColors.textHint.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          Expanded(
              child:
                  Divider(color: AppColors.textHint.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

// ── Group Reply Bar ───────────────────────────────────────────────────────────

class _GroupReplyBar extends StatelessWidget {
  final GroupMessage replyTo;
  final String myUid;
  final VoidCallback onCancel;

  const _GroupReplyBar({
    required this.replyTo,
    required this.myUid,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final senderLabel =
        replyTo.senderUid == myUid ? 'You' : replyTo.senderUsername;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(
          left: const BorderSide(color: AppColors.primary, width: 3),
          top: BorderSide(color: context.appColors.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyTo.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textHint),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ── Group Chat Bubble ─────────────────────────────────────────────────────────

enum _GroupTickStatus { delivered, read }

class _GroupChatBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;
  final bool showSender;
  final GroupModel? group;
  final String? myUid;

  const _GroupChatBubble({
    required this.message,
    required this.isMe,
    this.showSender = true,
    this.group,
    this.myUid,
  });

  _GroupTickStatus _tickStatus() {
    if (group == null || myUid == null) return _GroupTickStatus.delivered;
    // All other members must have lastReadAt >= message.createdAt
    final otherMembers =
        group!.memberIds.where((id) => id != myUid).toList();
    if (otherMembers.isEmpty) return _GroupTickStatus.delivered;
    final allRead = otherMembers.every((uid) {
      final readAt = group!.lastReadAt[uid];
      return readAt != null && !readAt.isBefore(message.createdAt);
    });
    return allRead ? _GroupTickStatus.read : _GroupTickStatus.delivered;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _AvatarBubble(
              senderUid: message.senderUid,
              username: message.senderUsername,
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && showSender)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(
                    message.senderUsername,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.62),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          begin: Alignment(0.0, -1.0),
                          end: Alignment(1.0, 1.0),
                          colors: [AppColors.amber, AppColors.amberDeep],
                        )
                      : null,
                  color: isMe ? null : AppColors.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMe ? 14 : 2),
                    bottomRight: Radius.circular(isMe ? 2 : 14),
                  ),
                  border: isMe ? null : Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply quote
                    if (message.hasReply) ...[
                      Container(
                        padding: const EdgeInsets.all(7),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe ? Colors.white : AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.replyToSenderName ?? '',
                              style: AppTextStyles.labelSmall.copyWith(
                                color:
                                    isMe ? Colors.white : AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.replyToText ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            message.text,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isMe
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textHint,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          _GroupTickWidget(status: _tickStatus()),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _AvatarBubble extends ConsumerWidget {
  final String senderUid;
  final String username;
  const _AvatarBubble({required this.senderUid, required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_senderPhotoProvider(senderUid));
    return UserAvatar(
      username: username,
      photoUrl: userAsync.valueOrNull?.photoUrl,
      size: 30,
    );
  }
}

class _GroupTickWidget extends StatelessWidget {
  final _GroupTickStatus status;
  const _GroupTickWidget({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _GroupTickStatus.delivered:
        return Icon(Icons.done_rounded,
            size: 13, color: Colors.white.withValues(alpha: 0.55));
      case _GroupTickStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 13, color: Color(0xFF53BDEB));
    }
  }
}

/// Group avatar: shows photo if available, otherwise the emoji icon.
class _GroupAvatar extends StatelessWidget {
  final GroupModel group;
  final double size;
  const _GroupAvatar({required this.group, required this.size});

  @override
  Widget build(BuildContext context) {
    if (group.photoUrl != null && group.photoUrl!.isNotEmpty) {
      return UserAvatar(
        username: group.name,
        photoUrl: group.photoUrl,
        size: size,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          group.avatarEmoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}

// ── Group Input Bar ───────────────────────────────────────────────────────────

class _GroupInputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;

  const _GroupInputBar({required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(top: BorderSide(color: context.appColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: ctrl,
                  style: AppTextStyles.bodySmall,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'message_placeholder'.tr(),
                    hintStyle:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                    filled: true,
                    fillColor: context.appColors.card,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Members Tab ───────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final GroupModel group;
  final String myUid;
  final String groupId;

  const _MembersTab({
    required this.group,
    required this.myUid,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = group.isAdmin(myUid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.push('/home/groups/$groupId/settings'),
              icon: const Icon(Icons.person_add_alt_1_outlined,
                  color: AppColors.primary, size: 18),
              label: Text(
                'Add Member',
                style:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        Text(
          'MEMBERS (${group.memberCount})',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textHint,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...group.memberIds.map(
          (uid) => _MemberTile(
            uid: uid,
            group: group,
            myUid: myUid,
            groupId: groupId,
            isAdmin: isAdmin,
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final String uid;
  final GroupModel group;
  final String myUid;
  final String groupId;
  final bool isAdmin;

  const _MemberTile({
    required this.uid,
    required this.group,
    required this.myUid,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMemberAdmin = group.isAdmin(uid);
    final isSelf = uid == myUid;

    return FutureBuilder(
      future: ref.read(firestoreServiceProvider).getUser(uid),
      builder: (context, snap) {
        final user = snap.data;
        final username = user?.username ?? 'CheckMate User';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: UserAvatar(
            username: username,
            photoUrl: user?.photoUrl,
            size: 40,
          ),
          title: Row(
            children: [
              Text(username, style: AppTextStyles.bodyMedium),
              if (isMemberAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Admin',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: isSelf
              ? Text('You',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textHint))
              : null,
          trailing: isAdmin && !isSelf
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textHint, size: 18),
                  color: AppColors.cardElevated,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    final svc = ref.read(groupServiceProvider);
                    switch (val) {
                      case 'make_admin':
                        await svc.addAdmin(groupId, uid);
                        break;
                      case 'remove_admin':
                        await svc.removeAdmin(groupId, uid);
                        break;
                      case 'remove':
                        await svc.removeMember(groupId, uid);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isMemberAdmin)
                      PopupMenuItem(
                        value: 'make_admin',
                        child: Text('make_admin'.tr()),
                      ),
                    if (isMemberAdmin)
                      PopupMenuItem(
                        value: 'remove_admin',
                        child: Text('remove_admin'.tr()),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Remove from group',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

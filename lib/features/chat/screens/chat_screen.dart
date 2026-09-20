import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/friends_service.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/content_filter.dart';
import '../../../core/widgets/user_avatar.dart';

// ── Design tokens (local) ──────────────────────────────────────────────────────
const _kBg           = AppColors.background;
const _kSurface      = AppColors.surface;
const _kCard         = AppColors.card;
const _kAmber        = AppColors.amber;
const _kAmberDeep    = AppColors.amberDeep;
const _kAmberGlow    = AppColors.amberGlow;
const _kWin          = AppColors.win;
const _kInk          = AppColors.ink;
const _kInkDim       = AppColors.inkDim;
const _kInkMute      = AppColors.inkMute;
const _kBorder       = AppColors.border;
const _kBorderStrong = AppColors.borderStrong;

// ── Report reasons: stored value → translation key ─────────────────────────────
const Map<String, String> _kReportReasons = {
  'spam': 'report_reason_spam',
  'harassment': 'report_reason_harassment',
  'inappropriate': 'report_reason_inappropriate',
  'cheating': 'report_reason_cheating',
  'other': 'report_reason_other',
};

// ── Screen ─────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUid;
  const ChatScreen({super.key, required this.otherUid});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _otherUsername;
  String? _otherPhotoUrl;
  UserModel? _otherUser;
  StreamSubscription<UserModel?>? _otherUserSub;

  late final String _myUid;
  late final String _chatId;

  late final Stream<List<ChatMessageModel>> _messagesStream;
  late final Stream<bool> _typingStream;

  Timer? _typingTimer;
  bool _isTyping = false;

  ChatMessageModel? _replyTo;

  ChatModel? _chatMeta;
  StreamSubscription<ChatModel?>? _chatMetaSub;

  bool _isMuted = false;
  StreamSubscription<bool>? _muteSub;

  // ── Pagination state ───────────────────────────────────────────────────────
  final List<ChatMessageModel> _olderMessages = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  DateTime? _oldestDate; // createdAt of the oldest loaded message (stream or fetched)

  // ── Send-in-progress guard ─────────────────────────────────────────────────
  // Prevents the send button from being tapped while a Firestore write is
  // in flight.  This is the UI-layer companion to the service-layer guard;
  // together they ensure no message is ever silently dropped.
  bool _isSending = false;

  // ── Reply-scroll state ─────────────────────────────────────────────────────
  // One GlobalKey per message id — lets us locate any bubble in the tree so
  // Scrollable.ensureVisible can scroll to it when the user taps a reply quote.
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedId; // id of the message currently being highlighted

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _myUid = ref.read(currentUserProvider).valueOrNull?.uid ?? '';
    _chatId = ChatModel.chatId(_myUid, widget.otherUid);

    _messagesStream = ref.read(chatServiceProvider).watchMessages(_chatId);
    _typingStream =
        ref.read(chatServiceProvider).watchTyping(_chatId, widget.otherUid);

    _scrollCtrl.addListener(_onScroll);
    _listenOtherUser();
    _markRead();
    _markDelivered();
    _listenMute();
    _listenChatMeta();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markRead();
  }

  void _listenOtherUser() {
    _otherUserSub = ref
        .read(firestoreServiceProvider)
        .watchUser(widget.otherUid)
        .listen((user) {
      if (mounted) {
        setState(() {
          _otherUser = user;
          _otherUsername = (user?.blockedUsers.contains(_myUid) == true)
              ? 'Chess User'
              : (user?.username ?? 'CheckMate User');
          _otherPhotoUrl = user?.photoUrl;
        });
      }
    });
  }

  Future<void> _markRead() async {
    if (_myUid.isEmpty) return;
    try {
      await ref.read(chatServiceProvider).markAsRead(_chatId, _myUid);
    } catch (_) {
      // Chat document may not exist yet (first-time chat) — safe to ignore.
    }
  }

  Future<void> _markDelivered() async {
    if (_myUid.isEmpty) return;
    try {
      await ref.read(chatServiceProvider).markDelivered(_chatId, _myUid);
    } catch (_) {
      // Chat document may not exist yet (first-time chat) — safe to ignore.
    }
  }

  void _listenChatMeta() {
    if (_myUid.isEmpty) return;
    _chatMetaSub =
        ref.read(chatServiceProvider).watchChatMeta(_chatId).listen((meta) {
      if (mounted) setState(() => _chatMeta = meta);
    });
  }

  void _listenMute() {
    if (_myUid.isEmpty) return;
    _muteSub = ref
        .read(chatServiceProvider)
        .watchMuted(_chatId, _myUid)
        .listen((v) {
      if (mounted) setState(() => _isMuted = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _chatMetaSub?.cancel();
    _muteSub?.cancel();
    _otherUserSub?.cancel();
    try {
      _clearTyping();
    } catch (_) {}
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (_myUid.isEmpty) return;
    if (text.isEmpty) {
      _clearTypingImmediate();
      return;
    }
    if (!_isTyping) {
      _isTyping = true;
      ref.read(chatServiceProvider).setTyping(_chatId, _myUid, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _clearTypingImmediate);
  }

  void _clearTyping() {
    if (_myUid.isEmpty) return;
    _clearTypingImmediate();
  }

  void _clearTypingImmediate() {
    if (_isTyping) {
      _isTyping = false;
      ref.read(chatServiceProvider).setTyping(_chatId, _myUid, false);
    }
    _typingTimer?.cancel();
  }

  void _setReply(ChatMessageModel msg) => setState(() => _replyTo = msg);
  void _cancelReply() => setState(() => _replyTo = null);

  Future<void> _toggleMute() async {
    if (_myUid.isEmpty) return;
    final svc = ref.read(chatServiceProvider);
    if (_isMuted) {
      await svc.unmuteChat(_chatId, _myUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat unmuted'), duration: Duration(seconds: 2)),
        );
      }
    } else {
      await svc.muteChat(_chatId, _myUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat muted'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _send() async {
    // UI-level guard: ignore tap if a send is already in flight.
    if (_isSending) return;

    final text = _ctrl.text.trim();
    if (text.isEmpty || _myUid.isEmpty) return;

    // Content filter (client-side fast path — the service rejects too)
    if (!ContentFilter.isClean(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('message_blocked_filter'.tr())),
      );
      return;
    }

    // Message privacy check (client-side fast path, before any Firestore write)
    final privacy = _otherUser?.messagePrivacy ?? 'everyone';
    if (privacy == 'nobody') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${_otherUsername ?? 'This user'} is not accepting messages.'),
      ));
      return;
    }
    if (privacy == 'friends') {
      final areFriends = await ref
          .read(friendsServiceProvider)
          .areFriends(_myUid, widget.otherUid);
      if (!mounted) return;
      if (!areFriends) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${_otherUsername ?? 'This user'} only accepts messages from friends.'),
        ));
        return;
      }
    }

    // Lock UI before clearing the field so the button is disabled immediately.
    setState(() => _isSending = true);

    _ctrl.clear();
    _clearTyping();

    final reply = _replyTo;
    _cancelReply();

    try {
      await ref.read(chatServiceProvider).sendMessage(
            myUid: _myUid,
            otherUid: widget.otherUid,
            text: text,
            replyToId: reply?.id,
            replyToText: reply?.text,
            replyToSenderName:
                reply?.senderUid == _myUid ? 'You' : _otherUsername,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
      _markRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
      // Restore the unsent text so the user can retry.
      _ctrl.text = text;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  void _onScroll() {
    // In a reversed ListView, maxScrollExtent is the "top" of the conversation.
    // Trigger load-more when the user scrolls within 300px of the top.
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _oldestDate == null) return;
    setState(() => _loadingMore = true);
    try {
      final older = await ref.read(chatServiceProvider).fetchOlderMessages(
            _chatId,
            before: _oldestDate!,
          );
      if (!mounted) return;
      if (older.isEmpty) {
        _hasMore = false;
      } else {
        _olderMessages.addAll(older);
        _oldestDate = older.last.createdAt; // oldest in this page
      }
    } catch (e) {
      debugPrint('[Chat] loadMore failed: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _showMoreSheet(BuildContext context) {
    final me = ref.read(currentUserProvider).valueOrNull;
    final isBlocked = me?.blockedUsers.contains(widget.otherUid) ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
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
                  color: _kInkMute, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                PhosphorIcons.prohibit(PhosphorIconsStyle.regular),
                color: AppColors.error,
              ),
              title: Text(
                isBlocked
                    ? 'Unblock ${_otherUsername ?? 'user'}'
                    : 'Block ${_otherUsername ?? 'user'}',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (_myUid.isEmpty) return;
                final fs = ref.read(firestoreServiceProvider);
                if (isBlocked) {
                  await fs.unblockUser(_myUid, widget.otherUid);
                } else {
                  await fs.blockUser(_myUid, widget.otherUid);
                }
                ref.invalidate(currentUserProvider);
                if (mounted && !isBlocked) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${_otherUsername ?? 'User'} has been blocked.'),
                  ));
                }
              },
            ),
            ListTile(
              leading: Icon(
                PhosphorIcons.flag(PhosphorIconsStyle.regular),
                color: _kAmber,
              ),
              title: Text(
                'report_user'.tr(),
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w500, color: _kInk),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showReportSheet(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Reason picker. Pass [message] to attach a snapshot of the reported
  /// message to the report.
  void _showReportSheet(BuildContext context, {ChatMessageModel? message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
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
                  color: _kInkMute, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'report_sheet_title'.tr(),
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'report_sheet_subtitle'.tr(),
                    style: GoogleFonts.inter(fontSize: 12, color: _kInkMute),
                  ),
                ],
              ),
            ),
            for (final entry in _kReportReasons.entries)
              ListTile(
                title: Text(
                  entry.value.tr(),
                  style: GoogleFonts.inter(fontSize: 14, color: _kInk),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _submitReport(entry.key, message: message);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason,
      {ChatMessageModel? message}) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    final isBlocked = me?.blockedUsers.contains(widget.otherUid) ?? false;
    try {
      await ref.read(firestoreServiceProvider).reportUser(
            reportedUid: widget.otherUid,
            reason: reason,
            chatId: _chatId,
            messageId: message?.id,
            messageText: message?.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('report_submitted'.tr()),
        duration: const Duration(seconds: 5),
        action: isBlocked
            ? null
            : SnackBarAction(
                label: 'block_user'.tr(),
                textColor: _kAmber,
                onPressed: _blockAfterReport,
              ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('report_failed'.tr())),
      );
    }
  }

  Future<void> _blockAfterReport() async {
    // The snackbar can outlive this screen — bail out if it already went away.
    if (_myUid.isEmpty || !mounted) return;
    await ref.read(firestoreServiceProvider).blockUser(_myUid, widget.otherUid);
    ref.invalidate(currentUserProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_otherUsername ?? 'User'} has been blocked.'),
      ));
    }
  }

  void _showMessageMenu(BuildContext context, ChatMessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _kInkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: _kAmber),
              title: Text('reply'.tr(),
                  style: GoogleFonts.inter(fontSize: 14, color: _kInk)),
              onTap: () {
                Navigator.pop(context);
                _setReply(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: _kInkDim),
              title: Text('copy'.tr(),
                  style: GoogleFonts.inter(fontSize: 14, color: _kInk)),
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
            if (!isMe)
              ListTile(
                leading: Icon(PhosphorIcons.flag(PhosphorIconsStyle.regular),
                    color: _kAmber),
                title: Text('report_user'.tr(),
                    style: GoogleFonts.inter(fontSize: 14, color: _kInk)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportSheet(context, message: msg);
                },
              ),
            if (isMe)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text('delete'.tr(),
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(chatServiceProvider).deleteMessage(_chatId, msg.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Scroll to a referenced message ────────────────────────────────────────

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key?.currentContext == null) {
      // The referenced message is not currently built in the viewport
      // (it may be older than the loaded page). Give a subtle haptic so the
      // user knows their tap was registered.
      HapticFeedback.lightImpact();
      return;
    }
    setState(() => _highlightedId = messageId);
    Scrollable.ensureVisible(
      key!.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _myUid;
    final elo = _otherUser?.blitzStats.rating ?? _otherUser?.overallRating;
    // Respect showOnlineStatus and invisibleMode prefs
    final canShowOnline =
        (_otherUser?.showOnlineStatus ?? true) &&
        !(_otherUser?.invisibleMode ?? false);
    final isOnline = canShowOnline &&
        _otherUser?.lastSeen != null &&
        DateTime.now().difference(_otherUser!.lastSeen!).inMinutes < 5;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            _ChatHeader(
              username: _otherUsername ?? '...',
              photoUrl: _otherPhotoUrl,
              isOnline: isOnline,
              elo: elo,
              typingStream: _typingStream,
              inviteDisabled: _otherUser?.challengePrivacy == 'nobody',
              onBack: () => context.pop(),
              onInvite: () {
                if (_otherUser != null) {
                  context.push('/home/invite', extra: _otherUser);
                }
              },
              onProfile: () => context.push('/home/profile/${widget.otherUid}'),
              onMore: () => _showMoreSheet(context),
            ),
            // Messages
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                stream: _messagesStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: _kAmber));
                  }
                  final streamMsgs = snap.data ?? [];

                  // Update oldest-date cursor from the stream (used for pagination)
                  if (streamMsgs.isNotEmpty) {
                    final streamOldest = streamMsgs.last.createdAt;
                    if (_oldestDate == null ||
                        streamOldest.isBefore(_oldestDate!)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _oldestDate = streamOldest);
                      });
                    }
                  }

                  if (streamMsgs.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _markRead();
                    });
                  }

                  // Merge: stream (newest) + fetched older pages, dedup by id
                  final streamIds = streamMsgs.map((m) => m.id).toSet();
                  final filtered = _olderMessages
                      .where((m) => !streamIds.contains(m.id))
                      .toList();
                  final messages = [...streamMsgs, ...filtered];

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'no_messages_yet'.tr(),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: _kInkMute),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    // +1 spacer at bottom (index 0 area handled by reverse),
                    // +1 for load-more / end-of-history indicator at top
                    itemCount: messages.length + 2,
                    itemBuilder: (_, i) {
                      // Spacer at the very bottom of the reversed list
                      if (i == messages.length + 1) {
                        return const SizedBox(height: 8);
                      }
                      // Load-more indicator / end-of-history at the top
                      if (i == messages.length) {
                        if (_loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: _kAmber, strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        if (!_hasMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Beginning of conversation',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: _kInkMute),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      final msg = messages[i];
                      final isMe = msg.senderUid == myUid;
                      final msgKey = _messageKeys.putIfAbsent(
                          msg.id, () => GlobalKey());

                      Widget? separator;
                      if (i < messages.length - 1) {
                        final older = messages[i + 1];
                        final msgDay = DateTime(msg.createdAt.year,
                            msg.createdAt.month, msg.createdAt.day);
                        final olderDay = DateTime(older.createdAt.year,
                            older.createdAt.month, older.createdAt.day);
                        if (msgDay != olderDay) {
                          separator = _DateSeparator(date: msg.createdAt);
                        }
                      } else {
                        separator = _DateSeparator(date: msg.createdAt);
                      }

                      _TickStatus tickStatus = _TickStatus.sent;
                      if (isMe) {
                        final readAt =
                            _chatMeta?.lastReadAt[widget.otherUid];
                        if (readAt != null &&
                            !msg.createdAt.isAfter(readAt)) {
                          tickStatus = _TickStatus.read;
                        }
                      }

                      return Column(
                        children: [
                          if (separator != null) separator,
                          Dismissible(
                            key: ValueKey('dismiss_${msg.id}'),
                            direction: DismissDirection.startToEnd,
                            confirmDismiss: (_) async {
                              _setReply(msg);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 16),
                              color: _kAmberGlow,
                              child: const Icon(Icons.reply_rounded,
                                  color: _kAmber),
                            ),
                            child: GestureDetector(
                              onLongPress: () =>
                                  _showMessageMenu(context, msg, isMe),
                              child: _MessageBubble(
                                key: msgKey,
                                message: msg,
                                isMe: isMe,
                                tickStatus: isMe ? tickStatus : null,
                                highlighted: _highlightedId == msg.id,
                                onReplyTap: msg.replyToId != null
                                    ? () => _scrollToMessage(msg.replyToId!)
                                    : null,
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
              _ReplyBar(
                replyTo: _replyTo!,
                senderLabel:
                    _replyTo!.senderUid == myUid ? 'You' : (_otherUsername ?? ''),
                onCancel: _cancelReply,
              ),
            // Input bar
            _InputBar(
              ctrl: _ctrl,
              onSend: _send,
              onChanged: _onTextChanged,
              isSending: _isSending,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat Header ────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final bool isOnline;
  final int? elo;
  final Stream<bool> typingStream;
  final VoidCallback onBack;
  final VoidCallback onInvite;
  final VoidCallback onProfile;
  final VoidCallback onMore;
  final bool inviteDisabled;

  const _ChatHeader({
    required this.username,
    required this.isOnline,
    required this.typingStream,
    required this.onBack,
    required this.onInvite,
    required this.onProfile,
    required this.onMore,
    this.photoUrl,
    this.elo,
    this.inviteDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kInkDim, size: 20),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          // Avatar + name + status — entire area tappable for profile
          Expanded(
            child: GestureDetector(
              onTap: onProfile,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      UserAvatar(
                        username: username,
                        photoUrl: photoUrl,
                        size: 38,
                        squircle: true,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _kWin,
                              shape: BoxShape.circle,
                              border: Border.all(color: _kBg, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Name + status
                  Expanded(
                    child: StreamBuilder<bool>(
                      stream: typingStream,
                      builder: (_, snap) {
                        final typing = snap.data ?? false;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              username,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _kInk,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (typing)
                              Text(
                                'typing…',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: _kAmber),
                              )
                            else
                              Text(
                                isOnline
                                    ? 'Online${elo != null ? ' · $elo ELO' : ''}'
                                    : elo != null
                                        ? '$elo ELO'
                                        : '',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isOnline ? _kWin : _kInkMute,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Invite chip
          AbsorbPointer(
            absorbing: inviteDisabled,
            child: Opacity(
              opacity: inviteDisabled ? 0.4 : 1.0,
              child: GestureDetector(
                onTap: onInvite,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kAmberGlow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kAmber, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                        color: _kAmber,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Invite',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // More (block) menu
          IconButton(
            icon: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
                color: _kInkMute, size: 20),
            onPressed: onMore,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Tick Status ───────────────────────────────────────────────────────────────

enum _TickStatus { sent, read }

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
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _kInkMute,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reply Bar ─────────────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  final ChatMessageModel replyTo;
  final String senderLabel;
  final VoidCallback onCancel;

  const _ReplyBar({
    required this.replyTo,
    required this.senderLabel,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(
          left: BorderSide(color: _kAmber, width: 3),
          top: BorderSide(color: _kBorder),
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
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kAmber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyTo.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: _kInkDim),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: _kInkMute),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final _TickStatus? tickStatus;
  final bool highlighted;
  final VoidCallback? onReplyTap;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.tickStatus,
    this.highlighted = false,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    // AnimatedContainer covers the full row width so the amber flash looks like
    // the WhatsApp-style highlight (the bubble itself stays unchanged).
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: highlighted
          ? _kAmber.withValues(alpha: 0.12)
          : Colors.transparent,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          begin: Alignment(0.0, -1.0),
                          end: Alignment(1.0, 1.0),
                          colors: [_kAmber, _kAmberDeep],
                        )
                      : null,
                  color: isMe ? null : _kCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMe ? 14 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 14),
                  ),
                  border: isMe ? null : Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply quote — tapping it scrolls to the original message
                    if (message.hasReply) ...[
                      GestureDetector(
                        onTap: onReplyTap,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.black.withValues(alpha: 0.15)
                                : _kAmberGlow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: isMe ? Colors.black26 : _kAmber,
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
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isMe ? Colors.black54 : _kAmber,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message.replyToText ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isMe ? Colors.black45 : _kInkDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Message text + timestamp
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            message.text,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isMe ? _kBg : _kInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(message.createdAt),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                color: isMe
                                    ? _kBg.withValues(alpha: 0.6)
                                    : _kInkMute,
                              ),
                            ),
                            if (tickStatus != null) ...[
                              const SizedBox(width: 3),
                              _TickWidget(status: tickStatus!, isMe: isMe),
                            ],
                          ],
                        ),
                      ],
                    ),
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

class _TickWidget extends StatelessWidget {
  final _TickStatus status;
  final bool isMe;
  const _TickWidget({required this.status, required this.isMe});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _TickStatus.sent:
        return Icon(Icons.done_rounded,
            size: 13,
            color: isMe ? _kBg.withValues(alpha: 0.5) : _kInkMute);
      case _TickStatus.read:
        return const Icon(Icons.done_all_rounded, size: 13, color: _kAmber);
    }
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final bool isSending;

  const _InputBar({
    required this.ctrl,
    required this.onSend,
    required this.onChanged,
    this.isSending = false,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onCtrlChange);
  }

  void _onCtrlChange() {
    final has = widget.ctrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: _kBg,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Attachment button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.add_rounded, color: _kInkDim, size: 18),
            ),
            const SizedBox(width: 8),
            // Text field
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: widget.ctrl,
                  style: GoogleFonts.inter(fontSize: 13, color: _kInk),
                  onChanged: widget.onChanged,
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  decoration: InputDecoration(
                    hintText: 'message_placeholder'.tr(),
                    hintStyle:
                        GoogleFonts.inter(fontSize: 13, color: _kInkMute),
                    filled: true,
                    fillColor: _kCard,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          const BorderSide(color: _kBorderStrong),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button — dimmed and non-tappable while a send is in flight.
            GestureDetector(
              onTap: widget.isSending ? null : widget.onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (_hasText && !widget.isSending) ? _kAmber : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: (_hasText && !widget.isSending)
                      ? null
                      : Border.all(color: _kBorder),
                  boxShadow: (_hasText && !widget.isSending)
                      ? [
                          BoxShadow(
                            color: _kAmber.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: widget.isSending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          color: _kAmber, strokeWidth: 2),
                      )
                    : Icon(
                        Icons.arrow_forward_rounded,
                        color: _hasText ? _kBg : _kInkMute,
                        size: 18,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

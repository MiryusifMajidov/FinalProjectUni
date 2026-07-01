import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/game_chat_service.dart';

const _quickMessages = [
  'Good luck!',
  'Good game!',
  'Well played!',
  'Thanks!',
  'Nice move!',
  'Rematch?',
];

class GameChatPanel extends ConsumerStatefulWidget {
  final String gameId;
  final VoidCallback onClose;

  const GameChatPanel({
    super.key,
    required this.gameId,
    required this.onClose,
  });

  @override
  ConsumerState<GameChatPanel> createState() => _GameChatPanelState();
}

class _GameChatPanelState extends ConsumerState<GameChatPanel> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage(String text, {bool isQuick = false}) async {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    await ref.read(gameChatServiceProvider).sendMessage(
      gameId: widget.gameId,
      senderUid: me.uid,
      senderUsername: me.username,
      text: text.trim(),
      isQuick: isQuick,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid ?? '';

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(
            left: BorderSide(color: context.appColors.divider, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: context.appColors.divider)),
            ),
            child: Row(
              children: [
                Icon(
                    PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
                    color: AppColors.primary,
                    size: 20),
                const SizedBox(width: 8),
                Text('chat'.tr(), style: AppTextStyles.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: StreamBuilder<List<GameChatMessage>>(
              stream: ref
                  .read(gameChatServiceProvider)
                  .watchMessages(widget.gameId),
              builder: (context, snap) {
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say something!',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint),
                    ),
                  );
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderUid == myUid;
                    return _ChatBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Quick messages
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _quickMessages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () =>
                    _sendMessage(_quickMessages[i], isQuick: true),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.appColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appColors.divider),
                  ),
                  child: Text(_quickMessages[i],
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Input
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: AppTextStyles.bodySmall,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint),
                      filled: true,
                      fillColor: context.appColors.card,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _sendMessage(_ctrl.text),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final GameChatMessage message;
  final bool isMe;
  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(message.senderUsername,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textHint)),
            ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : context.appColors.card,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 12),
              ),
            ),
            child: Text(
              message.text,
              style: AppTextStyles.bodySmall.copyWith(
                color: isMe ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

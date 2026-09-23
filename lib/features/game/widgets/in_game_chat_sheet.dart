import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg          = Color(0xFF0A0A0B);
const _kCard        = Color(0xFF1A1A1E);
const _kAmber       = Color(0xFFE8B960);
const _kInk         = Color(0xFFF5F3EF);
const _kInkDim      = Color(0xFFB0A898);
const _kInkMute     = Color(0xFF706860);
const _kBorder      = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);

const _quickChats = [
  'Good luck!', 'Good game!', 'Well played!', 'Thanks!', 'Nice move'
];

class _ChatMessage {
  final String text;
  final bool isMe;
  const _ChatMessage({required this.text, required this.isMe});
}

/// In-game chat drawer / bottom sheet.
///
/// Show via [showInGameChat] or embed directly.
class InGameChatSheet extends StatefulWidget {
  final String opponentName;
  const InGameChatSheet({super.key, required this.opponentName});

  @override
  State<InGameChatSheet> createState() => _InGameChatSheetState();
}

class _InGameChatSheetState extends State<InGameChatSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMessage> _messages = [
    const _ChatMessage(text: 'Well played!', isMe: true),
    const _ChatMessage(text: 'Good game!', isMe: false),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isMe: true));
      _ctrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 8),
          Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              color: _kBorderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                  size: 16,
                  color: _kAmber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chat',
                    style: GoogleFonts.fraunces(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    PhosphorIcons.x(PhosphorIconsStyle.regular),
                    size: 16,
                    color: _kInkMute,
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: _kBorder),

          // Messages
          SizedBox(
            height: 200,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                return _buildMessage(msg, i);
              },
            ),
          ),

          // Quick chat chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _quickChats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTap: () => _send(_quickChats[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text(
                      _quickChats[i],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _kInkDim,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input row
          Container(
            color: _kBg,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: _kBorder),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _ctrl,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: _kInk),
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13, color: _kInkMute),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        isDense: true,
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_ctrl.text),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                      size: 16,
                      color: const Color(0xFF1A1205),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg, int i) {
    if (msg.isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: const BoxDecoration(
            color: _kAmber,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1205),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.opponentName,
          style: GoogleFonts.inter(fontSize: 10, color: _kInkMute),
        ),
        const SizedBox(height: 3),
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: _kBorder),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _kInk,
            ),
          ),
        ),
      ],
    );
  }
}

/// Show the in-game chat as a modal bottom sheet.
Future<void> showInGameChat(
  BuildContext context, {
  required String opponentName,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => InGameChatSheet(opponentName: opponentName),
  );
}

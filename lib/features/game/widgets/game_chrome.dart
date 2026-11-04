import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bot_badge.dart';

// Building blocks shared by the chess, checkers and domino game pages, so the
// three games look and behave like one app: the same top bar, the same player
// rows around the board and the same action buttons under it.

// ── Top bar ──────────────────────────────────────────────────────────────────

/// A round icon button in [GameTopBar].
class GameTopBarAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const GameTopBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
}

/// Back button, the game's mode ("VS BOT · CASUAL") over its progress
/// ("Move 12"), and up to two round buttons on the right.
class GameTopBar extends StatelessWidget {
  final String modeLabel;
  final String subLabel;
  final VoidCallback onBack;
  final List<GameTopBarAction> actions;

  const GameTopBar({
    super.key,
    required this.modeLabel,
    required this.subLabel,
    required this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          _RoundButton(
            icon: PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: onBack,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  modeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMute,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.inkDim,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isEmpty)
            // Keeps the title centred when there is nothing on the right.
            const SizedBox(width: 36)
          else
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _RoundButton(
                icon: actions[i].icon,
                tooltip: actions[i].tooltip,
                onTap: actions[i].onTap,
              ),
            ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: Icon(icon, color: AppColors.inkDim, size: 18),
        ),
      ),
    );
  }
}

// ── Player strip ─────────────────────────────────────────────────────────────

/// One player's row above or below the board: avatar (their photo, or the
/// token of the side they play), name, a details line and, at the end, the
/// clock or turn timer. The player to move gets the amber ring.
class GamePlayerStrip extends StatelessWidget {
  final String name;
  final String? photoUrl;

  /// Drawn inside the avatar when there is no photo (a king, a disc, a tile).
  final Widget token;

  /// Light avatar background (the player has the white / light side).
  final bool lightAvatar;
  final bool isActive;

  /// Small widgets on the second line: rating, piece count, captures…
  final List<Widget> details;
  final Widget? trailing;

  /// A computer player: shows the BOT badge after the name.
  final bool isBot;

  const GamePlayerStrip({
    super.key,
    required this.name,
    required this.token,
    required this.isActive,
    this.photoUrl,
    this.lightAvatar = false,
    this.details = const [],
    this.trailing,
    this.isBot = false,
  });

  /// Plain text for [details], in the strip's small style.
  static Widget detail(String text, {Color color = AppColors.inkMute}) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final avatarPx = (38 * MediaQuery.devicePixelRatioOf(context)).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lightAvatar
                  ? const Color(0xFFF5F3EF)
                  : const Color(0xFF1A1310),
              border: Border.all(
                color: isActive ? AppColors.amber : const Color(0xFF3D3530),
                width: isActive ? 2.0 : 1.5,
              ),
              boxShadow: isActive
                  ? const [BoxShadow(color: AppColors.amberGlow, blurRadius: 12)]
                  : null,
            ),
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      // Decode at avatar size, not the uploaded photo's.
                      memCacheWidth: avatarPx,
                      errorWidget: (_, __, ___) => Center(child: token),
                    ),
                  )
                : Center(child: token),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (isBot) ...[
                      const SizedBox(width: 6),
                      const BotBadge(fontSize: 9.5),
                    ],
                  ],
                ),
                if (details.isNotEmpty)
                  Row(
                    children: [
                      for (var i = 0; i < details.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        // The last item may shrink (captured pieces late in
                        // a game); the rest keep their size.
                        if (i == details.length - 1)
                          Flexible(child: details[i])
                        else
                          details[i],
                      ],
                    ],
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// The large clock or turn timer at the end of a [GamePlayerStrip]: amber
/// while that player is to move, red when time is nearly out.
class GameClockText extends StatelessWidget {
  final String text;
  final bool active;
  final bool low;

  const GameClockText(
    this.text, {
    super.key,
    required this.active,
    this.low = false,
  });

  /// "m:ss" for a number of seconds.
  static String seconds(int s) {
    final v = s < 0 ? 0 : s;
    return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: low
            ? AppColors.loss
            : active
                ? AppColors.amber
                : AppColors.inkDim,
        letterSpacing: -0.5,
      ),
    );
  }
}

/// A small spinner for the end of a strip while a bot is thinking.
class GameThinkingIndicator extends StatelessWidget {
  const GameThinkingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.inkMute,
      ),
    );
  }
}

// ── Action row ───────────────────────────────────────────────────────────────

/// One button in [GameActionRow]. A null [onTap] shows it dimmed and
/// disabled — never as a button that silently does nothing.
class GameAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const GameAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
}

/// The row of equal-width actions under the board (Hint, Undo, Resign…).
class GameActionRow extends StatelessWidget {
  final List<GameAction> actions;

  const GameActionRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(child: _ActionButton(action: a)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final GameAction action;
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    final color = action.danger
        ? AppColors.loss.withValues(alpha: 0.85)
        : AppColors.inkDim;
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: action.onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(action.icon, size: 16, color: color),
                const SizedBox(height: 4),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Resign ───────────────────────────────────────────────────────────────────

/// Asks before resigning; true when the player confirmed. Online games warn
/// that leaving counts as a loss; [message] overrides the text (e.g. "White
/// resigns — are you sure?" in pass-and-play).
Future<bool> confirmResign(
  BuildContext context, {
  bool online = false,
  String? message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardElevated,
      title: Text(
        'resign'.tr(),
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      content: Text(
        message ??
            (online ? 'leave_game_warning'.tr() : 'resign_confirm'.tr()),
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkDim),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'cancel'.tr(),
            style: GoogleFonts.inter(color: AppColors.inkDim),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'resign'.tr(),
            style: GoogleFonts.inter(
              color: AppColors.loss,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/widgets/bot_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/moulded.dart';

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

/// Back button, the game's mode ("vs bot · 5+0") over its progress
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
            icon: PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
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
                  style: AppFonts.ui(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMute,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isEmpty)
            // Keeps the title centred when there is nothing on the right.
            const SizedBox(width: 48)
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
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Moulded(
          color: AppColors.card,
          lip: 3,
          semanticLabel: tooltip,
          onTap: onTap,
          child: Icon(icon, color: AppColors.ink, size: 20),
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

  /// Opens this player's profile (tapping the avatar or the name).
  final VoidCallback? onTap;

  /// A labelled bot: the Bot badge follows the name.
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
    this.onTap,
    this.isBot = false,
  });

  /// Plain text for [details], in the strip's small style.
  static Widget detail(String text, {Color color = AppColors.inkMute}) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AppFonts.ui(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 13,
      color: color,
      fontWeight: FontWeight.w500,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final avatarPx = (38 * MediaQuery.devicePixelRatioOf(context)).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: onTap != null,
              hint: onTap != null ? 'view_profile'.tr() : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            lightAvatar
                                ? const Color(0xFFEEF1EC)
                                : AppColors.cardElevated,
                        border: Border.all(
                          color:
                              isActive
                                  ? AppColors.amber
                                  : AppColors.cardElevated,
                          width: isActive ? 2.5 : 1.5,
                        ),
                      ),
                      child:
                          photoUrl != null && photoUrl!.isNotEmpty
                              ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl!,
                                  fit: BoxFit.cover,
                                  // Decode at avatar size, not the uploaded photo's.
                                  memCacheWidth: avatarPx,
                                  errorWidget:
                                      (_, __, ___) => Center(child: token),
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
                                  style: AppFonts.ui(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (isBot) ...[
                                const SizedBox(width: 6),
                                const BotBadge(fontSize: 10.5),
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
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
    final bg =
        low
            ? AppColors.loss
            : active
            ? AppColors.amber
            : AppColors.card;
    final fg = low || active ? AppColors.onAmber : AppColors.inkDim;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppFonts.ui(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: -0.3,
          height: 1.15,
        ),
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

  /// Working (e.g. the engine is looking for a hint): a spinner replaces
  /// the icon and the button cannot be pressed again.
  final bool busy;

  const GameAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.busy = false,
  });
}

/// The row of equal-width actions under the board (Hint, Undo, Resign…).
class GameActionRow extends StatelessWidget {
  final List<GameAction> actions;

  const GameActionRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          for (final a in actions) Expanded(child: _ActionButton(action: a)),
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
    final enabled = action.onTap != null || action.busy;
    final color = action.danger ? AppColors.loss : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Moulded(
          color: AppColors.card,
          radius: 12,
          lip: 3,
          semanticLabel: action.label,
          onTap: action.busy ? null : action.onTap,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              if (action.busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: color,
                  ),
                )
              else
                Icon(action.icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.ui(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
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
    builder:
        (ctx) => AlertDialog(
          title: Text(
            'resign'.tr(),
            style: AppFonts.ui(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          content: Text(
            message ??
                (online ? 'leave_game_warning'.tr() : 'resign_confirm'.tr()),
            style: AppFonts.ui(fontSize: 14, color: AppColors.inkDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'cancel'.tr(),
                style: AppFonts.ui(color: AppColors.inkDim),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'resign'.tr(),
                style: AppFonts.ui(
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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/moulded.dart';
import 'game_icon.dart';

/// The game switcher: three catalin tokens — butterscotch chess, cherry
/// draughts, jade dominoes. The active game's token is filled with its colour;
/// the others are plain surface tokens with the colour on their icon only.
///
/// Uses the [activeGameProvider] so every screen that reads it updates together.
class GameSwitch extends ConsumerWidget {
  /// If non-null, overrides the notifier and calls this instead.
  final ValueChanged<GameType>? onChanged;

  const GameSwitch({super.key, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeGameProvider);

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (final type in GameType.values) ...[
            if (type != GameType.values.first) const SizedBox(width: 8),
            Expanded(
              child: _GameToken(
                type: type,
                selected: type == active,
                onTap: () {
                  if (type == active) return;
                  HapticFeedback.selectionClick();
                  if (onChanged != null) {
                    onChanged!(type);
                  } else {
                    ref.read(activeGameProvider.notifier).select(type);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameToken extends StatelessWidget {
  final GameType type;
  final bool selected;
  final VoidCallback onTap;

  const _GameToken({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = type.accent;
    final ink = selected ? AppColors.onAmber : AppColors.inkDim;
    return Moulded(
      color: selected ? accent : AppColors.card,
      selected: selected,
      radius: 12,
      lip: 3,
      semanticLabel: type.name.tr(),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(
              type: type,
              size: 17,
              color: selected ? AppColors.onAmber : accent,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                type.name.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.ui(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

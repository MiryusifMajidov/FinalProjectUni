import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_type.dart';
import '../theme/app_colors.dart';

/// Three-segment game switcher matching the design's `GameSwitch` component.
/// Sits at the top of Home / Profile / Leaderboard / Arena screens.
///
/// Uses the [activeGameProvider] so every screen that reads it updates together.
class GameSwitch extends ConsumerWidget {
  /// If non-null, overrides the notifier and calls this instead.
  final ValueChanged<GameType>? onChanged;

  const GameSwitch({super.key, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeGameProvider);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: GameType.values.map((type) {
          final selected = type == active;
          final identity = type.identity;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (onChanged != null) {
                  onChanged!(type);
                } else {
                  ref.read(activeGameProvider.notifier).select(type);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected
                      ? identity.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected
                        ? identity.accent.withValues(alpha: 0.25)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        identity.glyph,
                        style: TextStyle(
                          fontSize: 16,
                          color: selected
                              ? identity.accent
                              : AppColors.inkMute,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        identity.name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? identity.accent
                              : AppColors.inkMute,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

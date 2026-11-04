import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The small "BOT" tag next to a computer player's name — in arena
/// standings, in the game's player strip and when matchmaking falls back to
/// a bot. Bots are never passed off as people.
class BotBadge extends StatelessWidget {
  final double fontSize;
  const BotBadge({super.key, this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Bot',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.45, vertical: fontSize * 0.12),
        decoration: BoxDecoration(
          color: AppColors.inkMute.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.inkMute.withValues(alpha: 0.35)),
        ),
        child: Text(
          'BOT',
          style: GoogleFonts.inter(
            fontSize: fontSize,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: AppColors.inkDim,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// The "Bot" tag after a labelled bot's name (`bot_2001` … `bot_2500`, see
/// BotPool.isLabelledUid): in the game strip, at a table, in arena
/// standings, on its profile and in search results.
class BotBadge extends StatelessWidget {
  final double fontSize;
  const BotBadge({super.key, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final label = 'bot'.tr();
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            fontSize * 0.45, fontSize * 0.15, fontSize * 0.55, fontSize * 0.15),
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.circular(fontSize * 0.45),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.robot(PhosphorIconsStyle.bold),
                size: fontSize + 1, color: AppColors.inkDim),
            SizedBox(width: fontSize * 0.3),
            Text(
              label,
              style: AppFonts.ui(
                fontSize: fontSize,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.inkDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

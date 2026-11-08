import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/models/game_type.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/moulded.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../core/widgets/table_pieces.dart';

/// Games that need no account and no network: the three bots and
/// two-players-on-one-phone. Reached from the sign-in screen, so a player
/// who never signs in — or opens the app with no connection — can still play.
class OfflinePlayScreen extends ConsumerWidget {
  const OfflinePlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading:
            context.canPop()
                ? IconButton(
                  tooltip: 'back'.tr(),
                  icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
                  onPressed: () => context.pop(),
                )
                : null,
        automaticallyImplyLeading: false,
        title: Text('play_offline'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            'offline_caption'.tr(),
            style: AppFonts.ui(
              fontSize: 16,
              color: AppColors.inkDim,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          const Center(child: TablePieces(height: 120)),
          const SizedBox(height: 26),
          _Tile(
            type: GameType.chess,
            title: 'chess'.tr(),
            subtitle: '${'vs_bot'.tr()} · ${'bot_tiers'.tr()}',
            onTap: () => context.push('/offline/bot-setup'),
          ),
          const SizedBox(height: 10),
          _Tile(
            type: GameType.checkers,
            title: 'checkers'.tr(),
            subtitle: '${'vs_bot'.tr()} · ${'bot_tiers'.tr()}',
            onTap: () => context.push('/offline/checkers-bot-setup'),
          ),
          const SizedBox(height: 10),
          _Tile(
            type: GameType.domino,
            title: 'domino'.tr(),
            subtitle: 'vs_bot'.tr(),
            onTap: () => context.push('/offline/domino-bot-setup'),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
            title: 'offline_two_players'.tr(),
            subtitle: '${'chess'.tr()}, ${'checkers'.tr()}, ${'domino'.tr()}',
            onTap: () => context.push('/offline/local-setup'),
          ),
          // Signed-in players' bot games are saved like any other game;
          // only a signed-out player's are not.
          if (!signedIn) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    PhosphorIcons.info(PhosphorIconsStyle.regular),
                    size: 16,
                    color: AppColors.inkMute,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'offline_not_saved'.tr(),
                    style: AppFonts.ui(
                      fontSize: 13,
                      color: AppColors.inkMute,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!signedIn) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'offline_sign_in_cta'.tr(),
                    style: AppFonts.ui(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'offline_sign_in_sub'.tr(),
                    style: AppFonts.ui(fontSize: 14, color: AppColors.inkDim),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: Moulded(
                      color: AppColors.amber,
                      onTap:
                          () =>
                              context.canPop()
                                  ? context.pop()
                                  : context.go('/login'),
                      child: Center(
                        child: Text(
                          'sign_in'.tr(),
                          style: AppFonts.ui(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onAmber,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final GameType? type;
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    this.type,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = type?.accent ?? AppColors.inkDim;
    return Moulded(
      color: AppColors.card,
      radius: 14,
      semanticLabel: '$title, $subtitle',
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: type == null ? AppColors.cardElevated : accent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child:
                type != null
                    ? GameIcon(type: type!, size: 24, color: AppColors.onAmber)
                    : Icon(icon, size: 24, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(fontSize: 14, color: AppColors.inkMute),
                ),
              ],
            ),
          ),
          Icon(
            PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
            size: 18,
            color: AppColors.inkMute,
          ),
        ],
      ),
    );
  }
}

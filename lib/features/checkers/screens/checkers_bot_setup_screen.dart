import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/moulded.dart';

/// Checkers-specific bot setup.
/// Design-matched to chess BotSetupScreen but with Checkers accent (#6FB4E0)
/// and the 6 Checkers bot tiers from PLAY_META.checkers.botTiers.
class CheckersBotSetupScreen extends StatefulWidget {
  const CheckersBotSetupScreen({super.key});

  @override
  State<CheckersBotSetupScreen> createState() => _CheckersBotSetupScreenState();
}

class _CheckersBotSetupScreenState extends State<CheckersBotSetupScreen> {
  static const _accent = Color(0xFFE2565E);

  int _selectedTier = 0;
  bool _playAsWhite = true;
  int _selectedVariant = 0;

  // (name key, rating, search depth) — the same six level names as chess.
  static const _tiers = [
    ('bot_level_1', 600,  1),
    ('bot_level_2', 1000, 2),
    ('bot_level_3', 1400, 3),
    ('bot_level_4', 1700, 4),
    ('bot_level_5', 2000, 5),
    ('bot_level_6', 2300, 6),
  ];

  // (key, label key, board) — keys match CheckersVariant parsing in the game
  // screen.
  static const _variants = [
    ('standard',      'variant_standard',      '8×8'),
    ('russian',       'variant_russian',       '8×8'),
    ('international', 'variant_international', '10×10'),
    ('turkish',       'variant_turkish',       '8×8'),
    ('brazilian',     'variant_brazilian',     '8×8'),
    ('german',        'variant_german',        '8×8'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
            color: AppColors.ink,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'play_vs_bot'.tr(),
              style: AppFonts.ui(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable options — the Start button stays pinned below.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const SizedBox(height: 20),
              // ── Difficulty ────────────────────────────────────────────
              Text(
                'difficulty'.tr(),
                style: AppFonts.ui(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
              ),
              const SizedBox(height: 10),
              ..._tiers.asMap().entries.map((e) {
                final i = e.key;
                final (name, elo, _) = e.value;
                final selected = i == _selectedTier;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Moulded(
                    color: selected ? _accent : AppColors.card,
                    selected: selected,
                    radius: 14,
                    lip: 3,
                    semanticLabel: '${name.tr()}, ~$elo',
                    onTap: () => setState(() => _selectedTier = i),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Level indicator dots
                        Row(
                          children: List.generate(
                            6,
                            (d) => Container(
                              width: 7, height: 7,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d <= i
                                    ? (selected ? AppColors.onAmber : _accent)
                                    : (selected
                                        ? AppColors.onAmber.withValues(alpha: 0.25)
                                        : AppColors.inkFaint),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          name.tr(),
                          style: AppFonts.ui(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: selected ? AppColors.onAmber : AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '~$elo',
                          style: AppFonts.ui(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.onAmber.withValues(alpha: 0.75)
                                : AppColors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 60 * i))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.05);
              }),

              const SizedBox(height: 24),

              // ── Play as ──────────────────────────────────────────────
              Text(
                'play_as'.tr(),
                style: AppFonts.ui(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _SideButton(
                    label: 'white'.tr(),
                    selected: _playAsWhite,
                    color: const Color(0xFFF5F0E0),
                    accentColor: _accent,
                    onTap: () => setState(() => _playAsWhite = true),
                  ),
                  const SizedBox(width: 10),
                  _SideButton(
                    label: 'black'.tr(),
                    selected: !_playAsWhite,
                    color: const Color(0xFF2A2017),
                    accentColor: _accent,
                    onTap: () => setState(() => _playAsWhite = false),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Variant ──────────────────────────────────────────────
              Text(
                'arena_variant'.tr(),
                style: AppFonts.ui(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _variants.asMap().entries.map((e) {
                  final i = e.key;
                  final (_, labelKey, board) = e.value;
                  final label = '${labelKey.tr()} $board';
                  final selected = i == _selectedVariant;
                  return Moulded(
                    color: selected ? _accent : AppColors.card,
                    selected: selected,
                    radius: 10,
                    lip: 3,
                    semanticLabel: label,
                    onTap: () => setState(() => _selectedVariant = i),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 15),
                    child: Text(
                      label,
                      style: AppFonts.ui(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.onAmber : AppColors.ink,
                      ),
                    ),
                  );
                }).toList(),
              ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Sticky Play button ────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF111915),),
                  child: Text(
                    'start_game'.tr(),
                    style: AppFonts.ui(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111915),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startGame() {
    final (_, elo, depth) = _tiers[_selectedTier];
    final (variantKey, _, _) = _variants[_selectedVariant];
    final gameId = const Uuid().v4();
    context.push('/checkers-game/$gameId', extra: {
      'mode': 'bot',
      'gameType': 'checkers',
      'playerIsWhite': _playAsWhite,
      'botDepth': depth,
      'botRating': elo,
      'isRated': false,
      'myUsername': 'you'.tr(),
      'opponentUsername': 'Bot ($elo)',
      'checkersVariant': variantKey,
    });
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color accentColor;
  final VoidCallback onTap;

  const _SideButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Moulded(
        color: selected ? accentColor : AppColors.card,
        selected: selected,
        radius: 14,
        lip: 3,
        semanticLabel: label,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                    color: Colors.black.withValues(alpha: 0.25), width: 2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppFonts.ui(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onAmber : AppColors.inkDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

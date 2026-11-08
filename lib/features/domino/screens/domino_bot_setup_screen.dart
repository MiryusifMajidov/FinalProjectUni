import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/moulded.dart';

/// Domino game setup — players, ruleset variant (Draw / Block), target score
/// and 2v2 partnership. There is no difficulty tier: the AI always plays its
/// regular strength.
class DominoBotSetupScreen extends StatefulWidget {
  const DominoBotSetupScreen({super.key});

  @override
  State<DominoBotSetupScreen> createState() => _DominoBotSetupScreenState();
}

class _DominoBotSetupScreenState extends State<DominoBotSetupScreen> {
  static const _accent = Color(0xFF4CBF95);
  static const _accentSoft = Color(0x244CBF95);

  int _playerCount = 2;     // 2 or 4
  bool _teams = false;      // 4P only: 2v2 partnership
  String _variant = 'draw'; // 'draw' | 'block'
  int _target = 100;        // 100 / 150 / 200

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

              // ── Players ──────────────────────────────────────────────
              _sectionLabel('domino_players'.tr()),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ChoiceButton(
                    label: 'players_n'.tr(args: ['2']),
                    selected: _playerCount == 2,
                    accent: _accent,
                    onTap: () => setState(() {
                      _playerCount = 2;
                      _teams = false;
                    }),
                  ),
                  const SizedBox(width: 10),
                  _ChoiceButton(
                    label: 'players_n'.tr(args: ['4']),
                    selected: _playerCount == 4,
                    accent: _accent,
                    onTap: () => setState(() => _playerCount = 4),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),

              // ── 4P mode ──────────────────────────────────────────────
              if (_playerCount == 4) ...[
                const SizedBox(height: 24),
                _sectionLabel('domino_table_mode'.tr()),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ChoiceButton(
                      label: 'domino_free_for_all'.tr(),
                      selected: !_teams,
                      accent: _accent,
                      onTap: () => setState(() => _teams = false),
                    ),
                    const SizedBox(width: 10),
                    _ChoiceButton(
                      label: 'domino_teams'.tr(),
                      selected: _teams,
                      accent: _accent,
                      onTap: () => setState(() => _teams = true),
                    ),
                  ],
                ).animate().fadeIn(duration: 250.ms),
              ],

              const SizedBox(height: 24),

              // ── Variant ──────────────────────────────────────────────
              _sectionLabel('domino_ruleset'.tr()),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ChoiceButton(
                    label: 'domino_rules_draw'.tr(),
                    sublabel: 'domino_rules_draw_desc'.tr(),
                    selected: _variant == 'draw',
                    accent: _accent,
                    onTap: () => setState(() => _variant = 'draw'),
                  ),
                  const SizedBox(width: 10),
                  _ChoiceButton(
                    label: 'domino_rules_block'.tr(),
                    sublabel: 'domino_rules_block_desc'.tr(),
                    selected: _variant == 'block',
                    accent: _accent,
                    onTap: () => setState(() => _variant = 'block'),
                  ),
                ],
              ).animate(delay: 60.ms).fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              // ── Target score ─────────────────────────────────────────
              _sectionLabel('domino_match_to'.tr()),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final t in const [100, 150, 200]) ...[
                    if (t != 100) const SizedBox(width: 10),
                    _ChoiceButton(
                      label: '$t',
                      selected: _target == t,
                      accent: _accent,
                      onTap: () => setState(() => _target = t),
                    ),
                  ],
                ],
              ).animate(delay: 120.ms).fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              // Ruleset info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.info(PhosphorIconsStyle.regular),
                      color: _accent, size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'domino_rules_summary'.tr(args: ['$_target']),
                        style: AppFonts.ui(
                          fontSize: 12, color: _accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 180.ms).fadeIn(duration: 300.ms),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Sticky Start button ───────────────────────────────────
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppFonts.ui(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      );

  void _startGame() {
    final gameId = const Uuid().v4();
    context.push('/domino-game/$gameId', extra: {
      'mode': 'bot',
      'gameType': 'domino',
      'playerIsWhite': true,
      'isRated': false,
      'myUsername': 'you'.tr(),
      'opponentUsername': 'bot'.tr(),
      'dominoPlayerCount': _playerCount == 4 ? '4-player' : '2-player',
      'dominoVariant': _variant,
      'dominoTarget': _target,
      'dominoTeams': _teams,
    });
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    this.sublabel,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Moulded(
        color: selected ? accent : AppColors.card,
        selected: selected,
        radius: 14,
        lip: 3,
        semanticLabel: label,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.ui(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onAmber : AppColors.ink,
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 3),
              Text(
                sublabel!,
                textAlign: TextAlign.center,
                style: AppFonts.ui(
                  fontSize: 12,
                  color: selected
                      ? AppColors.onAmber.withValues(alpha: 0.75)
                      : AppColors.inkMute,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

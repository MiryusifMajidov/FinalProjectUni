import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/game_model.dart';
import '../../../core/services/auth_service.dart';

import '../../../core/widgets/game_icon.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/moulded.dart';
// ── Design tokens ─────────────────────────────────────────────────────────────

const _kBg            = AppColors.background;
const _kCard          = AppColors.card;
const _kAmber         = AppColors.amber;
const _kInk           = AppColors.ink;
const _kInkDim        = AppColors.inkDim;
const _kInkMute       = AppColors.inkMute;

// ── Level data ────────────────────────────────────────────────────────────────

class _BotLevel {
  final String name;
  final String description;
  final int elo;
  final double strength;
  /// Piece letter in the cburnett set: P, B, N, R, Q, K (pawn → king).
  final String piece;
  final int tier;
  const _BotLevel(this.name, this.description, this.elo, this.strength, this.piece, this.tier);
}

const _kLevels = [
  // Name and description are translation keys.
  _BotLevel('bot_level_1', 'bot_level_1_desc', 400,  0.07, 'P', 1),
  _BotLevel('bot_level_2', 'bot_level_2_desc', 800,  0.22, 'B', 2),
  _BotLevel('bot_level_3', 'bot_level_3_desc', 1400, 0.42, 'N', 3),
  _BotLevel('bot_level_4', 'bot_level_4_desc', 1800, 0.62, 'R', 4),
  _BotLevel('bot_level_5', 'bot_level_5_desc', 2400, 0.83, 'Q', 5),
  _BotLevel('bot_level_6', 'bot_level_6_desc', 3000, 1.00, 'K', 6),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class BotSetupScreen extends ConsumerStatefulWidget {
  const BotSetupScreen({super.key});

  @override
  ConsumerState<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends ConsumerState<BotSetupScreen> {
  int _levelIndex = 2; // Intermediate
  String _playerColor = 'white';
  TimeControl _timeControl = TimeControls.blitz5;

  _BotLevel get _level => _kLevels[_levelIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // The same plain back arrow as every other app bar.
                  IconButton(
                    tooltip: 'back'.tr(),
                    onPressed: () => context.pop(),
                    icon: Icon(
                      PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                      color: _kInk, size: 22,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'play_vs_bot'.tr(),
                    style: AppFonts.ui(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _HeroCard(level: _level)
                      .animate()
                      .fadeIn(duration: 360.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOut),
                ),

                // 2. Difficulty section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('difficulty'.tr()),
                      const SizedBox(height: 12),
                      _LevelGrid(
                        currentIndex: _levelIndex,
                        onSelect: (i) => setState(() => _levelIndex = i),
                      ).animate(delay: 60.ms).fadeIn(),
                    ],
                  ),
                ),

                // 3. Play as section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('play_as'.tr()),
                      const SizedBox(height: 10),
                      _ColorRow(
                        selected: _playerColor,
                        onSelect: (c) => setState(() => _playerColor = c),
                      ).animate(delay: 110.ms).fadeIn(),
                    ],
                  ),
                ),

                // 4. Time control section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('time_control'.tr()),
                      const SizedBox(height: 10),
                      _TimeGrid(
                        selected: _timeControl,
                        onSelect: (tc) => setState(() => _timeControl = tc),
                      ).animate(delay: 160.ms).fadeIn(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky CTA
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyStartButton(onPressed: _startGame)
                .animate(delay: 200.ms)
                .fadeIn()
                .slideY(begin: 0.2),
          ),
                ],        // close Stack children
              ),          // close Stack
            ),            // close Expanded
          ],              // close Column children
        ),                // close Column
      ),                  // close SafeArea
    );
  }

  void _startGame() async {
    final isWhite = _playerColor == 'random'
        ? DateTime.now().millisecondsSinceEpoch.isEven
        : _playerColor == 'white';

    final user = await readUserQuickly(ref);
    final gameId = const Uuid().v4();
    if (!mounted) return;

    context.push('/game/$gameId', extra: {
      'mode': GameMode.bot.name,
      'timeControl': _timeControl.toMap(),
      'playerIsWhite': isWhite,
      'botRating': _level.elo,
      'isRated': false,
      'myUsername': user?.username ?? 'You',
      'opponentUsername': 'Bot (${_level.elo})',
    });
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppFonts.ui(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _kInk,
        ),
      );
}

// ── Sticky start button ───────────────────────────────────────────────────────

class _StickyStartButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StickyStartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SizedBox(
        height: 60,
        child: Moulded(
          color: _kAmber,
          radius: 14,
          lip: 5,
          semanticLabel: 'start_game'.tr(),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIcons.play(PhosphorIconsStyle.fill),
                    size: 20, color: AppColors.onAmber),
                const SizedBox(width: 10),
                Text(
                  'start_game'.tr(),
                  style: AppFonts.ui(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onAmber,
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

// ── Selected level ────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final _BotLevel level;
  const _HeroCard({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.boardBrown1,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: PieceIcon(
                'b${level.piece}',
                key: ValueKey(level.piece),
                size: 58,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Column(
                key: ValueKey(level.name),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.name.tr(),
                    style: AppFonts.ui(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.description.tr(),
                    style: AppFonts.ui(
                      fontSize: 14,
                      color: _kInkDim,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${'bot_level_selected'.tr(args: ['${level.tier}'])} · ${level.elo} Elo',
                    style: AppFonts.ui(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kAmber,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Level grid ────────────────────────────────────────────────────────────────

class _LevelGrid extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onSelect;
  const _LevelGrid({required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const cols = 3;
      const spacing = 8.0;
      final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(_kLevels.length, (i) {
          final level = _kLevels[i];
          final selected = i == currentIndex;
          final ink = selected ? AppColors.onAmber : _kInk;
          return SizedBox(
            width: itemWidth,
            child: Moulded(
              color: selected ? _kAmber : _kCard,
              selected: selected,
              lip: 3,
              semanticLabel: '${level.name.tr()}, ${level.elo} Elo',
              onTap: () => onSelect(i),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PieceIcon(
                    'b${level.piece}',
                    size: 28,
                    color: selected ? AppColors.onAmber : _kInkDim,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    level.name.tr(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.ui(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(
                    '${level.elo}',
                    style: AppFonts.ui(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.onAmber.withValues(alpha: 0.75)
                          : _kInkMute,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    });
  }
}

// ── Play as — color picker ────────────────────────────────────────────────────

class _ColorRow extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _ColorRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ColorTile(
            value: 'white',
            selected: selected == 'white',
            onTap: () => onSelect('white')),
        const SizedBox(width: 8),
        _ColorTile(
            value: 'random',
            selected: selected == 'random',
            onTap: () => onSelect('random')),
        const SizedBox(width: 8),
        _ColorTile(
            value: 'black',
            selected: selected == 'black',
            onTap: () => onSelect('black')),
      ],
    );
  }
}

class _ColorTile extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _ColorTile(
      {required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = switch (value) {
      'white' => 'white'.tr(),
      'black' => 'black'.tr(),
      _ => 'random_color'.tr(),
    };

    return Expanded(
      child: SizedBox(
        height: 84,
        child: Moulded(
          color: selected ? _kAmber : _kCard,
          selected: selected,
          lip: 3,
          semanticLabel: label,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PieceAvatar(value: value),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppFonts.ui(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.onAmber : _kInkDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieceAvatar extends StatelessWidget {
  final String value;
  const _PieceAvatar({required this.value});

  static const _whiteBase = Color(0xFFECECF2);

  @override
  Widget build(BuildContext context) {
    if (value == 'random') {
      return SizedBox(
        width: 36,
        height: 36,
        child: CustomPaint(painter: _HalfCirclePainter()),
      );
    }

    final isWhite = value == 'white';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Both kings sit on a light disc so the black one stays visible.
        color: isWhite ? _whiteBase : const Color(0xFFB8B4AC),
        border: Border.all(
          color: isWhite
              ? Colors.white.withOpacity(0.3)
              : _kInkMute.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Center(child: PieceIcon(isWhite ? 'wK' : 'bK', size: 24)),
    );
  }
}

class _HalfCirclePainter extends CustomPainter {
  static const _whiteBase = Color(0xFFECECF2);
  static const _darkBase  = Color(0xFF252530);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(rect, math.pi / 2, math.pi, true,
        Paint()..color = _whiteBase);
    canvas.drawArc(rect, -math.pi / 2, math.pi, true,
        Paint()..color = _darkBase);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = _kInkMute.withOpacity(0.3),
    );
  }

  @override
  bool shouldRepaint(_HalfCirclePainter _) => false;
}

// ── Time control ──────────────────────────────────────────────────────────────

class _TimeGrid extends StatelessWidget {
  final TimeControl selected;
  final void Function(TimeControl) onSelect;
  const _TimeGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimeRow(
          icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
          label: 'bullet'.tr(),
          labelColor: AppColors.bullet,
          controls: TimeControls.allBullet,
          selected: selected,
          onSelect: onSelect,
        ),
        const SizedBox(height: 10),
        _TimeRow(
          icon: PhosphorIcons.fire(PhosphorIconsStyle.fill),
          label: 'blitz'.tr(),
          labelColor: AppColors.blitz,
          controls: TimeControls.allBlitz,
          selected: selected,
          onSelect: onSelect,
        ),
        const SizedBox(height: 10),
        _TimeRow(
          icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
          label: 'rapid'.tr(),
          labelColor: AppColors.rapid,
          controls: TimeControls.allRapid,
          selected: selected,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color labelColor;
  final List<TimeControl> controls;
  final TimeControl selected;
  final void Function(TimeControl) onSelect;

  const _TimeRow({
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.controls,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Row(
            children: [
              Icon(icon, size: 15, color: labelColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kInkDim,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controls.map((tc) {
              final sel = selected == tc;
              return Moulded(
                color: sel ? _kAmber : _kCard,
                selected: sel,
                radius: 10,
                lip: 3,
                semanticLabel: tc.label,
                onTap: () => onSelect(tc),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 14,
                ),
                child: Text(
                  tc.label,
                  style: AppFonts.ui(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: sel ? AppColors.onAmber : _kInk,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

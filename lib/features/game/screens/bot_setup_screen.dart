import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/game_model.dart';
import '../../../core/services/auth_service.dart';

import '../../../core/widgets/game_icon.dart';
import '../../../core/utils/text_case.dart';
// ── Design tokens ─────────────────────────────────────────────────────────────

const _kBg            = AppColors.background;
const _kCard          = AppColors.card;
const _kAmber         = AppColors.amber;
const _kAmberDeep     = AppColors.amberDeep;
const _kAmberGlow     = AppColors.amberGlow;
const _kInk           = AppColors.ink;
const _kInkDim        = AppColors.inkDim;
const _kInkMute       = AppColors.inkMute;
const _kBorder        = AppColors.border;

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
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: _kInkDim, size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'play_vs_bot'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: _HeroCard(level: _level)
                      .animate()
                      .fadeIn(duration: 360.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOut),
                ),

                // 2. Difficulty section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('difficulty'.tr()),
                      const SizedBox(height: 10),
                      _LevelGrid(
                        currentIndex: _levelIndex,
                        onSelect: (i) => setState(() => _levelIndex = i),
                      ).animate(delay: 60.ms).fadeIn(),
                    ],
                  ),
                ),

                // 3. Play as section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
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

    final user = await ref.read(currentUserProvider.future);
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
  // One style for every section heading (they were a mix of "Difficulty",
  // "PLAY AS" and "Choose Time Control").
  Widget build(BuildContext context) => Text(
        text.toUpperCaseFor(context),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kInkMute,
          letterSpacing: 1.0,
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBg.withOpacity(0.0), _kBg.withOpacity(0.98)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _kAmber,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kAmberGlow,
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Start game →',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1205),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final _BotLevel level;
  const _HeroCard({required this.level});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment(0.0, -1.0),
          end: Alignment(1.0, 1.0),
          // 135deg
          transform: GradientRotation(135 * math.pi / 180),
          colors: [_kAmber, _kAmberDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _kAmberGlow,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content overlay
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SELECTED · TIER ${level.tier}',
                  style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: const Color(0xFF1A1205).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    level.name.tr(),
                    key: ValueKey(level.name),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1205),
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 260,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    // Default layout centres the child, which indented the
                    // line relative to the title above it.
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, if (current != null) current],
                    ),
                    child: Text(
                      level.description.tr(),
                      key: ValueKey(level.description),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1205).withOpacity(0.72),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${level.elo}',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1205),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ELO',
                      style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1205).withOpacity(0.6),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
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

          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: itemWidth,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: selected ? _kAmberGlow : _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _kAmber : _kBorder,
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PieceIcon(
                    'b${level.piece}',
                    size: 26,
                    color: selected ? _kAmber : _kInkDim,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.name.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${level.elo} ELO',
                    style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
                      color: _kInkMute,
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
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 72,
          decoration: BoxDecoration(
            color: selected ? _kAmberGlow : _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kAmber : _kBorder,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PieceAvatar(value: value),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? _kAmber : _kInkDim,
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
          width: 68,
          child: Row(
            children: [
              Icon(icon, size: 13, color: labelColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: controls.map((tc) {
              final sel = selected == tc;
              return GestureDetector(
                onTap: () => onSelect(tc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 11,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? _kAmberGlow : _kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? _kAmber : _kBorder,
                      width: sel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    tc.label,
                    style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel ? _kAmber : _kInkDim,
                    ),
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

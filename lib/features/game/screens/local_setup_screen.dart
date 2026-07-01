import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/services/auth_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = AppColors.background;
const _kCard      = AppColors.card;
// Per-game accent now from _gameType.identity (no hardcoded amber)
const _kInk       = AppColors.ink;
const _kInkDim    = AppColors.inkDim;
const _kInkMute   = AppColors.inkMute;
const _kBorder    = AppColors.border;

class LocalSetupScreen extends ConsumerStatefulWidget {
  const LocalSetupScreen({super.key});

  @override
  ConsumerState<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends ConsumerState<LocalSetupScreen> {
  final _player1Ctrl = TextEditingController();
  final _player2Ctrl = TextEditingController();
  TimeControl _timeControl = TimeControls.rapid10;
  late GameType _gameType;

  // Per-game rule options (checkers / domino — chess uses the clock instead)
  String _checkersVariant = 'standard';
  String _dominoVariant = 'draw';
  int _dominoTarget = 100;

  @override
  void initState() {
    super.initState();
    _gameType = ref.read(activeGameProvider);
  }

  @override
  void dispose() {
    _player1Ctrl.dispose();
    _player2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    final user = await ref.read(currentUserProvider.future);
    final p1 = _player1Ctrl.text.trim().isEmpty
        ? (user?.username ?? 'Player 1')
        : _player1Ctrl.text.trim();
    final p2 = _player2Ctrl.text.trim().isEmpty ? 'Player 2' : _player2Ctrl.text.trim();
    final gameId = const Uuid().v4();

    if (mounted) {
      context.push(_gameType.gameRoute(gameId), extra: {
        'mode': GameMode.local.name,
        'gameType': _gameType.name,
        // The clock only applies to chess; checkers/domino are untimed locally.
        'timeControl': _gameType == GameType.chess
            ? _timeControl.toMap()
            : TimeControls.none.toMap(),
        'playerIsWhite': true,
        'isRated': false,
        'myUsername': p1,
        'opponentUsername': p2,
        if (_gameType == GameType.checkers)
          'checkersVariant': _checkersVariant,
        if (_gameType == GameType.domino) ...{
          'dominoVariant': _dominoVariant,
          'dominoTarget': _dominoTarget,
          'dominoPlayerCount': '2-player',
        },
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
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
                    'play_with_friend'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 24),
                      child: Text(
                        'same_device_subtitle'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _kInkMute,
                        ),
                      ),
                    ),

                    // ── Player fields ────────────────────────────────────────
                    _PlayerField(
                      controller: _player1Ctrl,
                      pieceSymbol: _gameType == GameType.checkers ? '⛀' : _gameType == GameType.domino ? '🁫' : '♔',
                      colorLabel: _gameType == GameType.checkers ? 'LIGHT' : _gameType == GameType.domino ? 'PLAYER 1' : 'WHITE',
                      hint: 'Player 1 name',
                      accent: _gameType.accent,
                    ),
                    const SizedBox(height: 12),
                    _PlayerField(
                      controller: _player2Ctrl,
                      pieceSymbol: _gameType == GameType.checkers ? '⛂' : _gameType == GameType.domino ? '🁫' : '♚',
                      colorLabel: _gameType == GameType.checkers ? 'DARK' : _gameType == GameType.domino ? 'PLAYER 2' : 'BLACK',
                      hint: 'Player 2 name',
                      accent: _gameType.accent,
                    ),

                    const SizedBox(height: 28),

                    // ── Per-game rules ────────────────────────────────────────
                    // Chess: clock. Checkers: variant. Domino: ruleset + target.
                    if (_gameType == GameType.chess) ...[
                      Text(
                        'choose_time_control'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kInkMute,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TimeSection(
                        icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                        iconColor: const Color(0xFFFF6B6B),
                        label: 'bullet'.tr(),
                        controls: TimeControls.allBullet,
                        selected: _timeControl,
                        onSelect: (tc) => setState(() => _timeControl = tc),
                      ),
                      const SizedBox(height: 14),
                      _TimeSection(
                        icon: PhosphorIcons.flame(PhosphorIconsStyle.fill),
                        iconColor: const Color(0xFFFF9F43),
                        label: 'blitz'.tr(),
                        controls: TimeControls.allBlitz,
                        selected: _timeControl,
                        onSelect: (tc) => setState(() => _timeControl = tc),
                      ),
                      const SizedBox(height: 14),
                      _TimeSection(
                        icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
                        iconColor: const Color(0xFF54A0FF),
                        label: 'rapid'.tr(),
                        controls: TimeControls.allRapid,
                        selected: _timeControl,
                        onSelect: (tc) => setState(() => _timeControl = tc),
                      ),
                    ] else if (_gameType == GameType.checkers) ...[
                      Text(
                        'GAME VARIANT',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kInkMute,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _OptionChips(
                        options: GameTypeX.checkersVariants,
                        selected: _checkersVariant,
                        accent: _gameType.accent,
                        onSelect: (v) =>
                            setState(() => _checkersVariant = v),
                      ),
                    ] else if (_gameType == GameType.domino) ...[
                      Text(
                        'RULESET',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kInkMute,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _OptionChips(
                        options: GameTypeX.dominoVariants,
                        selected: _dominoVariant,
                        accent: _gameType.accent,
                        onSelect: (v) => setState(() => _dominoVariant = v),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'MATCH TO',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kInkMute,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _OptionChips(
                        options: [
                          for (final t in GameTypeX.dominoTargets)
                            ('$t', '$t points'),
                        ],
                        selected: '$_dominoTarget',
                        accent: _gameType.accent,
                        onSelect: (v) => setState(
                            () => _dominoTarget = int.tryParse(v) ?? 100),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Start button (bright accent CTA, like matchmaking) ────
                    GestureDetector(
                      onTap: _startGame,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _gameType.accent,
                              Color.lerp(_gameType.accent, Colors.black, 0.25)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _gameType.accent.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.users(PhosphorIconsStyle.fill),
                                size: 18,
                                color: const Color(0xFF0A0A0B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Start Pass & Play',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0A0A0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Player field ──────────────────────────────────────────────────────────────

class _PlayerField extends StatefulWidget {
  final TextEditingController controller;
  final String pieceSymbol;
  final String colorLabel;
  final String hint;
  final Color accent;

  const _PlayerField({
    required this.controller,
    required this.pieceSymbol,
    required this.colorLabel,
    required this.hint,
    required this.accent,
  });

  @override
  State<_PlayerField> createState() => _PlayerFieldState();
}

class _PlayerFieldState extends State<_PlayerField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(16),
        // Focus is shown on the OUTER card border — the text field inside
        // draws no border of its own (no pill-inside-a-card effect).
        border: Border.all(
          color: focused
              ? widget.accent.withValues(alpha: 0.65)
              : _kBorder.withValues(alpha: 0.55),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar circle with the game piece, tinted in the game accent
          Container(
            margin: const EdgeInsets.all(10),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.pieceSymbol,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),

          // Label + text field
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'PLAYER · ${widget.colorLabel}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _kInkMute,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  style: GoogleFonts.inter(fontSize: 14, color: _kInk),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
                    // Explicitly disable EVERY border variant — the global
                    // input theme defines enabled/focused outlines that would
                    // otherwise draw a second pill outline inside the card.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // Edit icon
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              PhosphorIcons.pencilSimple(PhosphorIconsStyle.regular),
              color: focused ? widget.accent : _kInkMute,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Option chips (checkers variant / domino ruleset & target) ─────────────────

class _OptionChips extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final Color accent;
  final void Function(String) onSelect;

  const _OptionChips({
    required this.options,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSel = opt.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? accent.withValues(alpha: 0.15) : _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? accent : _kBorder,
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt.$2,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                color: isSel ? accent : _kInkDim,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Time section (reusable) ───────────────────────────────────────────────────

class _TimeSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final List<TimeControl> controls;
  final TimeControl selected;
  final void Function(TimeControl) onSelect;

  const _TimeSection({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.controls,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header row
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor.withOpacity(0.35), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        // Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controls.map((tc) {
            final isSel = tc == selected;
            return GestureDetector(
              onTap: () => onSelect(tc),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? iconColor.withOpacity(0.15) : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? iconColor : _kBorder,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  tc.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                    color: isSel ? iconColor : _kInkDim,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

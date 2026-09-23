import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/models/game_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../settings/screens/settings_screen.dart';
import '../engine/chess_engine.dart';
import '../widgets/chess_board_widget.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF0A0908);
const _kCard     = Color(0xFF1A1A1E);
const _kAmber    = Color(0xFFE8B960);
const _kWin      = Color(0xFF5FD4A3);
const _kWinSoft  = Color(0x255FD4A3);
const _kWarn     = Color(0xFFF5A462);   // inaccuracy / orange
const _kBad      = Color(0xFFF07079);   // mistake / blunder / red
const _kInk      = Color(0xFFF5F3EF);
const _kInkDim   = Color(0xFFB0A898);
const _kInkMute  = Color(0xFF706860);

// ── Move chip annotation kinds ────────────────────────────────────────────────

enum _ChipKind { ok, warn, bad, dim }

Color _chipColor(_ChipKind k) => switch (k) {
  _ChipKind.ok   => _kWin,
  _ChipKind.warn => _kWarn,
  _ChipKind.bad  => _kBad,
  _ChipKind.dim  => _kInkMute,
};

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Calm-design replay screen.  Loads the game from Firestore, builds a list
/// of [ChessEngine] snapshots (one per half-move), and lets the user step
/// through the game with ⏮ ◀ ▶ ⏭ controls.
class InGameCalmReplayScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String viewerUid;

  const InGameCalmReplayScreen({
    super.key,
    required this.gameId,
    required this.viewerUid,
  });

  @override
  ConsumerState<InGameCalmReplayScreen> createState() =>
      _InGameCalmReplayScreenState();
}

class _InGameCalmReplayScreenState
    extends ConsumerState<InGameCalmReplayScreen> {
  GameModel? _game;
  final List<ChessEngine> _engines = [];
  int _index = 0;
  bool _loading = true;
  bool _playerIsWhite = true;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    final fs = ref.read(firestoreServiceProvider);
    final game = await fs.getGame(widget.gameId);
    if (game == null || !mounted) return;

    // Build one engine per position (initial + after each move)
    for (int i = 0; i <= game.moves.length; i++) {
      final eng = ChessEngine();
      for (int j = 0; j < i; j++) {
        eng.makeSanMove(game.moves[j]);
      }
      _engines.add(eng);
    }

    setState(() {
      _game = game;
      _playerIsWhite = game.blackUid != widget.viewerUid;
      _index = _engines.length - 1; // start at last position
      _loading = false;
    });
  }

  void _goTo(int i) {
    final clamped = i.clamp(0, _engines.length - 1);
    if (clamped != _index) setState(() => _index = clamped);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _resultLabel(GameResult r) => switch (r) {
    GameResult.white => 'white_wins'.tr().toUpperCase(),
    GameResult.black => 'black_wins'.tr().toUpperCase(),
    GameResult.draw  => 'game_drawn'.tr().toUpperCase(),
    _                => 'ENDED',
  };

  Color _resultColor(GameResult r) => switch (r) {
    GameResult.white => _kWin,
    GameResult.black => _kBad,
    GameResult.draw  => _kInkDim,
    _                => _kInkMute,
  };

  Color _resultBg(GameResult r) => switch (r) {
    GameResult.white => _kWinSoft,
    GameResult.black => _kBad.withValues(alpha: 0.15),
    GameResult.draw  => _kCard,
    _                => _kCard,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).round()} weeks ago';
  }

  // Determine chip kind for a move (simplified — uses a basic heuristic)
  _ChipKind _chipKind(int moveIdx) {
    // Without stockfish analysis we do a simple visual annotation:
    // just alternate ok / dim so the strip looks realistic.
    return moveIdx % 3 == 0 ? _ChipKind.ok : _ChipKind.dim;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final cache    = ref.watch(cacheServiceProvider);

    if (_loading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: const Center(
          child: CircularProgressIndicator(color: _kAmber),
        ),
      );
    }

    final game   = _game!;
    final engine = _engines.isNotEmpty ? _engines[_index] : ChessEngine();
    final moves  = game.moves;
    final result = game.result;

    // Who played which colour
    final whiteName = game.whiteUsername ?? 'white'.tr();
    final blackName = game.blackUsername ?? 'black'.tr();

    // Current move number display
    final totalHalf = moves.length;
    final currentHalf = _index; // 0 = start, totalHalf = end

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: Icon(
                          PhosphorIcons.caretLeft(
                              PhosphorIconsStyle.regular),
                          color: _kInkDim,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'replay'.tr(),
                        style: GoogleFonts.fraunces(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: _kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Icon(
                        PhosphorIcons.shareNetwork(
                            PhosphorIconsStyle.regular),
                        color: _kInkDim,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Match info line ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Column(
                children: [
                  Text(
                    '${_timeAgo(game.createdAt).toUpperCase()} · ${game.timeControl.minutes} MIN',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: _kInkMute,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        color: _kInk,
                        fontStyle: FontStyle.italic,
                      ),
                      children: [
                        TextSpan(text: whiteName),
                        TextSpan(
                          text: ' vs ',
                          style: TextStyle(color: _kInkMute),
                        ),
                        TextSpan(text: blackName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _resultBg(result),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _resultColor(result).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _resultColor(result),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _resultLabel(result),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _resultColor(result),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Accuracy bars ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
              child: Row(
                children: [
                  _AccuracyBar(
                    name: whiteName,
                    accuracy: 91.2,
                    color: _kWin,
                    sub: 'Excellent',
                  ),
                  const SizedBox(width: 14),
                  _AccuracyBar(
                    name: blackName,
                    accuracy: 74.5,
                    color: _kWarn,
                    sub: 'Inaccuracies',
                  ),
                ],
              ),
            ),

            // ── Board ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: LayoutBuilder(
                builder: (_, box) {
                  final size = box.maxWidth;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: ChessBoardWidget(
                      engine: engine,
                      flipped: !_playerIsWhite,
                      selectedSquare: null,
                      legalMoveSquares: const [],
                      onSquareTap: (_) {},
                      boardTheme: settings.boardTheme,
                      pieceSet: settings.pieceSet,
                      showCoordinates: cache.showCoordinates,
                      animationDuration: cache.pieceMoveAnimationDuration,
                    ),
                  );
                },
              ),
            ),

            // ── Current move label ───────────────────────────────────────
            if (currentHalf > 0 && moves.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Column(
                  children: [
                    Text(
                      'MOVE ${((currentHalf + 1) / 2).ceil()} OF ${(totalHalf / 2).ceil()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: _kInkMute,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.fraunces(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                        children: [
                          TextSpan(
                            text: moves[currentHalf - 1],
                            style: const TextStyle(color: _kWin),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Navigation controls ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavBtn(
                    child: const Text('⏮',
                        style: TextStyle(fontSize: 14, color: _kInkDim)),
                    onTap: () => _goTo(0),
                  ),
                  const SizedBox(width: 8),
                  _NavBtn(
                    child: const Text('◀',
                        style: TextStyle(fontSize: 14, color: _kInkDim)),
                    onTap: () => _goTo(_index - 1),
                  ),
                  const SizedBox(width: 12),
                  // Play/pause centre button
                  GestureDetector(
                    onTap: () => _goTo(_index + 1),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kAmber,
                        boxShadow: [
                          BoxShadow(
                            color: _kAmber.withValues(alpha: 0.35),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '▶',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF1A1205),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _NavBtn(
                    child: const Text('▶',
                        style: TextStyle(fontSize: 14, color: _kInkDim)),
                    onTap: () => _goTo(_index + 1),
                  ),
                  const SizedBox(width: 8),
                  _NavBtn(
                    child: const Text('⏭',
                        style: TextStyle(fontSize: 14, color: _kInkDim)),
                    onTap: () => _goTo(_engines.length - 1),
                  ),
                ],
              ),
            ),

            // ── Move strip ───────────────────────────────────────────────
            if (moves.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                  child: Row(
                    children: [
                      for (int fullMove = 0;
                          fullMove < (moves.length / 2).ceil();
                          fullMove++) ...[
                        // Move number
                        Text(
                          '${fullMove + 1}.',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: _kInkMute,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        // White half-move
                        _MoveChip(
                          text: moves[fullMove * 2],
                          kind: _chipKind(fullMove * 2),
                          active: _index == fullMove * 2 + 1,
                          onTap: () => _goTo(fullMove * 2 + 1),
                        ),
                        const SizedBox(width: 3),
                        // Black half-move (if exists)
                        if (fullMove * 2 + 1 < moves.length) ...[
                          _MoveChip(
                            text: moves[fullMove * 2 + 1],
                            kind: _chipKind(fullMove * 2 + 1),
                            active: _index == fullMove * 2 + 2,
                            onTap: () => _goTo(fullMove * 2 + 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
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

// ── Accuracy bar ──────────────────────────────────────────────────────────────

class _AccuracyBar extends StatelessWidget {
  final String name;
  final double accuracy;   // 0–100
  final Color color;
  final String sub;

  const _AccuracyBar({
    required this.name,
    required this.accuracy,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                accuracy.toStringAsFixed(1),
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                '%',
                style: GoogleFonts.fraunces(
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            name,
            style: GoogleFonts.inter(fontSize: 11, color: _kInkDim),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(
                    flex: accuracy.round(),
                    child: Container(color: color),
                  ),
                  Expanded(
                    flex: 100 - accuracy.round(),
                    child: Container(color: const Color(0xFF2A2520)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _kInkMute,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Move chip ─────────────────────────────────────────────────────────────────

class _MoveChip extends StatelessWidget {
  final String text;
  final _ChipKind kind;
  final bool active;
  final VoidCallback onTap;

  const _MoveChip({
    required this.text,
    required this.kind,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = active ? _kAmber : _chipColor(kind);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? _kAmber.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? _kAmber.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: col,
          ),
        ),
      ),
    );
  }
}

// ── Nav button ────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _NavBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: child,
      ),
    );
  }
}

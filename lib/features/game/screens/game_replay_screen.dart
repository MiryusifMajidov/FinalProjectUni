import 'dart:math';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/models/game_model.dart';
import '../engine/chess_engine.dart';
import '../engine/stockfish_service.dart';
import '../widgets/chess_board_widget.dart';

// ── Move annotation enum ───────────────────────────────────────────────────────

enum MoveAnnotation { brilliant, best, excellent, good, inaccuracy, mistake, blunder }

extension MoveAnnotationX on MoveAnnotation {
  String get symbol => switch (this) {
        MoveAnnotation.brilliant  => '!!',
        MoveAnnotation.best       => '★',
        MoveAnnotation.excellent  => '!',
        MoveAnnotation.good       => '',
        MoveAnnotation.inaccuracy => '?',
        MoveAnnotation.mistake    => '??',
        MoveAnnotation.blunder    => '???',
      };

  Color get color => switch (this) {
        MoveAnnotation.brilliant  => const Color(0xFF00CEC9), // firuzəyi — chess.com rəngi
        MoveAnnotation.best       => AppColors.success,
        MoveAnnotation.excellent  => AppColors.success,
        MoveAnnotation.good       => Colors.transparent,
        MoveAnnotation.inaccuracy => AppColors.warning,
        MoveAnnotation.mistake    => const Color(0xFFFF9F43),
        MoveAnnotation.blunder    => AppColors.error,
      };

  String get label => switch (this) {
        MoveAnnotation.brilliant  => 'Brilliant',
        MoveAnnotation.best       => 'Best move',
        MoveAnnotation.excellent  => 'Excellent',
        MoveAnnotation.good       => '',
        MoveAnnotation.inaccuracy => 'Inaccuracy',
        MoveAnnotation.mistake    => 'Mistake',
        MoveAnnotation.blunder    => 'Blunder',
      };
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class GameReplayScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String viewerUid;

  const GameReplayScreen({
    super.key,
    required this.gameId,
    required this.viewerUid,
  });

  @override
  ConsumerState<GameReplayScreen> createState() => _GameReplayScreenState();
}

class _GameReplayScreenState extends ConsumerState<GameReplayScreen> {
  GameModel? _game;
  final List<ChessEngine> _engines = [];
  int _index = 0;
  bool _loading = true;
  bool _playerIsWhite = true;

  // ── Analysis state ─────────────────────────────────────────────────────────
  bool _analyzing = false;
  double _analyzeProgress = 0;
  List<PositionEvalResult?> _evals = [];   // one per engine position (N+1)
  List<MoveAnnotation> _annotations = []; // one per move (N)
  double? _whiteAccuracy;
  double? _blackAccuracy;

  bool get _hasAnalysis => _annotations.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    final fs = ref.read(firestoreServiceProvider);
    final game = await fs.getGame(widget.gameId);
    if (game == null || !mounted) return;

    for (int i = 0; i <= game.moves.length; i++) {
      final eng = ChessEngine();
      for (int j = 0; j < i; j++) {
        eng.makeSanMove(game.moves[j]);
      }
      _engines.add(eng);
    }

    final playerIsWhite = game.blackUid != widget.viewerUid;

    setState(() {
      _game = game;
      _index = _engines.length - 1;
      _playerIsWhite = playerIsWhite;
      _loading = false;
    });
  }

  void _goTo(int i) {
    if (i < 0 || i >= _engines.length) return;
    setState(() => _index = i);
  }

  // ── Analysis ───────────────────────────────────────────────────────────────

  Future<void> _analyzeGame() async {
    if (_analyzing || _engines.isEmpty) return;
    setState(() {
      _analyzing = true;
      _analyzeProgress = 0;
      _evals = List<PositionEvalResult?>.filled(_engines.length, null, growable: true);
      _annotations = [];
      _whiteAccuracy = null;
      _blackAccuracy = null;
    });

    final stockfish = StockfishService();
    // Evaluate all positions in parallel batches of 5.
    // Each batch fires up to 5 API calls concurrently → fast overall.
    const batchSize = 5;
    final total = _engines.length;

    for (int start = 0; start < total; start += batchSize) {
      if (!mounted) return;
      final end = (start + batchSize).clamp(0, total);

      final batch = await Future.wait([
        for (int i = start; i < end; i++) _evalOne(stockfish, _engines[i].fen),
      ]);

      for (int j = 0; j < batch.length; j++) {
        _evals[start + j] = batch[j];
      }

      if (mounted) setState(() => _analyzeProgress = end / total);
    }

    // Build annotations + accuracy
    final annotations = <MoveAnnotation>[];
    final whiteLosses = <double>[];
    final blackLosses = <double>[];

    for (int i = 0; i < _game!.moves.length; i++) {
      final before = _evals[i];
      final after  = _evals[i + 1];

      if (before == null || after == null) {
        annotations.add(MoveAnnotation.good);
        continue;
      }

      final isWhiteMove = i % 2 == 0;
      final loss = _cpLoss(before.score, after.score, isWhiteMove);

      // Brilliant: ən yaxşı gediş + material itkisi (qurban)
      final matBefore = _engines[i].materialAdvantageFor(isWhiteMove);
      final matAfter  = _engines[i + 1].materialAdvantageFor(isWhiteMove);
      final isSacrifice = matAfter < matBefore;

      if (isWhiteMove) whiteLosses.add(loss);
      else             blackLosses.add(loss);

      annotations.add(_classify(loss, isSacrifice));
    }

    if (!mounted) return;
    setState(() {
      _annotations   = annotations;
      _analyzing     = false;
      _whiteAccuracy = _calcAccuracy(whiteLosses);
      _blackAccuracy = _calcAccuracy(blackLosses);
    });
  }

  /// Try online API first; fall back to fast local depth-2 minimax.
  Future<PositionEvalResult?> _evalOne(StockfishService svc, String fen) async {
    final online = await svc.evaluatePositionOnline(fen);
    if (online != null) return online;
    // API failed → local minimax depth 2 (fast)
    try {
      return await svc.evaluatePositionLocal(fen, depth: 2);
    } catch (_) {
      return null;
    }
  }

  /// Centipawn loss (0+) for the side that just moved.
  /// Scores are in pawn units; we convert to centipawns internally.
  double _cpLoss(double scoreBefore, double scoreAfter, bool isWhiteMove) {
    // Cap extreme mate scores
    final b = scoreBefore.clamp(-20.0, 20.0) * 100; // → centipawns
    final a = scoreAfter.clamp(-20.0,  20.0) * 100;
    final loss = isWhiteMove ? (b - a) : (a - b);
    return loss.clamp(0.0, 2000.0);
  }

  MoveAnnotation _classify(double cpLoss, bool isSacrifice) {
    // Briliant: motor seçimi + qurban verilmiş gediş
    if (cpLoss <= 5 && isSacrifice) return MoveAnnotation.brilliant;
    if (cpLoss <= 10)  return MoveAnnotation.best;
    if (cpLoss <= 25)  return MoveAnnotation.excellent;
    if (cpLoss <= 60)  return MoveAnnotation.good;
    if (cpLoss <= 120) return MoveAnnotation.inaccuracy;
    if (cpLoss <= 250) return MoveAnnotation.mistake;
    return MoveAnnotation.blunder;
  }

  /// Accuracy % from a list of centipawn losses (per side).
  double _calcAccuracy(List<double> losses) {
    if (losses.isEmpty) return 100.0;
    final avg = losses.reduce((a, b) => a + b) / losses.length;
    // Approximate chess.com-style accuracy formula
    final acc = 103.1668 * exp(-0.04354 * avg / 100.0) - 3.1669;
    return acc.clamp(0.0, 100.0);
  }

  // ── Eval score string ──────────────────────────────────────────────────────

  String _evalLabel() {
    if (!_hasAnalysis || _index >= _evals.length) return '';
    final ev = _evals[_index];
    if (ev == null) return '';
    final s = ev.score;
    if (s >= 9000)  return 'M+';
    if (s <= -9000) return 'M-';
    final pawns = (s / 1.0).abs();
    final sign  = s >= 0 ? '+' : '−';
    return '$sign${pawns.toStringAsFixed(1)}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: AppColors.inkDim, size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'past_games'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final cache     = ref.watch(cacheServiceProvider);
    final game      = _game!;
    final white     = game.whiteUsername ?? 'white'.tr();
    final black     = game.blackUsername ?? 'black'.tr();
    final totalMoves = _engines.length - 1;

    final currentAnnotation = (_hasAnalysis && _index > 0 && _index - 1 < _annotations.length)
        ? _annotations[_index - 1]
        : null;

    final currentEvalScore = (_hasAnalysis && _index < _evals.length)
        ? (_evals[_index]?.score ?? 0.0)
        : 0.0;

    return Column(
      children: [
        // ── Result banner ──────────────────────────────────────────────────
        _ResultBanner(game: game),

        // ── Accuracy cards (after analysis) ───────────────────────────────
        if (_hasAnalysis) ...[
          const SizedBox(height: 4),
          _AccuracyCards(
            whiteName: white,
            blackName: black,
            whiteAccuracy: _whiteAccuracy ?? 100,
            blackAccuracy: _blackAccuracy ?? 100,
          ),
        ],

        const SizedBox(height: 4),

        // ── Opponent player label ──────────────────────────────────────────
        _PlayerLabel(
          name: _playerIsWhite ? black : white,
          isWhite: !_playerIsWhite,
        ),

        // ── Board + eval bar ───────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Eval bar
                if (_hasAnalysis)
                  _EvalBar(
                    score: currentEvalScore,
                    flipped: !_playerIsWhite,
                    label: _evalLabel(),
                  ),

                // Chess board
                Expanded(
                  child: Center(
                    child: AbsorbPointer(
                      child: ChessBoardWidget(
                        engine: _engines[_index],
                        flipped: !_playerIsWhite,
                        selectedSquare: null,
                        legalMoveSquares: const [],
                        onSquareTap: (_) {},
                        showCoordinates: cache.showCoordinates,
                        animationDuration: cache.pieceMoveAnimationDuration,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── My player label ────────────────────────────────────────────────
        _PlayerLabel(
          name: _playerIsWhite ? white : black,
          isWhite: _playerIsWhite,
        ),

        const SizedBox(height: 6),

        // ── Current move annotation ────────────────────────────────────────
        if (currentAnnotation != null &&
            currentAnnotation != MoveAnnotation.good &&
            _index > 0)
          _AnnotationBadge(
            annotation: currentAnnotation,
            moveSan: game.moves[_index - 1],
          ),

        // ── Move counter ───────────────────────────────────────────────────
        Text(
          _index == 0 ? 'Start' : 'Move $_index / $totalMoves',
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),

        // ── Navigation controls ────────────────────────────────────────────
        _NavControls(
          index: _index,
          maxIndex: _engines.length - 1,
          onFirst: () => _goTo(0),
          onPrev:  () => _goTo(_index - 1),
          onNext:  () => _goTo(_index + 1),
          onLast:  () => _goTo(_engines.length - 1),
        ),

        const SizedBox(height: 6),

        // ── Move list with annotations ─────────────────────────────────────
        if (totalMoves > 0)
          SizedBox(
            height: 52,
            child: _MoveList(
              moves:        game.moves,
              annotations:  _annotations,
              currentIndex: _index,
              onTap:        _goTo,
            ),
          ),

        const SizedBox(height: 8),

        // ── Analyze button or progress ─────────────────────────────────────
        if (!_hasAnalysis && !_analyzing && totalMoves > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _analyzeGame,
                icon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill), size: 18),
                label: Text('analyze_game'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

        if (_analyzing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Analyzing… ${(_analyzeProgress * _engines.length).toInt()} / ${_engines.length}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      '${(_analyzeProgress * 100).toInt()}%',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _analyzeProgress,
                    backgroundColor: AppColors.divider,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Eval bar ───────────────────────────────────────────────────────────────────

class _EvalBar extends StatelessWidget {
  final double score; // pawn units, positive = white better
  final bool flipped; // true if black is at bottom of board
  final String label;

  const _EvalBar({required this.score, required this.flipped, required this.label});

  @override
  Widget build(BuildContext context) {
    // White's share of the bar (0.0 → 1.0)
    double whiteFraction = 0.5 + (score.clamp(-7.0, 7.0) / 14.0);
    if (flipped) whiteFraction = 1.0 - whiteFraction;

    return SizedBox(
      width: 20,
      child: Column(
        children: [
          // Score label
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          // Bar
          Expanded(
            child: Container(
              width: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: const Color(0xFF2A2A3E),
              ),
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final totalH = constraints.maxHeight;
                  final blackH = totalH * (1 - whiteFraction);
                  final whiteH = totalH * whiteFraction;
                  return Column(
                    children: [
                      // Black portion (top)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        height: blackH,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3A3A4E),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(7)),
                        ),
                      ),
                      // White portion (bottom)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        height: whiteH,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0EDE0),
                          borderRadius:
                              BorderRadius.vertical(bottom: Radius.circular(7)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Accuracy cards ─────────────────────────────────────────────────────────────

class _AccuracyCards extends StatelessWidget {
  final String whiteName;
  final String blackName;
  final double whiteAccuracy;
  final double blackAccuracy;

  const _AccuracyCards({
    required this.whiteName,
    required this.blackName,
    required this.whiteAccuracy,
    required this.blackAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _AccuracyCard(name: whiteName, accuracy: whiteAccuracy, isWhite: true),
          const SizedBox(width: 8),
          _AccuracyCard(name: blackName, accuracy: blackAccuracy, isWhite: false),
        ],
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  final String name;
  final double accuracy;
  final bool isWhite;

  const _AccuracyCard({
    required this.name,
    required this.accuracy,
    required this.isWhite,
  });

  Color get _accentColor {
    if (accuracy >= 90) return AppColors.success;
    if (accuracy >= 75) return const Color(0xFF54A0FF);
    if (accuracy >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accentColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isWhite ? const Color(0xFFF0EDE0) : const Color(0xFF2A2A2E),
                border: Border.all(color: AppColors.textHint),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${accuracy.toStringAsFixed(1)}%',
              style: AppTextStyles.labelMedium.copyWith(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Annotation badge ───────────────────────────────────────────────────────────

class _AnnotationBadge extends StatelessWidget {
  final MoveAnnotation annotation;
  final String moveSan;

  const _AnnotationBadge({required this.annotation, required this.moveSan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: annotation.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: annotation.color.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  annotation.symbol,
                  style: TextStyle(
                    color: annotation.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  annotation.label,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: annotation.color),
                ),
                const SizedBox(width: 5),
                Text(
                  moveSan,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result banner ──────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final GameModel game;
  const _ResultBanner({required this.game});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (game.result) {
      GameResult.white => ('white_wins'.tr(), AppColors.success),
      GameResult.black => ('black_wins'.tr(), AppColors.success),
      GameResult.draw  => ('game_drawn'.tr(), AppColors.warning),
      _                => ('past_games'.tr(), AppColors.primary),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${game.whiteUsername ?? 'white'.tr()} vs ${game.blackUsername ?? 'black'.tr()}',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player label ───────────────────────────────────────────────────────────────

class _PlayerLabel extends StatelessWidget {
  final String name;
  final bool isWhite;
  const _PlayerLabel({required this.name, required this.isWhite});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isWhite ? const Color(0xFFF0EDE0) : const Color(0xFF2A2A2E),
              border: Border.all(color: AppColors.textHint),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(name, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}

// ── Navigation controls ────────────────────────────────────────────────────────

class _NavControls extends StatelessWidget {
  final int index;
  final int maxIndex;
  final VoidCallback onFirst;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLast;

  const _NavControls({
    required this.index,
    required this.maxIndex,
    required this.onFirst,
    required this.onPrev,
    required this.onNext,
    required this.onLast,
  });

  @override
  Widget build(BuildContext context) {
    final atStart = index == 0;
    final atEnd   = index == maxIndex;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavBtn(icon: PhosphorIcons.skipBack(PhosphorIconsStyle.fill),    onTap: atStart ? null : onFirst),
        const SizedBox(width: 8),
        _NavBtn(icon: PhosphorIcons.caretLeft(PhosphorIconsStyle.fill),   onTap: atStart ? null : onPrev),
        const SizedBox(width: 8),
        _NavBtn(icon: PhosphorIcons.caretRight(PhosphorIconsStyle.fill),  onTap: atEnd   ? null : onNext),
        const SizedBox(width: 8),
        _NavBtn(icon: PhosphorIcons.skipForward(PhosphorIconsStyle.fill), onTap: atEnd   ? null : onLast),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.divider.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.textHint,
          size: 20,
        ),
      ),
    );
  }
}

// ── Move list with annotations ─────────────────────────────────────────────────

class _MoveList extends StatefulWidget {
  final List<String> moves;
  final List<MoveAnnotation> annotations; // same length as moves or empty
  final int currentIndex;
  final void Function(int) onTap;

  const _MoveList({
    required this.moves,
    required this.annotations,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<_MoveList> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(_MoveList old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != old.currentIndex) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!_scrollCtrl.hasClients) return;
    final pairIdx = ((widget.currentIndex - 1) / 2).floor();
    final target  = (pairIdx * 68.0).clamp(
      0.0,
      _scrollCtrl.position.maxScrollExtent,
    );
    _scrollCtrl.animateTo(target,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  MoveAnnotation? _annotationFor(int moveIndex) {
    if (widget.annotations.isEmpty) return null;
    if (moveIndex >= widget.annotations.length) return null;
    final ann = widget.annotations[moveIndex];
    return ann == MoveAnnotation.good ? null : ann;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollCtrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: (widget.moves.length / 2).ceil(),
      itemBuilder: (_, pairIdx) {
        final wMoveIdx = pairIdx * 2;
        final bMoveIdx = wMoveIdx + 1;
        final whiteSan = widget.moves[wMoveIdx];
        final blackSan = bMoveIdx < widget.moves.length
            ? widget.moves[bMoveIdx]
            : null;
        final whiteActive = widget.currentIndex == wMoveIdx + 1;
        final blackActive = blackSan != null &&
            widget.currentIndex == bMoveIdx + 1;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                '${pairIdx + 1}.',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textHint),
              ),
            ),
            _MoveChip(
              san:        whiteSan,
              active:     whiteActive,
              annotation: _annotationFor(wMoveIdx),
              onTap:      () => widget.onTap(wMoveIdx + 1),
            ),
            const SizedBox(width: 2),
            if (blackSan != null)
              _MoveChip(
                san:        blackSan,
                active:     blackActive,
                annotation: _annotationFor(bMoveIdx),
                onTap:      () => widget.onTap(bMoveIdx + 1),
              ),
            const SizedBox(width: 6),
          ],
        );
      },
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String san;
  final bool active;
  final MoveAnnotation? annotation;
  final VoidCallback onTap;

  const _MoveChip({
    required this.san,
    required this.active,
    required this.annotation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ann = annotation;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : (ann != null
                  ? ann.color.withOpacity(0.10)
                  : AppColors.primary.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(6),
          border: active
              ? null
              : (ann != null
                  ? Border.all(color: ann.color.withOpacity(0.35), width: 1)
                  : null),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              san,
              style: AppTextStyles.labelSmall.copyWith(
                color: active
                    ? Colors.white
                    : (ann != null
                        ? ann.color
                        : AppColors.textSecondary),
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (ann != null && ann.symbol.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                ann.symbol,
                style: TextStyle(
                  fontSize: 9,
                  color: active ? Colors.white70 : ann.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── ELO → depth / randomness / delay tables ───────────────────────────────────

int _depthForElo(int elo) {
  if (elo <= 600) return 1;
  if (elo <= 1000) return 3;
  if (elo <= 1400) return 5;
  if (elo <= 1800) return 8;
  if (elo <= 2200) return 12;
  // stockfish.online API reliably handles up to depth 15.
  // Depth 18+ causes very long response times or failures.
  return 15;
}

/// Probability of playing a random move instead of the best move.
double _randomChance(int elo) {
  if (elo <= 200) return 0.80;
  if (elo <= 600) return 0.50;
  if (elo <= 1000) return 0.25;
  return 0.0;
}

/// Fake thinking delay (ms): 400 ms at 200 ELO, capped at 1200 ms.
int _thinkingMs(int elo) =>
    (400 + ((elo.clamp(200, 3000) - 200) / 2800 * 800).round()).clamp(400, 1200);

/// Result of evaluating a position locally.
class PositionEvalResult {
  final double score;    // in pawn units, positive = white better, ±9999 = mate
  final String? bestMove; // UCI notation e.g. "e2e4"
  const PositionEvalResult({required this.score, this.bestMove});
}

// ── Service ────────────────────────────────────────────────────────────────────

/// HTTP-based chess engine service.
///
/// Move selection pipeline:
///   1. Fake thinking delay (gives the UI a natural feel).
///   2. Random move injection (lower ELOs play suboptimally).
///   3. Stockfish Online API  → `https://stockfish.online/api/s/v2.php`
///   4. Offline minimax (depth 2–3) as fallback when the API is unreachable.
///
/// Returns moves in UCI format: "e2e4", "g1f3", "e7e8q" (promotion).
class StockfishService {
  static final StockfishService _i = StockfishService._();
  factory StockfishService() => _i;
  StockfishService._();

  final _rng = Random();

  Future<String?> getBestMove({
    required String fen,
    required int botRating,
    required List<String> moves,
    int? overrideDepth,
    int? overrideDelayMs,
  }) async {
    if (moves.isEmpty) return null;

    // Visual delay (minimum thinking time shown to user).
    final visualDelayMs = overrideDelayMs ?? _thinkingMs(botRating);

    // Random move injection for low-ELO bots.
    if (overrideDepth == null) {
      final chance = _randomChance(botRating);
      if (chance > 0 && _rng.nextDouble() < chance) {
        await Future.delayed(Duration(milliseconds: visualDelayMs));
        return _randomUciMove(fen);
      }
    }

    final depth = overrideDepth ?? _depthForElo(botRating);
    final fbDepth = overrideDepth != null
        ? overrideDepth.clamp(1, 3)
        : (botRating <= 800 ? 2 : 3);

    // For very short campaign delays (easy chapters), skip API entirely.
    // visualDelayMs == 0 means "no delay" (regular bot games) — still use API.
    if (visualDelayMs > 0 && visualDelayMs <= 350) {
      await Future.delayed(Duration(milliseconds: visualDelayMs));
      return compute(_minimaxBestMove, _MinimaxArgs(fen: fen, depth: fbDepth));
    }

    // Start API call immediately (parallel with the visual delay).
    final apiFuture = _fetchApiMove(fen: fen, depth: depth)
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        )
        .catchError((e) {
          debugPrint('[StockfishAPI] request failed: $e — using minimax');
          return null as String?;
        });

    // Wait the minimum visual delay while the API runs in parallel.
    await Future.delayed(Duration(milliseconds: visualDelayMs));

    // Collect API result (already done if fast, or timed-out).
    final apiMove = await apiFuture;
    if (apiMove != null) return apiMove;

    // Fallback: offline minimax.
    return compute(_minimaxBestMove, _MinimaxArgs(fen: fen, depth: fbDepth));
  }

  /// Evaluate a position via the online Stockfish API (depth 12).
  /// Returns null on network error or timeout.
  Future<PositionEvalResult?> evaluatePositionOnline(String fen) async {
    try {
      final uri = Uri.https('stockfish.online', '/api/s/v2.php', {
        'fen': fen,
        'depth': '12',
      });
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      double score;
      final mate = data['mate'];
      final eval = data['evaluation'];
      if (mate != null && mate != 0) {
        score = (mate as num) > 0 ? 9999.0 : -9999.0;
      } else if (eval != null) {
        score = (eval as num).toDouble();
      } else {
        return null;
      }

      // Parse best move from "bestmove e2e4 ponder ..." string
      String? bestMove;
      final line = data['bestmove'] as String?;
      if (line != null) {
        final parts = line.trim().split(RegExp(r'\s+'));
        final idx = parts.indexOf('bestmove');
        final mi = idx >= 0 ? idx + 1 : 0;
        if (mi < parts.length) {
          final m = parts[mi];
          if (m.isNotEmpty && m != '(none)') bestMove = m;
        }
      }

      return PositionEvalResult(score: score, bestMove: bestMove);
    } catch (_) {
      return null;
    }
  }

  /// Evaluate a position locally using minimax (depth 2 — fast fallback).
  /// Uses Flutter's compute() so it runs off the main isolate.
  /// Returns score in pawn units (positive = white better).
  Future<PositionEvalResult> evaluatePositionLocal(String fen, {int depth = 2}) {
    return compute(_computePositionEval, _EvalArgs(fen: fen, depth: depth));
  }

  /// Nothing to dispose for an HTTP-based service.
  void dispose() {}

  // ── HTTP API ────────────────────────────────────────────────────────────────

  Future<String?> _fetchApiMove({
    required String fen,
    required int depth,
  }) async {
    final uri = Uri.https('stockfish.online', '/api/s/v2.php', {
      'fen': fen,
      'depth': depth.toString(),
    });

    final resp = await http.get(uri).timeout(const Duration(seconds: 4));
    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] != true) return null;

    // Response: {"success":true, "bestmove":"bestmove e2e4 ponder d7d5", ...}
    final line = data['bestmove'] as String?;
    if (line == null || line.isEmpty) return null;

    final parts = line.trim().split(RegExp(r'\s+'));
    final bmIdx = parts.indexOf('bestmove');
    final moveIdx = bmIdx >= 0 ? bmIdx + 1 : 0;

    if (moveIdx < parts.length) {
      final m = parts[moveIdx];
      if (m.isNotEmpty && m != '(none)') return m;
    }
    return null;
  }

  // ── Random move helper ──────────────────────────────────────────────────────

  String? _randomUciMove(String fen) {
    final chess = ch.Chess.fromFEN(fen);
    final verboseMoves = chess.moves({'verbose': true});
    if (verboseMoves.isEmpty) return null;
    verboseMoves.shuffle(_rng);
    final m = verboseMoves.first as Map;
    final from = m['from'] as String;
    final to = m['to'] as String;
    final promo = m['promotion'];
    return promo != null ? '$from$to$promo' : '$from$to';
  }
}

// ── Minimax (top-level — required by compute()) ───────────────────────────────

class _MinimaxArgs {
  final String fen;
  final int depth;
  _MinimaxArgs({required this.fen, required this.depth});
}

class _EvalArgs {
  final String fen;
  final int depth;
  _EvalArgs({required this.fen, required this.depth});
}

String? _minimaxBestMove(_MinimaxArgs args) {
  final chess = ch.Chess.fromFEN(args.fen);
  final verboseMoves = chess.moves({'verbose': true});
  if (verboseMoves.isEmpty) return null;

  // Shuffle before searching so that equal-score moves are chosen randomly
  // each call. This prevents the engine from oscillating between the same
  // two moves when their material scores are identical.
  verboseMoves.shuffle(Random());

  final maximizing = chess.turn == ch.Color.WHITE;
  String? bestMove;
  var bestScore = maximizing ? double.negativeInfinity : double.infinity;

  for (final mv in verboseMoves) {
    final map = mv as Map;
    final from = map['from'] as String;
    final to = map['to'] as String;
    final promo = map['promotion'] as String?;

    final copy = ch.Chess.fromFEN(chess.fen);
    copy.move({'from': from, 'to': to, if (promo != null) 'promotion': promo});

    final score = _alphabeta(
      copy,
      args.depth - 1,
      double.negativeInfinity,
      double.infinity,
      !maximizing,
    );

    if ((maximizing && score > bestScore) ||
        (!maximizing && score < bestScore)) {
      bestScore = score;
      bestMove = promo != null ? '$from$to$promo' : '$from$to';
    }
  }
  return bestMove;
}

/// Top-level function for Flutter compute() — evaluates a position and
/// returns the score plus the best move (UCI).
PositionEvalResult _computePositionEval(_EvalArgs args) {
  final chess = ch.Chess.fromFEN(args.fen);

  if (chess.game_over) {
    final score = chess.in_checkmate
        ? (chess.turn == ch.Color.WHITE ? -9999.0 : 9999.0)
        : 0.0;
    return PositionEvalResult(score: score, bestMove: null);
  }

  final verboseMoves = chess.moves({'verbose': true});
  if (verboseMoves.isEmpty) return const PositionEvalResult(score: 0, bestMove: null);

  final maximizing = chess.turn == ch.Color.WHITE;
  String? bestMove;
  var bestScore = maximizing ? double.negativeInfinity : double.infinity;

  for (final mv in verboseMoves) {
    final map = mv as Map;
    final from = map['from'] as String;
    final to   = map['to']   as String;
    final promo = map['promotion'] as String?;

    final copy = ch.Chess.fromFEN(chess.fen);
    copy.move({'from': from, 'to': to, if (promo != null) 'promotion': promo});

    final score = _alphabeta(copy, args.depth - 1,
        double.negativeInfinity, double.infinity, !maximizing);

    if ((maximizing && score > bestScore) || (!maximizing && score < bestScore)) {
      bestScore = score;
      bestMove  = promo != null ? '$from$to$promo' : '$from$to';
    }
  }

  return PositionEvalResult(score: bestScore, bestMove: bestMove);
}

double _alphabeta(
  ch.Chess chess,
  int depth,
  double alpha,
  double beta,
  bool maximizing,
) {
  if (depth == 0 || chess.game_over) return _evaluate(chess);

  final moves = chess.moves({'verbose': true});

  if (maximizing) {
    var best = double.negativeInfinity;
    for (final mv in moves) {
      final map = mv as Map;
      final copy = ch.Chess.fromFEN(chess.fen);
      copy.move({
        'from': map['from'],
        'to': map['to'],
        if (map['promotion'] != null) 'promotion': map['promotion'],
      });
      final score = _alphabeta(copy, depth - 1, alpha, beta, false);
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (beta <= alpha) break;
    }
    return best;
  } else {
    var best = double.infinity;
    for (final mv in moves) {
      final map = mv as Map;
      final copy = ch.Chess.fromFEN(chess.fen);
      copy.move({
        'from': map['from'],
        'to': map['to'],
        if (map['promotion'] != null) 'promotion': map['promotion'],
      });
      final score = _alphabeta(copy, depth - 1, alpha, beta, true);
      if (score < best) best = score;
      if (best < beta) beta = best;
      if (beta <= alpha) break;
    }
    return best;
  }
}

double _evaluate(ch.Chess chess) {
  if (chess.in_checkmate) {
    return chess.turn == ch.Color.WHITE ? -10000.0 : 10000.0;
  }
  if (chess.in_stalemate || chess.in_draw) return 0.0;

  var score = 0.0;
  for (final key in ch.Chess.SQUARES.keys) {
    final piece = chess.get(key as String);
    if (piece == null) continue;
    double val;
    if (piece.type == ch.PieceType.PAWN) {
      val = 1.0;
    } else if (piece.type == ch.PieceType.KNIGHT) {
      val = 3.0;
    } else if (piece.type == ch.PieceType.BISHOP) {
      val = 3.2;
    } else if (piece.type == ch.PieceType.ROOK) {
      val = 5.0;
    } else if (piece.type == ch.PieceType.QUEEN) {
      val = 9.0;
    } else {
      val = 0.0; // KING
    }
    score += piece.color == ch.Color.WHITE ? val : -val;
  }
  return score;
}

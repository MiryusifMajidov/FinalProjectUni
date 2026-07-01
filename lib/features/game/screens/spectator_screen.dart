import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/realtime_game_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../engine/chess_engine.dart';
import '../widgets/chess_board_widget.dart';

class SpectatorScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String watchedUid;

  const SpectatorScreen({
    super.key,
    required this.gameId,
    required this.watchedUid,
  });

  @override
  ConsumerState<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends ConsumerState<SpectatorScreen> {
  final _engine = ChessEngine();
  final _seenKeys = <String>{};
  StreamSubscription<DatabaseEvent>? _moveSub;
  StreamSubscription<DatabaseEvent>? _gameOverSub;
  bool _gameOver = false;
  String _statusText = '';
  String _whiteUsername = '';
  String _blackUsername = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {
        _statusText = 'watch_game'.tr();
        _whiteUsername = 'white'.tr();
        _blackUsername = 'black'.tr();
      });
    });
    _loadPlayerNames();
    _subscribeToMoves();
  }

  @override
  void dispose() {
    _moveSub?.cancel();
    _gameOverSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPlayerNames() async {
    final fs = ref.read(firestoreServiceProvider);
    final watched = await fs.getUser(widget.watchedUid);
    if (watched == null || !mounted) return;
    // We don't know which color watched user is yet — update when we get game data
    setState(() {
      _whiteUsername = watched.username;
    });
  }

  void _subscribeToMoves() {
    final rtdb = ref.read(realtimeGameServiceProvider);

    _moveSub = rtdb.watchMoves(widget.gameId).listen((event) {
      if (!mounted) return;
      final key = event.snapshot.key ?? '';
      if (_seenKeys.contains(key)) return;
      _seenKeys.add(key);

      final raw = event.snapshot.value;
      if (raw == null) return;
      final map = Map<String, dynamic>.from(raw as Map);
      final from = map['from'] as String?;
      final to = map['to'] as String?;
      final promotion = map['promotion'] as String?;
      if (from == null || to == null) return;

      setState(() {
        _engine.makeMove(from, to, promotion: promotion);
      });
    });

    _gameOverSub = rtdb.watchGameOver(widget.gameId).listen((event) {
      final raw = event.snapshot.value;
      if (raw == null || !mounted) return;
      final map = Map<String, dynamic>.from(raw as Map);
      final result = map['result'] as String? ?? '';
      setState(() {
        _gameOver = true;
        _statusText = _resultText(result);
      });
    });
  }

  String _resultText(String result) {
    switch (result) {
      case 'white': return 'white_wins'.tr();
      case 'black': return 'black_wins'.tr();
      case 'draw':  return 'game_drawn'.tr();
      default:      return 'watch_game'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(cacheServiceProvider);
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
                  'spectating'.tr(),
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
          const SizedBox(height: 4),
          // Status banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _gameOver ? AppColors.error.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _gameOver ? AppColors.error.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_gameOver) ...[
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _statusText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _gameOver ? AppColors.error : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Player names
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PlayerChip(name: _blackUsername, color: Colors.black),
                _PlayerChip(name: _whiteUsername, color: Colors.white),
              ],
            ),
          ),

          // Board (read-only — no interactions)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AbsorbPointer(
                  child: ChessBoardWidget(
                    engine: _engine,
                    flipped: false,
                    selectedSquare: null,
                    legalMoveSquares: const [],
                    onSquareTap: (_) {},
                    showCoordinates: cache.showCoordinates,
                  ),
                ),
              ),
            ),
          ),

          if (_gameOver)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: Text('close'.tr()),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final Color color;
  const _PlayerChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: AppColors.textHint, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

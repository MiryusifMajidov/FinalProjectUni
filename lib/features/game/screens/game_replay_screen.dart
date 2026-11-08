import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/models/game_model.dart';
import '../engine/chess_engine.dart';
import '../widgets/chess_board_widget.dart';
import '../../../core/theme/app_fonts.dart';

/// A finished chess game, move by move.
///
/// This screen used to offer a computer analysis (best moves, blunders, an
/// accuracy score). It sent every position to a free third-party API and,
/// whenever that was slow or unreachable, quietly fell back to counting
/// material two moves deep — so it labelled good moves as blunders, and its
/// accuracy formula reported ~99 % even for badly played games. Misleading
/// numbers are worse than none, so the replay stays and the analysis is gone
/// until it can run on a real engine.
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
  bool _notFound = false;
  bool _playerIsWhite = true;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    final fs = ref.read(firestoreServiceProvider);
    final game = await fs.getGame(widget.gameId);
    if (!mounted) return;
    if (game == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }

    // One position per move, built incrementally (each step copies the
    // previous position instead of replaying the game from the start).
    final positions = <ChessEngine>[ChessEngine()];
    for (final san in game.moves) {
      final next = ChessEngine.fromFen(positions.last.fen);
      next.makeSanMove(san);
      positions.add(next);
    }

    setState(() {
      _game = game;
      _engines
        ..clear()
        ..addAll(positions);
      _index = _engines.length - 1;
      _playerIsWhite = game.blackUid != widget.viewerUid;
      _loading = false;
    });
  }

  void _goTo(int i) {
    if (i < 0 || i >= _engines.length) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'back'.tr(),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                          color: AppColors.inkDim,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'replay'.tr(),
                    style: AppFonts.ui(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.amber))
                  : _notFound
                      ? Center(
                          child: Text(
                            'game_not_found'.tr(),
                            style: AppFonts.ui(
                                fontSize: 14, color: AppColors.inkDim),
                          ),
                        )
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final cache = ref.watch(cacheServiceProvider);
    final game = _game!;
    final white = game.whiteUsername ?? 'white'.tr();
    final black = game.blackUsername ?? 'black'.tr();
    final totalMoves = _engines.length - 1;

    return Column(
      children: [
        _ResultBanner(game: game),
        const SizedBox(height: 4),
        _PlayerLabel(
          name: _playerIsWhite ? black : white,
          isWhite: !_playerIsWhite,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
        ),
        _PlayerLabel(
          name: _playerIsWhite ? white : black,
          isWhite: _playerIsWhite,
        ),
        const SizedBox(height: 8),
        Text(
          _index == 0
              ? 'replay_start'.tr()
              : 'replay_move_of'.tr(
                  namedArgs: {'n': '$_index', 'total': '$totalMoves'}),
          style: AppFonts.ui(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.inkDim,
          ),
        ),
        const SizedBox(height: 8),
        _NavControls(
          index: _index,
          maxIndex: totalMoves,
          onFirst: () => _goTo(0),
          onPrev: () => _goTo(_index - 1),
          onNext: () => _goTo(_index + 1),
          onLast: () => _goTo(totalMoves),
        ),
        const SizedBox(height: 8),
        if (totalMoves > 0)
          SizedBox(
            height: 52,
            child: _MoveList(
              moves: game.moves,
              currentIndex: _index,
              onTap: _goTo,
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Result banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final GameModel game;
  const _ResultBanner({required this.game});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (game.result) {
      GameResult.white => ('white_wins'.tr(), AppColors.win),
      GameResult.black => ('black_wins'.tr(), AppColors.win),
      GameResult.draw => ('game_drawn'.tr(), AppColors.draw),
      _ => ('past_games'.tr(), AppColors.amber),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '${game.whiteUsername ?? 'white'.tr()} – ${game.blackUsername ?? 'black'.tr()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.ui(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: AppFonts.ui(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player label ──────────────────────────────────────────────────────────────

class _PlayerLabel extends StatelessWidget {
  final String name;
  final bool isWhite;
  const _PlayerLabel({required this.name, required this.isWhite});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color:
                  isWhite ? const Color(0xFFF0EDE0) : const Color(0xFF2A2A2E),
              border: Border.all(color: AppColors.inkMute),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.ui(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation controls ───────────────────────────────────────────────────────

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
    final atEnd = index == maxIndex;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavBtn(
            icon: PhosphorIcons.skipBack(PhosphorIconsStyle.fill),
            label: 'replay_first'.tr(),
            onTap: atStart ? null : onFirst),
        const SizedBox(width: 8),
        _NavBtn(
            icon: PhosphorIcons.caretLeft(PhosphorIconsStyle.fill),
            label: 'replay_previous'.tr(),
            onTap: atStart ? null : onPrev),
        const SizedBox(width: 8),
        _NavBtn(
            icon: PhosphorIcons.caretRight(PhosphorIconsStyle.fill),
            label: 'replay_next'.tr(),
            onTap: atEnd ? null : onNext),
        const SizedBox(width: 8),
        _NavBtn(
            icon: PhosphorIcons.skipForward(PhosphorIconsStyle.fill),
            label: 'replay_last'.tr(),
            onTap: atEnd ? null : onLast),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 48,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.amber.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: enabled ? AppColors.amber : AppColors.inkFaint,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ── Move list ─────────────────────────────────────────────────────────────────

class _MoveList extends StatefulWidget {
  final List<String> moves;
  final int currentIndex;
  final void Function(int) onTap;

  const _MoveList({
    required this.moves,
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!_scrollCtrl.hasClients) return;
    final pairIdx = ((widget.currentIndex - 1) / 2).floor();
    final target =
        (pairIdx * 68.0).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(target,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
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
        final blackSan =
            bMoveIdx < widget.moves.length ? widget.moves[bMoveIdx] : null;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text(
                '${pairIdx + 1}.',
                style: AppFonts.ui(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 11.5,
                  color: AppColors.inkMute,
                ),
              ),
            ),
            _MoveChip(
              san: widget.moves[wMoveIdx],
              active: widget.currentIndex == wMoveIdx + 1,
              onTap: () => widget.onTap(wMoveIdx + 1),
            ),
            const SizedBox(width: 2),
            if (blackSan != null)
              _MoveChip(
                san: blackSan,
                active: widget.currentIndex == bMoveIdx + 1,
                onTap: () => widget.onTap(bMoveIdx + 1),
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
  final VoidCallback onTap;

  const _MoveChip({
    required this.san,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.amber
              : AppColors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          san,
          style: AppFonts.ui(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF241703) : AppColors.inkDim,
          ),
        ),
      ),
    );
  }
}

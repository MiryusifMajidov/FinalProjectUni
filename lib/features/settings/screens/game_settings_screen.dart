import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/models/game_type.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/theme/board_themes.dart';
import '../../game/engine/chess_engine.dart';
import '../../game/widgets/chess_board_widget.dart';
import 'settings_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = Color(0xFF0A0A0B);
const _kSurface      = Color(0xFF131316);
const _kCard         = Color(0xFF1A1A1E);
const _kAmber        = Color(0xFFE8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kBorder       = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);

class GameSettingsScreen extends ConsumerStatefulWidget {
  const GameSettingsScreen({super.key});

  @override
  ConsumerState<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends ConsumerState<GameSettingsScreen> {
  // Board theme — local visual ID mapped from persisted BoardTheme enum
  late String _boardTheme;

  /// Maps persisted [BoardTheme] → local visual string used by the swatch carousel.
  static String _themeToId(BoardTheme t) => switch (t) {
    BoardTheme.brownWood  => 'walnut',
    BoardTheme.greenFelt  => 'forest',
    BoardTheme.darkMarble => 'marble',
    BoardTheme.blueIce    => 'slate',
    BoardTheme.creamPaper => 'cream',
  };

  /// Maps local visual string → [BoardTheme] for persistence.
  static BoardTheme _idToTheme(String id) => switch (id) {
    'walnut' => BoardTheme.brownWood,
    'forest' => BoardTheme.greenFelt,
    'marble' => BoardTheme.darkMarble,
    'slate'  => BoardTheme.blueIce,
    'cream'  => BoardTheme.creamPaper,
    _        => BoardTheme.brownWood,
  };

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _boardTheme = _themeToId(settings.boardTheme);
    _pieceSet   = settings.pieceSet.name;
    final c = ref.read(cacheServiceProvider);
    _autoQueen        = c.autoQueen;
    _highlightLastMove = c.highlightLastMove;
    _showLegalMoves   = c.showLegalMoves;
    _confirmMoves     = c.confirmMoves;
    _premove          = c.premove;
    _notation         = c.moveNotation;
    _coordinates      = c.showCoordinates;
    _animSpeed        = c.animSpeed;
    _reduceMotion     = c.reduceMotion;
  }

  void _haptic() {
    if (ref.read(cacheServiceProvider).hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  // Gameplay toggles
  bool _autoQueen        = false;
  bool _highlightLastMove = true;
  bool _showLegalMoves   = true;
  bool _confirmMoves     = false;
  bool _premove          = true;

  // Display / motion (moved here from the former Appearance screen)
  bool   _coordinates  = true;
  String _animSpeed    = 'med';
  bool   _reduceMotion = false;

  // Notation
  String _notation = 'san';

  // Piece set
  String _pieceSet = 'cburnett';

  static const _boardThemes = [
    (id: 'walnut', label: 'Walnut', light: Color(0xFFF0D9B5), dark: Color(0xFFB58863)),
    (id: 'slate',  label: 'Slate',  light: Color(0xFFDEE3E6), dark: Color(0xFF8CA2AD)),
    (id: 'forest', label: 'Forest', light: Color(0xFFEEEED2), dark: Color(0xFF769656)),
    (id: 'marble', label: 'Marble', light: Color(0xFF2C2C3E), dark: Color(0xFF1A1A28)),
    (id: 'cream',  label: 'Cream',  light: Color(0xFFF5F0E8), dark: Color(0xFFD4C5A9)),
  ];

  static const _pieceSets = [
    (id: 'cburnett', label: 'CBurnett'),
    (id: 'merida',   label: 'Merida'),
    (id: 'alpha',    label: 'Alpha'),
  ];

  @override
  Widget build(BuildContext context) {
    final activeGame = ref.watch(activeGameProvider);
    final isChess    = activeGame == GameType.chess;
    final isDomino   = activeGame == GameType.domino;
    final accent     = activeGame.accent;

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
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: _kInkDim,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'game_settings'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                  const Spacer(),
                  // Game indicator chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      activeGame.glyph,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const SizedBox(height: 20),

                  // ── Board + piece live preview (chess & checkers only) ──
                  if (!isDomino) ...[
                    Center(
                      // The preview matches the ACTIVE game: chess shows the
                      // chess set, checkers shows discs — no chess pieces on
                      // a checkers settings page.
                      child: isChess
                          ? _GameBoardPreview(
                              boardTheme: _idToTheme(_boardTheme),
                              pieceSet: PieceSet.values.byName(_pieceSet),
                            )
                          : _CheckersBoardPreview(
                              boardTheme: _idToTheme(_boardTheme),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // ── BOARD carousel ───────────────────────────────────
                    _sectionLabel('BOARD'),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        scrollDirection: Axis.horizontal,
                        itemCount: _boardThemes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final theme = _boardThemes[i];
                          final selected = _boardTheme == theme.id;
                          return _BoardThemeSwatch(
                            label: theme.label,
                            lightColor: theme.light,
                            darkColor: theme.dark,
                            selected: selected,
                            accent: accent,
                            onTap: () {
                              _haptic();
                              setState(() => _boardTheme = theme.id);
                              ref.read(settingsProvider.notifier)
                                  .setBoardTheme(_idToTheme(theme.id));
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── PIECES carousel (chess only) ──────────────────────
                  if (isChess) ...[
                    _sectionLabel('PIECES'),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        scrollDirection: Axis.horizontal,
                        itemCount: _pieceSets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final ps      = _pieceSets[i];
                          final theme   = _boardThemes
                              .firstWhere((t) => t.id == _boardTheme);
                          final selected = _pieceSet == ps.id;
                          return _PieceSetSwatch(
                            id: ps.id,
                            label: ps.label,
                            lightColor: theme.light,
                            darkColor: theme.dark,
                            selected: selected,
                            onTap: () {
                              _haptic();
                              setState(() => _pieceSet = ps.id);
                              final p = PieceSet.values.byName(ps.id);
                              ref.read(settingsProvider.notifier).setPieceSet(p);
                              ref.read(cacheServiceProvider).setPieceSet(ps.id);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── GAMEPLAY group ─────────────────────────────────────
                  _sectionLabel('GAMEPLAY'),
                  _SettingsGroup(children: [
                    // Auto-queen — chess only
                    if (isChess)
                      _SettingsRow(
                        icon: PhosphorIcons.crown(PhosphorIconsStyle.regular),
                        label: 'Auto-queen promotion',
                        accent: accent,
                        right: _DesignToggle(
                          on: _autoQueen,
                          accent: accent,
                          onToggle: () {
                            _haptic();
                            final v = !_autoQueen;
                            setState(() => _autoQueen = v);
                            ref.read(cacheServiceProvider).setAutoQueen(v);
                          },
                        ),
                      ),
                    // Coordinates — chess only (a–h / 1–8 labels)
                    if (isChess)
                      _SettingsRow(
                        icon: PhosphorIcons.hash(PhosphorIconsStyle.regular),
                        label: 'Coordinates',
                        sub: 'Show a–h / 1–8 labels on the board',
                        accent: accent,
                        right: _DesignToggle(
                          on: _coordinates,
                          accent: accent,
                          onToggle: () {
                            _haptic();
                            final v = !_coordinates;
                            setState(() => _coordinates = v);
                            ref.read(cacheServiceProvider).setShowCoordinates(v);
                          },
                        ),
                      ),
                    _SettingsRow(
                      icon: PhosphorIcons.arrowsHorizontal(PhosphorIconsStyle.regular),
                      label: 'Highlight last move',
                      accent: accent,
                      right: _DesignToggle(
                        on: _highlightLastMove,
                        accent: accent,
                        onToggle: () {
                          _haptic();
                          final v = !_highlightLastMove;
                          setState(() => _highlightLastMove = v);
                          ref.read(cacheServiceProvider).setHighlightLastMove(v);
                        },
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.dotsSixVertical(PhosphorIconsStyle.regular),
                      label: 'Show legal moves',
                      accent: accent,
                      right: _DesignToggle(
                        on: _showLegalMoves,
                        accent: accent,
                        onToggle: () {
                          _haptic();
                          final v = !_showLegalMoves;
                          setState(() => _showLegalMoves = v);
                          ref.read(cacheServiceProvider).setShowLegalMoves(v);
                        },
                      ),
                      isLast: !isChess, // last item for checkers/domino
                    ),
                    // Confirm moves — chess only (no confirm step in
                    // checkers/domino)
                    if (isChess)
                      _SettingsRow(
                        icon: PhosphorIcons.checkSquare(PhosphorIconsStyle.regular),
                        label: 'Confirm moves',
                        accent: accent,
                        right: _DesignToggle(
                          on: _confirmMoves,
                          accent: accent,
                          onToggle: () {
                            _haptic();
                            final v = !_confirmMoves;
                            setState(() => _confirmMoves = v);
                            ref.read(cacheServiceProvider).setConfirmMoves(v);
                          },
                        ),
                      ),
                    // Premove — chess only
                    if (isChess)
                      _SettingsRow(
                        icon: PhosphorIcons.lightning(PhosphorIconsStyle.regular),
                        label: 'Premove',
                        accent: accent,
                        right: _DesignToggle(
                          on: _premove,
                          accent: accent,
                          onToggle: () {
                            _haptic();
                            final v = !_premove;
                            setState(() => _premove = v);
                            ref.read(cacheServiceProvider).setPremove(v);
                          },
                        ),
                        isLast: true,
                      ),
                  ]),

                  const SizedBox(height: 24),

                  // ── NOTATION group (chess only) ────────────────────────
                  if (isChess) ...[
                    _sectionLabel('NOTATION'),
                    _SettingsGroup(children: [
                      _SettingsRow(
                        icon: PhosphorIcons.textT(PhosphorIconsStyle.regular),
                        label: 'Move notation',
                        accent: accent,
                        right: _SegmentedControl(
                          options: const ['SAN', 'Long', 'Figurine'],
                          accent: accent,
                          selected: _notation == 'san'
                              ? 0
                              : _notation == 'long'
                                  ? 1
                                  : 2,
                          onChanged: (i) {
                            _haptic();
                            final v = ['san', 'long', 'figurine'][i];
                            setState(() => _notation = v);
                            ref.read(cacheServiceProvider).setMoveNotation(v);
                          },
                        ),
                        isLast: true,
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // ── MOTION group (moved from the Appearance screen) ────
                  _sectionLabel('MOTION'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.timer(PhosphorIconsStyle.regular),
                      label: 'Animation speed',
                      sub: 'Controls piece-move animation duration',
                      accent: accent,
                      right: _SegmentedControl(
                        options: const ['Slow', 'Med', 'Fast'],
                        accent: accent,
                        selected: _animSpeed == 'slow'
                            ? 0
                            : _animSpeed == 'fast'
                                ? 2
                                : 1,
                        onChanged: (i) {
                          _haptic();
                          final v = ['slow', 'med', 'fast'][i];
                          setState(() => _animSpeed = v);
                          ref.read(cacheServiceProvider).setAnimSpeed(v);
                        },
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.eye(PhosphorIconsStyle.regular),
                      label: 'Reduce motion',
                      sub: 'Disables all piece animations',
                      accent: accent,
                      right: _DesignToggle(
                        on: _reduceMotion,
                        accent: accent,
                        onToggle: () {
                          _haptic();
                          final v = !_reduceMotion;
                          setState(() => _reduceMotion = v);
                          ref.read(cacheServiceProvider).setReduceMotion(v);
                        },
                      ),
                      isLast: true,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kInkMute,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Live Board Preview (uses real ChessBoardWidget) ───────────────────────────

class _GameBoardPreview extends StatefulWidget {
  final BoardTheme boardTheme;
  final PieceSet pieceSet;

  const _GameBoardPreview({
    required this.boardTheme,
    required this.pieceSet,
  });

  @override
  State<_GameBoardPreview> createState() => _GameBoardPreviewState();
}

class _GameBoardPreviewState extends State<_GameBoardPreview> {
  // Starting position — stays constant; purely decorative.
  final _engine = ChessEngine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: ChessBoardWidget(
        engine: _engine,
        flipped: false,
        selectedSquare: null,
        legalMoveSquares: const [],
        onSquareTap: (_) {},
        boardTheme: widget.boardTheme,
        pieceSet: widget.pieceSet,
        showCoordinates: false,
      ),
    );
  }
}

// ── Checkers preview (discs on the selected board theme) ──────────────────────

class _CheckersBoardPreview extends StatelessWidget {
  final BoardTheme boardTheme;

  const _CheckersBoardPreview({required this.boardTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: CustomPaint(
        painter: _CheckersPreviewPainter(
          light: boardTheme.lightSquare,
          dark: boardTheme.darkSquare,
        ),
      ),
    );
  }
}

class _CheckersPreviewPainter extends CustomPainter {
  final Color light;
  final Color dark;

  const _CheckersPreviewPainter({required this.light, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 8;
    final cell = size.width / n;
    final lp = Paint()..color = light;
    final dp = Paint()..color = dark;
    final whiteDisc = Paint()..color = const Color(0xFFF5F0E0);
    final whiteEdge = Paint()
      ..color = const Color(0xFFD4C5A9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final blackDisc = Paint()..color = const Color(0xFF2A2017);
    final blackEdge = Paint()
      ..color = const Color(0xFF4A4030)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        final isDark = (r + c) % 2 == 1;
        canvas.drawRect(rect, isDark ? dp : lp);

        // Starting position: 12 dark discs (rows 0-2), 12 light (rows 5-7).
        if (!isDark) continue;
        if (r > 2 && r < 5) continue;
        final center = rect.center;
        final radius = cell * 0.36;
        if (r <= 2) {
          canvas.drawCircle(center, radius, blackDisc);
          canvas.drawCircle(center, radius, blackEdge);
        } else {
          canvas.drawCircle(center, radius, whiteDisc);
          canvas.drawCircle(center, radius, whiteEdge);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CheckersPreviewPainter old) =>
      old.light != light || old.dark != dark;
}

// ── Board Theme Swatch ─────────────────────────────────────────────────────────

class _BoardThemeSwatch extends StatelessWidget {
  final String label;
  final Color lightColor;
  final Color darkColor;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _BoardThemeSwatch({
    required this.label,
    required this.lightColor,
    required this.darkColor,
    required this.selected,
    required this.onTap,
    this.accent = _kAmber,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? accent : _kBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: GridView.count(
                crossAxisCount: 4,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(16, (i) {
                  final row = i ~/ 4;
                  final col = i % 4;
                  final isLight = (row + col) % 2 == 0;
                  return Container(color: isLight ? lightColor : darkColor);
                }),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: selected ? accent : _kInkDim,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Piece Set Swatch ──────────────────────────────────────────────────────────

class _PieceSetSwatch extends StatelessWidget {
  final String id;         // 'cburnett' | 'merida' | 'alpha'
  final String label;
  final Color lightColor;
  final Color darkColor;
  final bool selected;
  final VoidCallback onTap;

  const _PieceSetSwatch({
    required this.id,
    required this.label,
    required this.lightColor,
    required this.darkColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _kAmber : _kBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 2×2 mini checkerboard background
                  CustomPaint(
                    painter: _Mini2x2Painter(
                      light: lightColor,
                      dark: darkColor,
                    ),
                  ),
                  // King piece SVG
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SvgPicture.asset(
                      'assets/pieces/$id/wK.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: selected ? _kAmber : _kInkDim,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini2x2Painter extends CustomPainter {
  final Color light;
  final Color dark;

  const _Mini2x2Painter({required this.light, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width  / 2;
    final h = size.height / 2;
    final lp = Paint()..color = light;
    final dp = Paint()..color = dark;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), lp);
    canvas.drawRect(Rect.fromLTWH(w, 0, w, h), dp);
    canvas.drawRect(Rect.fromLTWH(0, h, w, h), dp);
    canvas.drawRect(Rect.fromLTWH(w, h, w, h), lp);
  }

  @override
  bool shouldRepaint(_Mini2x2Painter old) =>
      old.light != light || old.dark != dark;
}

// ── Shared local widgets ───────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Widget? right;
  final VoidCallback? onTap;
  final bool isLast;
  final Color accent;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
    this.right,
    this.onTap,
    this.isLast = false,
    this.accent = _kAmber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Center(
                    child: Icon(icon, color: accent, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kInk,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub!,
                          style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                        ),
                      ],
                    ],
                  ),
                ),
                right ??
                    Icon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                      color: _kInkMute,
                      size: 16,
                    ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Container(height: 1, color: _kBorder),
          ),
      ],
    );
  }
}

class _DesignToggle extends StatelessWidget {
  final bool on;
  final VoidCallback onToggle;
  final Color accent;

  const _DesignToggle({required this.on, required this.onToggle, this.accent = _kAmber});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: on ? accent : _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? accent : _kBorderStrong),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: on ? const Color(0xFF1A1205) : _kInk,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color accent;

  const _SegmentedControl({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.accent = _kAmber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: double.infinity,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Text(
                  options[i],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF1A1205) : _kInkMute,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

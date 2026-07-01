import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/campaign_chapter.dart';
import '../../../core/models/game_type.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/shimmer_box.dart';

// ── Chapter title list (short display names) ──────────────────────────────────

const List<String> _chapterTitles = [
  'First Steps',
  'Pawn Power',
  "Knight's Path",
  "Bishop's Diagonal",
  'Rook and Roll',
  'The Queen Awakens',
  'Royal Safety',
  'The Exchange',
  'Opening Principles',
  'The Middle Game',
  'Pins and Skewers',
  'Forks',
  'Discovered Attacks',
  'The Back Rank',
  'Zugzwang',
  'Endgame Basics',
  'King and Pawn',
  'Rook Endgames',
  'The Outpost',
  'Pawn Structures',
  'Isolated Pawns',
  'Passed Pawns',
  'Minority Attack',
  'Weak Squares',
  'Open Files',
  'The Sicilian',
  'French Defense',
  'Caro-Kann',
  "King's Indian",
  "Queen's Gambit",
  'The Initiative',
  'Sacrifices',
  'Attack on the King',
  'Defensive Play',
  'Counterplay',
  'Piece Coordination',
  'Space Advantage',
  'The Minority',
  'Prophylaxis',
  'Calculation',
  'The Ruy Lopez',
  'The Italian Game',
  'Nimzowitsch Defense',
  'The Grünfeld',
  'The Benoni',
  'The Dutch',
  'English Opening',
  'Réti Opening',
  'The Bird',
  'The Halfway Point',
  'Positional Mastery',
  'Tactical Vision',
  'The Endgame Art',
  'Strategic Plans',
  'Dynamic Play',
  'Imbalances',
  'Opposite Castling',
  'Closed Positions',
  'Open Games',
  'Pawn Majorities',
  'The Breakthrough',
  'Rook Activity',
  'Bishop vs Knight',
  'Two Bishops',
  'Knight Outposts',
  'Rook Behind Passed',
  'The Lucena',
  'The Philidor',
  'Complex Endgames',
  'The Exchange Sac',
  'Deep Calculation',
  'Endgame Technique',
  'The Windmill',
  'The Immortal',
  'Advanced Tactics',
  'Grandmaster Plans',
  'The Zugzwang Web',
  'Fortress Theory',
  'Interference',
  'The Clearance',
  'Deflection',
  'Decoy Tactics',
  'The Greek Gift',
  'Bxh7+ Themes',
  'The Brilliancy',
  'Mating Nets',
  'The Quiet Move',
  'Zwischenzug',
  'The Desperado',
  'Mutual Zugzwang',
  'Domination',
  'The Squeeze',
  'Opposite Bishops',
  'The Fortress',
  'Rook vs Pawns',
  'The Seven Pawns',
  'Almost There',
  'The Penultimate',
  'The Final Trial',
  "Champion's Crown",
];

String _chapterTitle(int chapter) {
  if (chapter < 1 || chapter > _chapterTitles.length) return 'Chapter $chapter';
  return _chapterTitles[chapter - 1];
}

// ── Act definitions ───────────────────────────────────────────────────────────

const List<String> _actNames = [
  'FOUNDATIONS',
  'TACTICS',
  'STRATEGY',
  'OPENINGS',
  'MIDDLE GAME',
  'ADVANCED',
  'MASTERY I',
  'MASTERY II',
  'GRANDMASTER',
  'CHAMPION',
];

String _romanNumeral(int n) => switch (n) {
      1  => 'I',
      2  => 'II',
      3  => 'III',
      4  => 'IV',
      5  => 'V',
      6  => 'VI',
      7  => 'VII',
      8  => 'VIII',
      9  => 'IX',
      10 => 'X',
      _  => '$n',
    };

/// Returns the section header label for the given 1-based act.
String _actLabel(int act) {
  final name  = act <= _actNames.length ? _actNames[act - 1] : 'ACT $act';
  final start = (act - 1) * 10 + 1;
  final end   = act * 10;
  return 'ACT ${_romanNumeral(act)} · $name · $start–$end';
}

// ── Font helpers ──────────────────────────────────────────────────────────────

TextStyle _mono({
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.inkMute,
  double letterSpacing = 0.6,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

TextStyle _fraunces({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  bool italic = true,
}) =>
    GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color,
    );

TextStyle _inter({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

// ── Winding path node positions ───────────────────────────────────────────────

// Pattern: columns snake left→center-right→far-right→center→left→...
// x positions: 16, 126, 196, 126, 16, 126, 196, 126, 16, ...
// Each step adds 70 in y.
const List<Offset> _nodePositions = [
  Offset(16, 4),
  Offset(126, 64),
  Offset(196, 134),
  Offset(126, 204),
  Offset(16, 274),
  Offset(126, 344),
  Offset(196, 414),
  Offset(126, 484),
  Offset(16, 554),
  Offset(126, 624),
  Offset(196, 694),
  Offset(126, 764),
  Offset(16, 834),
  Offset(126, 904),
  Offset(196, 974),
  Offset(126, 1044),
  Offset(16, 1114),
  Offset(126, 1184),
  Offset(196, 1254),
  Offset(126, 1324),
  Offset(16, 1394),
  Offset(126, 1464),
  Offset(196, 1534),
  Offset(126, 1604),
  Offset(16, 1674),
];

// ── Per-game accent (set by CampaignMapScreen.build, read by nested widgets) ─
Color _accent = AppColors.amber;

// ── Main screen ───────────────────────────────────────────────────────────────

class CampaignMapScreen extends ConsumerWidget {
  const CampaignMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final activeGame = ref.watch(activeGameProvider);
    final totalChapters = activeGame.identity.questChapters;
    _accent = activeGame.accent; // propagate to nested widgets

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        loading: () => Scaffold(
          backgroundColor: AppColors.background,
          body: const Padding(
            padding: EdgeInsets.all(20),
            child: ShimmerList(count: 6, itemHeight: 80),
          ),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) {
          final progress = switch (activeGame) {
            GameType.checkers => user?.checkersCampaignProgress ?? 0,
            GameType.domino   => user?.dominoCampaignProgress ?? 0,
            GameType.chess    => user?.campaignProgress ?? 0,
          };
          final nextChapter = (progress + 1).clamp(1, totalChapters);
          final percent = progress / totalChapters;

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────────
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
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                            color: AppColors.inkDim,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        activeGame.identity.questTitle,
                        style: _fraunces(
                          size: 22,
                          weight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Progress hero card ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ProgressHeroCard(
                    progress: progress,
                    percent: percent,
                    totalChapters: totalChapters,
                    accent: activeGame.accent,
                  ),
                ),

                const SizedBox(height: 10),

                // ── Up-next chapter card ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _UpNextCard(
                    progress: progress,
                    nextChapter: nextChapter,
                    accent: activeGame.accent,
                    gameType: activeGame,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Winding path section ─────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildActSections(progress, totalChapters, activeGame.accent),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds the list of act sections to display.
  ///
  /// Rule: Act N (chapters (N-1)×10+1 … N×10) is **unlocked** when
  /// [progress] >= (N-1)×10, i.e. the previous act is complete.
  ///
  /// We always show the unlocked acts plus one locked teaser act so the
  /// player can see what is coming next.
  static List<Widget> _buildActSections(int progress, int totalChapters, Color accent) {
    final totalActs = (totalChapters / 10).ceil();
    final nextChapter = (progress + 1).clamp(1, totalChapters);
    final currentAct  = ((nextChapter - 1) ~/ 10) + 1;
    final actsToShow  = (currentAct + 1).clamp(1, totalActs);

    final sections = <Widget>[];
    for (int act = 1; act <= actsToShow; act++) {
      final isLocked     = progress < (act - 1) * 10;
      final startChapter = (act - 1) * 10 + 1;

      sections.add(const SizedBox(height: 16));

      // Act divider header
      sections.add(_ActDivider(
        label: _actLabel(act),
        locked: isLocked,
      ));

      sections.add(const SizedBox(height: 16));

      // If the entire act is locked, show a compact locked-act placeholder
      // instead of a full 700 px winding path of lock icons.
      if (isLocked) {
        sections.add(_LockedActPlaceholder(act: act));
      } else {
        sections.add(_WindingPath(
          progress: progress,
          startChapter: startChapter,
        ));
      }

      sections.add(const SizedBox(height: 24));
    }
    return sections;
  }
}

// ── Progress hero card ────────────────────────────────────────────────────────

class _ProgressHeroCard extends StatelessWidget {
  final int progress;
  final double percent;
  final int totalChapters;
  final Color accent;

  const _ProgressHeroCard({
    required this.progress,
    required this.percent,
    required this.totalChapters,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Accent glow top-right
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accent.withValues(alpha: 0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: label + count + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROGRESS',
                      style: _mono(size: 10, color: AppColors.inkMute, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$progress',
                            style: _fraunces(size: 30, weight: FontWeight.w700, color: AppColors.ink),
                          ),
                          TextSpan(
                            text: '/$totalChapters',
                            style: _fraunces(size: 20, weight: FontWeight.w400, color: AppColors.inkMute),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress >= totalChapters
                          ? 'All chapters complete!'
                          : 'Chapter ${progress + 1} unlocked',
                      style: _inter(size: 12, weight: FontWeight.w500, color: accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right: circular progress ring
              SizedBox(
                width: 68,
                height: 68,
                child: CustomPaint(
                  painter: _CircularProgressPainter(percent: percent, accent: accent),
                  child: Center(
                    child: Text(
                      '${(percent * 100).round()}%',
                      style: _mono(size: 11, weight: FontWeight.w700, color: accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Circular progress ring (CustomPainter) ────────────────────────────────────

class _CircularProgressPainter extends CustomPainter {
  final double percent;
  final Color accent;
  const _CircularProgressPainter({required this.percent, this.accent = AppColors.amber});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (percent > 0) {
      // Progress arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fullSweep * percent,
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) => old.percent != percent;
}

// ── Up-next chapter card ──────────────────────────────────────────────────────

class _UpNextCard extends StatelessWidget {
  final int progress;
  final int nextChapter;
  final Color accent;
  final GameType gameType;

  const _UpNextCard({
    required this.progress,
    required this.nextChapter,
    required this.accent,
    required this.gameType,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = (nextChapter - 1).clamp(0, CampaignChapter.all.length - 1);
    final data = CampaignChapter.all[safeIndex];
    final title = _chapterTitle(nextChapter);
    final timeLabel = data.timeControl.label;
    final botRating = data.botRating;

    return GestureDetector(
      onTap: () => context.push('/home/campaign/$nextChapter'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // Left: chapter number badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: progress > 0
                  ? Text(
                      '$nextChapter',
                      style: _fraunces(
                        size: 18,
                        weight: FontWeight.w700,
                        color: const Color(0xFF1A1205),
                        italic: false,
                      ),
                    )
                  : Icon(
                      PhosphorIcons.lock(PhosphorIconsStyle.fill),
                      color: const Color(0xFF1A1205),
                      size: 20,
                    ),
            ),
            const SizedBox(width: 12),
            // Center: labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UP NEXT',
                    style: _mono(size: 9, color: accent, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: _fraunces(
                      size: 16,
                      weight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bot · $botRating ELO · $timeLabel',
                    style: _inter(size: 11, color: AppColors.inkDim),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
              color: accent,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Winding path ──────────────────────────────────────────────────────────────

class _WindingPath extends StatelessWidget {
  final int progress;

  /// First chapter number in this act (e.g. 1, 11, 21 …).
  final int startChapter;

  const _WindingPath({
    required this.progress,
    this.startChapter = 1,
  });

  // Every act has exactly 10 chapters.
  static const int _chaptersPerAct = 10;

  @override
  Widget build(BuildContext context) {
    // Total canvas height for 10 nodes (positions 0-9).
    final pathHeight = _nodePositions[_chaptersPerAct - 1].dy + 52 + 20;

    return SizedBox(
      width: double.infinity,
      height: pathHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dashed connecting path
          Positioned.fill(
            child: CustomPaint(
              painter: _PathPainter(
                progress: progress,
                nodeCount: _chaptersPerAct,
                startChapter: startChapter,
              ),
            ),
          ),
          // Chapter nodes
          for (int i = 0; i < _chaptersPerAct; i++)
            _ChapterNode(
              chapter: startChapter + i,
              progress: progress,
              position: _nodePositions[i],
            ),
        ],
      ),
    );
  }
}

// ── Path painter ──────────────────────────────────────────────────────────────

class _PathPainter extends CustomPainter {
  final int progress;
  final int nodeCount;

  /// Chapter number at node 0 (e.g. 1 for Act I, 11 for Act II).
  final int startChapter;

  const _PathPainter({
    required this.progress,
    required this.nodeCount,
    this.startChapter = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const nodeSize = 52.0;
    final centers = List.generate(
      nodeCount,
      (i) => Offset(
        _nodePositions[i].dx + nodeSize / 2,
        _nodePositions[i].dy + nodeSize / 2,
      ),
    );

    for (int i = 0; i < centers.length - 1; i++) {
      final from = centers[i];
      final to   = centers[i + 1];
      // Segment between node i and i+1 is "done" if chapter (startChapter+i)
      // has already been completed, i.e. its number ≤ progress.
      final isCompleted = (startChapter + i) <= progress;
      _drawDashedLine(canvas, from, to, isCompleted);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, bool completed) {
    final color = completed ? AppColors.win : AppColors.border;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final total = (to - from).distance;
    const dashLen = 8.0;
    const gapLen  = 6.0;
    final dir = (to - from) / total;

    double drawn = 0;
    bool dash = true;
    while (drawn < total) {
      final segLen = dash ? dashLen : gapLen;
      final end = drawn + segLen;
      if (dash) {
        canvas.drawLine(
          from + dir * drawn,
          from + dir * math.min(end, total),
          paint,
        );
      }
      drawn = end;
      dash = !dash;
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.progress != progress || old.startChapter != startChapter;
}

// ── Chapter node ──────────────────────────────────────────────────────────────

class _ChapterNode extends StatelessWidget {
  final int chapter;
  final int progress;
  final Offset position;

  const _ChapterNode({
    required this.chapter,
    required this.progress,
    required this.position,
  });

  bool get isDone => chapter <= progress;
  bool get isCurrent => chapter == progress + 1;
  bool get isLocked => chapter > progress + 1;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;

    Color bgColor;
    Color borderColor;
    Widget centerChild;
    List<BoxShadow>? shadows;

    if (isDone) {
      bgColor = AppColors.winSoft;
      borderColor = AppColors.win.withValues(alpha: 0.5);
      centerChild = const Text('✓',
          style: TextStyle(color: AppColors.win, fontSize: 22, fontWeight: FontWeight.w700));
      shadows = [
        BoxShadow(color: AppColors.win.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 1),
      ];
    } else if (isCurrent) {
      bgColor = _accent;
      borderColor = _accent;
      centerChild = Text(
        '$chapter',
        style: _fraunces(size: 18, weight: FontWeight.w700, color: const Color(0xFF1A1205)),
      );
      shadows = [
        BoxShadow(color: _accent.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 2),
      ];
    } else {
      bgColor = AppColors.card;
      borderColor = AppColors.border;
      centerChild = Icon(
        PhosphorIcons.lock(PhosphorIconsStyle.fill),
        color: AppColors.inkMute,
        size: 20,
      );
    }

    // Align to the right side for positions > 100 px
    final showLabel = isDone || isCurrent;
    final labelOnRight = position.dx < 100;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!labelOnRight && showLabel) ...[
            _NodeLabel(chapter: chapter, isDone: isDone),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: (isDone || isCurrent)
                ? () => context.push('/home/campaign/$chapter')
                : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Dashed ring for current
                if (isCurrent)
                  Positioned(
                    left: -5,
                    top: -5,
                    child: SizedBox(
                      width: size + 10,
                      height: size + 10,
                      child: CustomPaint(painter: _DashedRingPainter()),
                    ),
                  ),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 2),
                    boxShadow: shadows,
                  ),
                  alignment: Alignment.center,
                  child: centerChild,
                ),
              ],
            ),
          ),
          if (labelOnRight && showLabel) ...[
            const SizedBox(width: 8),
            _NodeLabel(chapter: chapter, isDone: isDone),
          ],
        ],
      ),
    );
  }
}

// ── Node label ────────────────────────────────────────────────────────────────

class _NodeLabel extends StatelessWidget {
  final int chapter;
  final bool isDone;

  const _NodeLabel({required this.chapter, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Text(
        _chapterTitle(chapter),
        style: _inter(
          size: 11,
          color: isDone ? AppColors.win : _accent,
          weight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Dashed ring for current node ──────────────────────────────────────────────

class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;

    final paint = Paint()
      ..color = _accent.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashCount = 16;
    const dashLen = math.pi * 2 / dashCount / 2;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (math.pi * 2 / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLen,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}

// ── Act divider ───────────────────────────────────────────────────────────────

class _ActDivider extends StatelessWidget {
  final String label;
  final bool locked;

  const _ActDivider({required this.label, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final lineColor = locked ? AppColors.border.withValues(alpha: 0.4) : AppColors.border;
    final textColor = locked ? AppColors.inkMute.withValues(alpha: 0.4) : AppColors.inkMute;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: lineColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                Icon(Icons.lock_outline_rounded,
                    size: 10, color: textColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: _mono(size: 10, color: textColor, letterSpacing: 1.0),
              ),
            ],
          ),
        ),
        Expanded(child: Container(height: 1, color: lineColor)),
      ],
    );
  }
}

// ── Locked act placeholder ────────────────────────────────────────────────────

/// Shown for acts that are not yet unlocked (next-act teaser).
class _LockedActPlaceholder extends StatelessWidget {
  final int act;

  const _LockedActPlaceholder({required this.act});

  @override
  Widget build(BuildContext context) {
    final chaptersNeeded = (act - 1) * 10;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: AppColors.inkMute.withValues(alpha: 0.5),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Locked',
                  style: _inter(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.inkMute.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Complete $chaptersNeeded chapters to unlock',
                  style: _inter(
                    size: 11,
                    color: AppColors.inkMute.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

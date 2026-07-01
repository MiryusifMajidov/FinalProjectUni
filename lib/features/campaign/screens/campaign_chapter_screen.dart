import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/campaign_chapter.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/services/auth_service.dart';

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

// ── Checkers chapter titles (60 chapters) ────────────────────────────────────

const List<String> _checkersChapterTitles = [
  'First Moves', 'Capture Rules', 'The Forced Jump', 'Corner Control',
  'Double Jump', 'King Me!', 'King Power', 'Center Control',
  'The Bridge', 'Trapping Pieces', 'The Exchange', 'Side Play',
  'Two for One', 'The Fork', 'Diagonal Lanes', 'King Chase',
  'The Dog Hole', 'The Dyke', 'Back Row Defense', 'The Elbow',
  'Man Down', 'King vs King', 'The Move', 'Shot Play',
  'Pitch & Sacrifice', 'The In-and-Out', 'First Position', 'The Octopus',
  'Breeches', 'The Coup', 'Payne Draw', 'Cross-Board Kings',
  'The Slip', 'Threading', 'The Skewer', 'Phalanx',
  'Triangle Formation', 'Squeeze Play', 'The Block', 'Tempo',
  'Opposition', 'King Traps', 'Multi-Jump Combos', 'The Spinner',
  'Back Rank Tricks', 'Advanced Shots', 'Waiting Moves', 'Connected Men',
  'Clearance Sac', 'The Decoy', 'Endgame Kings', 'Two vs One',
  'Three Kings', 'Deep Calculation', 'Positional Play', 'Grand Combo',
  'The Windmill', 'The Masterpiece', 'Final Challenge', 'Diagonal Champion',
];

// ── Domino chapter titles (40 chapters) ──────────────────────────────────────

const List<String> _dominoChapterTitles = [
  'First Bone', 'Matching Ends', 'The Spinner', 'Doubles',
  'Counting Pips', 'Blocking', 'The Pass', 'End Game Basics',
  'Heavy Tiles', 'Light Strategy', 'The Opener', 'Chain Building',
  'Reading the Board', 'Pip Counting', 'The Block Game', 'Score Attack',
  'The Sweep', 'Memory Play', 'Forcing Plays', 'The Domino Effect',
  'Double Trouble', 'End Control', 'The Closer', 'Tile Tracking',
  'The Squeeze', 'Advanced Blocking', 'Multi-Round', 'Point Racing',
  'The Spinner Master', 'Board Reading', 'Strategic Pass', 'Heavy Hand',
  'The Combo', 'Endgame Tactics', 'Perfect Plays', 'The Setup',
  'Chain Mastery', 'The Blitz Round', 'Final Challenge', 'Bones Champion',
];

String _chapterTitle(int chapter, GameType gameType) {
  final titles = switch (gameType) {
    GameType.checkers => _checkersChapterTitles,
    GameType.domino   => _dominoChapterTitles,
    GameType.chess    => _chapterTitles,
  };
  if (chapter < 1 || chapter > titles.length) return 'Chapter $chapter';
  return titles[chapter - 1];
}

// Piece emoji per chapter group
String _pieceEmoji(int chapter, GameType gameType) {
  if (gameType == GameType.checkers) {
    if (chapter <= 15) return '⛀';
    if (chapter <= 30) return '⛁';
    if (chapter <= 45) return '⛂';
    return '⛃';
  }
  if (gameType == GameType.domino) {
    if (chapter <= 10) return '🁫';
    if (chapter <= 20) return '🁣';
    if (chapter <= 30) return '🁳';
    return '🂓';
  }
  // Chess
  if (chapter <= 10) return '♙';
  if (chapter <= 20) return '♘';
  if (chapter <= 30) return '♗';
  if (chapter <= 40) return '♖';
  if (chapter <= 50) return '♕';
  if (chapter <= 60) return '♔';
  if (chapter <= 70) return '♙';
  if (chapter <= 80) return '♘';
  if (chapter <= 90) return '♗';
  return '♛';
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

// ── Screen ────────────────────────────────────────────────────────────────────

class CampaignChapterScreen extends ConsumerWidget {
  final int chapter;
  const CampaignChapterScreen({super.key, required this.chapter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGame = ref.watch(activeGameProvider);
    final totalChapters = activeGame.identity.questChapters;
    final data = CampaignChapter.all[chapter - 1];
    final title = _chapterTitle(chapter, activeGame);
    final piece = _pieceEmoji(chapter, activeGame);
    final accent = activeGame.accent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: back button only ────────────────────────────────────
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
                ],
              ),
            ),

            // ── Scrollable content ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Chapter badge pill
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'CHAPTER $chapter OF $totalChapters',
                          style: _mono(
                            size: 10,
                            color: accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(),

                    const SizedBox(height: 14),

                    // Large chapter title
                    Text(
                      title,
                      style: _fraunces(
                        size: 44,
                        weight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.08),

                    const SizedBox(height: 20),

                    // Piece portrait card
                    _PiecePortraitCard(
                      chapter: chapter,
                      piece: piece,
                      flavorText: data.flavorText,
                      accent: accent,
                    ).animate(delay: 100.ms).fadeIn(),

                    const SizedBox(height: 16),

                    // Stats row
                    _StatsRow(data: data, accent: accent)
                        .animate(delay: 140.ms).fadeIn(),

                    const SizedBox(height: 20),

                    // Objectives section
                    Text(
                      'OBJECTIVES',
                      style: _mono(
                        size: 11,
                        color: AppColors.inkMute,
                        letterSpacing: 1.2,
                      ),
                    ).animate(delay: 180.ms).fadeIn(),

                    const SizedBox(height: 10),

                    ...[
                      _ObjectiveRow(
                        label: 'Win the game',
                        xp: '+5 XP',
                        delay: 200,
                        accent: accent,
                      ),
                      _ObjectiveRow(
                        label: 'Make a capture',
                        xp: '+5 XP',
                        delay: 240,
                        accent: accent,
                      ),
                      _ObjectiveRow(
                        label: 'Complete in under 40 moves',
                        xp: '+5 XP',
                        delay: 280,
                        accent: accent,
                      ),
                    ],

                    const SizedBox(height: 80), // space for sticky CTAs
                  ],
                ),
              ),
            ),

            // ── Sticky bottom CTAs ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Begin Chapter" button with game accent
                  GestureDetector(
                    onTap: () => _startChapter(context, ref, data),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Begin Chapter',
                        style: _inter(
                          size: 15,
                          weight: FontWeight.w700,
                          color: const Color(0xFF1A1205),
                        ),
                      ),
                    ),
                  ).animate(delay: 320.ms).fadeIn().slideY(begin: 0.15),

                  const SizedBox(height: 10),

                  // Outline "Back to Map"
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: double.infinity,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Back to Map',
                        style: _inter(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.inkDim,
                        ),
                      ),
                    ),
                  ).animate(delay: 360.ms).fadeIn(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChapter(
    BuildContext context,
    WidgetRef ref,
    CampaignChapter data,
  ) async {
    final user = await ref.read(currentUserProvider.future);
    final gt = ref.read(activeGameProvider);
    final gameId = const Uuid().v4();

    if (!context.mounted) return;
    context.push(gt.gameRoute(gameId), extra: {
      'mode': GameMode.campaign.name,
      'gameType': gt.name,
      'timeControl': data.timeControl.toMap(),
      'playerIsWhite': true,
      'botRating': data.botRating,
      'isRated': false,
      'myUsername': user?.username ?? 'You',
      'opponentUsername': 'Bot (${data.botRating})',
      'campaignChapter': chapter,
    });
  }
}

// ── Piece portrait card ───────────────────────────────────────────────────────

class _PiecePortraitCard extends StatelessWidget {
  final int chapter;
  final String piece;
  final String flavorText;
  final Color accent;

  const _PiecePortraitCard({
    required this.chapter,
    required this.piece,
    required this.flavorText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardElevated, AppColors.card],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Radial circle with game piece/emoji
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [accent, accent.withValues(alpha: 0.7)],
                radius: 0.85,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              piece,
              style: const TextStyle(fontSize: 38),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              flavorText,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.inkDim,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final CampaignChapter data;
  final Color accent;

  const _StatsRow({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: PhosphorIcons.robot(PhosphorIconsStyle.regular),
            label: 'Bot Rating',
            value: '${data.botRating}',
            accent: accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: PhosphorIcons.timer(PhosphorIconsStyle.regular),
            label: 'Time',
            value: data.timeControl.label,
            accent: accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
            label: 'Reward',
            value: '+20 XP',
            valueColor: accent,
            accent: accent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: AppColors.inkMute,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.fraunces(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.ink,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Objective row ─────────────────────────────────────────────────────────────

class _ObjectiveRow extends StatelessWidget {
  final String label;
  final String xp;
  final int delay;
  final Color accent;

  const _ObjectiveRow({
    required this.label,
    required this.xp,
    required this.delay,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Circle checkbox (unchecked)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 2),
                color: AppColors.surface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.inkDim,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                xp,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideX(begin: 0.04);
  }
}

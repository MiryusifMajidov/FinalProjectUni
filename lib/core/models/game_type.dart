import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';

/// The three game types supported by Grandmaster.
enum GameType {
  chess,
  checkers,
  domino,
}

/// Visual identity for each game type — accent colour, glyph, gradient, labels.
/// Mirrors the GAMES constant from the design system (screens-8.jsx).
class GameIdentity {
  final GameType type;
  final String name;
  final String glyph;
  final Color accent;
  final Color accentSoft;  // 14 % opacity variant
  final List<Color> gradientColors;
  final String questTitle;
  final int questChapters;

  const GameIdentity({
    required this.type,
    required this.name,
    required this.glyph,
    required this.accent,
    required this.accentSoft,
    required this.gradientColors,
    required this.questTitle,
    required this.questChapters,
  });
}

/// Per-game identity data from the design system.
const Map<GameType, GameIdentity> kGameIdentities = {
  GameType.chess: GameIdentity(
    type: GameType.chess,
    name: 'Chess',
    glyph: '♞', // ♞
    accent: AppColors.amber,                   // #E8B960
    accentSoft: Color(0x24E8B960),
    gradientColors: [Color(0xFF1f1709), Color(0xFF3d2410)],
    questTitle: 'Grandmaster Path',
    questChapters: 100,
  ),
  GameType.checkers: GameIdentity(
    type: GameType.checkers,
    name: 'Checkers',
    glyph: '⛀', // ⛀
    accent: Color(0xFF6FB4E0),                 // #6FB4E0
    accentSoft: Color(0x246FB4E0),
    gradientColors: [Color(0xFF0a1620), Color(0xFF102a3d)],
    questTitle: 'Diagonal Road',
    questChapters: 60,
  ),
  GameType.domino: GameIdentity(
    type: GameType.domino,
    name: 'Domino',
    glyph: '🁫', // domino tile emoji fallback
    accent: Color(0xFF5FD4A3),                 // #5FD4A3
    accentSoft: Color(0x245FD4A3),
    gradientColors: [Color(0xFF0a1f16), Color(0xFF0f3329)],
    questTitle: 'Bones Trail',
    questChapters: 40,
  ),
};

/// Convenience extension on GameType to quickly access its identity.
extension GameTypeX on GameType {
  GameIdentity get identity => kGameIdentities[this]!;
  String get label => identity.name;
  Color get accent => identity.accent;
  Color get accentSoft => identity.accentSoft;
  String get glyph => identity.glyph;

  /// Whether this game uses a point system (300 start, min 100)
  /// instead of chess-style ELO (1200 start).
  bool get isPointBased => this != GameType.chess;

  /// Default starting score for new users.
  int get defaultScore => isPointBased ? 300 : 1200;

  /// Minimum score floor (only enforced for point-based games).
  int get minScore => isPointBased ? 100 : 0;

  /// Score label — "Points" for checkers/domino, "Rating" for chess.
  String get scoreLabel => isPointBased ? 'Points' : 'Rating';

  /// Calculates point change for point-based games (checkers / domino).
  ///
  /// Algorithm:
  ///  - Win base: +25, adjusted ±8 by opponent strength difference
  ///  - Loss base: -20, adjusted ±8 by opponent strength difference
  ///  - Draw: small ±5 shift toward the stronger player
  ///  - Floor: score never drops below [minScore]
  int calculatePointChange({
    required int myPoints,
    required int opponentPoints,
    required bool won,
    required bool lost,
  }) {
    if (!won && !lost) {
      // Draw — slight pull toward the stronger player
      final diff = opponentPoints - myPoints;
      return (diff / 80).round().clamp(-5, 5);
    }

    final diff = opponentPoints - myPoints;
    // Bonus/penalty based on opponent strength gap (capped at ±8)
    final adjustment = (diff / 60).round().clamp(-8, 8);

    int change;
    if (won) {
      change = 25 + adjustment; // 17 – 33 range
      if (change < 10) change = 10; // always gain at least 10 on win
    } else {
      change = -20 + adjustment; // -12 – -28 range
      // Enforce floor: can't drop below minScore
      final projected = myPoints + change;
      if (projected < minScore) {
        change = myPoints <= minScore ? 0 : -(myPoints - minScore);
      }
    }
    return change;
  }

  /// Checkers variant options for matchmaking.
  static const checkersVariants = [
    ('standard', 'Standard (8×8)'),
    ('russian', 'Russian (8×8)'),
    ('international', 'International (10×10)'),
    ('turkish', 'Turkish'),
    ('brazilian', 'Brazilian'),
  ];

  /// Domino player count options for matchmaking.
  static const dominoPlayerCounts = [
    ('2-player', '2 Players'),
    ('4-player', '4 Players'),
  ];

  /// Domino ruleset variants (Draw = boneyard drawing, Block = pass when stuck).
  static const dominoVariants = [
    ('draw', 'Draw'),
    ('block', 'Block'),
  ];

  /// Domino match target scores.
  static const dominoTargets = [100, 150, 200];

  /// Per-game fake bot names used in matchmaking bot fallback.
  List<String> get fakeBotNames => switch (this) {
    GameType.chess => const [
      'NightRider88', 'CastleKing', 'BlitzMaster42', 'QueenSlayer',
      'PawnStorm', 'KnightErrant', 'TacticalGuru', 'OpeningTheory',
      'EndgamePro', 'SilentBishop', 'CheckmateAce', 'ForkMaster99',
      'PinAndWin', 'Grandmaster_X', 'RookLifter', 'MiddleGame77',
      'SicilianKing', 'CatoTheFish', 'IronDefense', 'TacticsWizard',
    ],
    GameType.checkers => const [
      'JumpKing', 'DoubleJump', 'KingMeNow', 'DiagonalDash',
      'CrownSeeker', 'MultiCapture', 'BackRowHero', 'CornerKing',
      'CheckerChamp', 'DiscMaster', 'KingHunter', 'JumpStreak',
      'CaptureQueen', 'BoardSweeper', 'RedDisc99', 'DiscSlider',
      'CornerTrap', 'DoubleKing', 'RowRunner', 'JumpForce',
    ],
    GameType.domino => const [
      'BoneyardKing', 'TileShark', 'DoubleSixer', 'PipCounter',
      'DominoWiz', 'TileChain', 'BlockMaster', 'SpinnerKing',
      'DrawPile', 'TableRunner', 'DotMatrix', 'BoneYard88',
      'TileSnap', 'EndGame99', 'ChainLink', 'PipTracker',
      'BlockDrop', 'TileMaster', 'DominoAce', 'SnapPlay',
    ],
  };

  /// Per-game searching orb emoji.
  String get searchEmoji => switch (this) {
    GameType.chess    => '♟',
    GameType.checkers => '⛀',
    GameType.domino   => '🁫',
  };

  /// Route path to the correct game screen for this game type.
  String gameRoute(String gameId) => switch (this) {
    GameType.chess    => '/game/$gameId',
    GameType.checkers => '/checkers-game/$gameId',
    GameType.domino   => '/domino-game/$gameId',
  };

  /// Route path to the correct bot setup screen.
  String get botSetupRoute => switch (this) {
    GameType.chess    => '/home/bot-setup',
    GameType.checkers => '/home/checkers-bot-setup',
    GameType.domino   => '/home/domino-bot-setup',
  };

  /// Parse from a stored string (Firestore / RTDB). Falls back to chess.
  static GameType fromString(String? s) => switch (s) {
    'checkers' => GameType.checkers,
    'domino'   => GameType.domino,
    _          => GameType.chess,
  };
}

// ── Active-game provider ────────────────────────────────────────────────────
// Tracks which game the user currently has selected in the UI.
// Persists across tab changes within the same session.

class ActiveGameNotifier extends StateNotifier<GameType> {
  ActiveGameNotifier() : super(GameType.chess);

  void select(GameType type) => state = type;
}

final activeGameProvider =
    StateNotifierProvider<ActiveGameNotifier, GameType>(
  (ref) => ActiveGameNotifier(),
);

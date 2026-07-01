import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';

/// Checkers-specific bot setup.
/// Design-matched to chess BotSetupScreen but with Checkers accent (#6FB4E0)
/// and the 6 Checkers bot tiers from PLAY_META.checkers.botTiers.
class CheckersBotSetupScreen extends StatefulWidget {
  const CheckersBotSetupScreen({super.key});

  @override
  State<CheckersBotSetupScreen> createState() => _CheckersBotSetupScreenState();
}

class _CheckersBotSetupScreenState extends State<CheckersBotSetupScreen> {
  static const _accent = Color(0xFF6FB4E0);
  static const _accentSoft = Color(0x246FB4E0);

  int _selectedTier = 0;
  bool _playAsWhite = true;
  int _selectedVariant = 0;

  static const _tiers = [
    ('Novice',   600,  1),
    ('Club',     1000, 2),
    ('Skilled',  1400, 3),
    ('Sharp',    1700, 4),
    ('Master',   2000, 5),
    ('Champion', 2300, 6),
  ];

  // (key, label) — matches CheckersVariant parsing in the game screen.
  static const _variants = [
    ('standard',      'Standard 8×8'),
    ('russian',       'Russian 8×8'),
    ('international', 'International 10×10'),
    ('turkish',       'Turkish'),
    ('brazilian',     'Brazilian'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
            color: AppColors.ink,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⛀ ', style: TextStyle(fontSize: 18)),
            Text(
              'Play vs Bot',
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable options — the Start button stays pinned below.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const SizedBox(height: 20),
              // ── Difficulty ────────────────────────────────────────────
              Text(
                'DIFFICULTY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMute,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              ..._tiers.asMap().entries.map((e) {
                final i = e.key;
                final (name, elo, _) = e.value;
                final selected = i == _selectedTier;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTier = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? _accentSoft : AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? _accent.withValues(alpha: 0.4)
                              : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Level indicator dots
                          Row(
                            children: List.generate(
                              6,
                              (d) => Container(
                                width: 6, height: 6,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: d <= i
                                      ? _accent
                                      : AppColors.inkFaint,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              color: selected ? _accent : AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '~$elo',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected ? _accent : AppColors.inkDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 60 * i))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.05);
              }),

              const SizedBox(height: 24),

              // ── Play as ──────────────────────────────────────────────
              Text(
                'PLAY AS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMute,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _SideButton(
                    label: 'White',
                    selected: _playAsWhite,
                    color: const Color(0xFFF5F0E0),
                    accentColor: _accent,
                    onTap: () => setState(() => _playAsWhite = true),
                  ),
                  const SizedBox(width: 10),
                  _SideButton(
                    label: 'Black',
                    selected: !_playAsWhite,
                    color: const Color(0xFF2A2017),
                    accentColor: _accent,
                    onTap: () => setState(() => _playAsWhite = false),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Variant ──────────────────────────────────────────────
              Text(
                'VARIANT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMute,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _variants.asMap().entries.map((e) {
                  final i = e.key;
                  final (_, label) = e.value;
                  final selected = i == _selectedVariant;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedVariant = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _accentSoft : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? _accent.withValues(alpha: 0.4)
                              : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? _accent : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Sticky Play button ────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF0A0A0B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Start Game',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0A0A0B),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startGame() {
    final (_, elo, depth) = _tiers[_selectedTier];
    final (variantKey, _) = _variants[_selectedVariant];
    final gameId = const Uuid().v4();
    context.push('/checkers-game/$gameId', extra: {
      'mode': 'bot',
      'gameType': 'checkers',
      'playerIsWhite': _playAsWhite,
      'botDepth': depth,
      'botRating': elo,
      'isRated': false,
      'myUsername': 'You',
      'opponentUsername': 'Bot ($elo)',
      'checkersVariant': variantKey,
    });
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color accentColor;
  final VoidCallback onTap;

  const _SideButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.12)
                : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: AppColors.borderStrong, width: 2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? accentColor : AppColors.inkDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF0A0A0B);
const _kCard      = Color(0xFF1A1A1E);
const _kAmber     = Color(0xFFE8B960);
const _kAmberGlow = Color(0x24E8B960);
const _kInk       = Color(0xFFF5F3EF);
const _kInkDim    = Color(0xFFB0A898);
const _kInkMute   = Color(0xFF706860);
const _kBorder    = Color(0xFF2A2520);

// ── Level data ─────────────────────────────────────────────────────────────────
class _Level {
  final String label;
  final String copy;
  final int elo;
  final String glyph;   // chess piece Unicode
  final Color color;

  const _Level({
    required this.label,
    required this.copy,
    required this.elo,
    required this.glyph,
    required this.color,
  });
}

const _levels = [
  _Level(label: 'Beginner',     copy: 'Just learning the moves', elo: 400,  glyph: '♙', color: Color(0xFFA8C8E8)),
  _Level(label: 'Casual',       copy: 'Plays with friends',       elo: 800,  glyph: '♘', color: Color(0xFFA8E8C8)),
  _Level(label: 'Intermediate', copy: 'Knows openings',           elo: 1200, glyph: '♗', color: Color(0xFFE8B960)),
  _Level(label: 'Advanced',     copy: 'Studies tactics daily',    elo: 1600, glyph: '♖', color: Color(0xFFE8B0A8)),
  _Level(label: 'Expert',       copy: 'Tournament player',        elo: 2000, glyph: '♕', color: Color(0xFFC8A8E8)),
  _Level(label: 'Master',       copy: 'Title-caliber play',       elo: 2400, glyph: '♔', color: Color(0xFFE8C8A0)),
];

class SkillLevelScreen extends StatefulWidget {
  const SkillLevelScreen({super.key});

  @override
  State<SkillLevelScreen> createState() => _SkillLevelScreenState();
}

class _SkillLevelScreenState extends State<SkillLevelScreen> {
  int _selected = 2; // default Intermediate

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── AuthHeader ────────────────────────────────────────────
                _AuthHeader(title: 'Your Level', step: 2, onBack: () => context.pop()),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          "What's your level?",
                          style: GoogleFonts.fraunces(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: _kInk,
                            letterSpacing: -0.8,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "We'll set your starting ELO. You can always change it later.",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _kInkDim,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 2-column grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _levels.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.9,
                          ),
                          itemBuilder: (context, i) {
                            final level = _levels[i];
                            final selected = _selected == i;
                            return _LevelCard(
                              level: level,
                              selected: selected,
                              onTap: () => setState(() => _selected = i),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Sticky CTA ────────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _kBg.withValues(alpha: 0),
                      _kBg,
                      _kBg,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                child: GestureDetector(
                  onTap: () => context.push('/auth/profile-photo'),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _kAmber.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Create my account',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1205),
                      ),
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
}

// ── Level card ─────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final _Level level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _kAmberGlow : _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _kAmber : _kBorder,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAmber.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Piece icon box
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: level.color.withValues(alpha: 0.15),
                    border: Border.all(
                        color: level.color.withValues(alpha: 0.28)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    level.glyph,
                    style: TextStyle(
                      fontSize: 22,
                      color: level.color,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  level.label,
                  style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  level.copy,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _kInkMute,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${level.elo} ELO',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? _kAmber : _kInkDim,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            // Check badge
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: _kAmber,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIcons.check(PhosphorIconsStyle.bold),
                    size: 12,
                    color: const Color(0xFF1A1205),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Auth Header ────────────────────────────────────────────────────────────────

class _AuthHeader extends StatelessWidget {
  final String title;
  final int step;
  final VoidCallback onBack;

  const _AuthHeader({
    required this.title,
    required this.step,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
                color: _kInk,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: _kInk,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Step pills
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 1; i <= 2; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: i == step ? 22 : 14,
                  height: 5,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: i == step ? _kAmber : _kBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/services/auth_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF0A0A0B);
const _kCard      = Color(0xFF1A1A1E);
const _kAmber     = Color(0xFFE8B960);
const _kAmberDeep = Color(0xFFC49A45);
const _kAmberGlow = Color(0x24E8B960);
const _kInk       = Color(0xFFF5F3EF);
const _kInkDim    = Color(0xFFB0A898);
const _kInkMute   = Color(0xFF706860);
const _kBorder    = Color(0xFF2A2520);

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Animated "searching for an opponent" screen shown after the user taps
/// "Find Game" in the matchmaking flow.
///
/// Extras accepted via GoRouter:
///   timeLabel  – display string, e.g. '5 MIN'
///   isRated    – bool (default true)
///   minElo     – int lower bound of ELO search window
///   maxElo     – int upper bound
class MatchmakingSearchScreen extends ConsumerStatefulWidget {
  final String timeLabel;
  final bool isRated;
  final int minElo;
  final int maxElo;

  const MatchmakingSearchScreen({
    super.key,
    this.timeLabel = '5 MIN',
    this.isRated = true,
    required this.minElo,
    required this.maxElo,
  });

  @override
  ConsumerState<MatchmakingSearchScreen> createState() =>
      _MatchmakingSearchScreenState();
}

class _MatchmakingSearchScreenState
    extends ConsumerState<MatchmakingSearchScreen> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final myRating = user?.overallRating ?? 1200;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
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
                    'matchmaking'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),

            // ── Main content ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing orb
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer thin ring
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _kAmber.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Three staggered pulse rings
                        const _PulseRing(delay: Duration.zero),
                        _PulseRing(
                            delay: const Duration(milliseconds: 800)),
                        _PulseRing(
                            delay: const Duration(milliseconds: 1600)),
                        // Inner amber orb with pawn glyph
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.3, -0.3),
                              colors: [
                                Color(0xFFE8C87A),
                                _kAmberDeep,
                                Color(0xFF5C3A14),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 30,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.15),
                                blurRadius: 6,
                                spreadRadius: -4,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '♟',
                              style: TextStyle(
                                fontSize: 48,
                                color: const Color(0xFFFAF7F0),
                                shadows: [
                                  Shadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Label
                  Text(
                    'searching_opponent'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kInkDim,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Elapsed timer
                  Text(
                    _formattedTime,
                    style: GoogleFonts.fraunces(
                      fontSize: 56,
                      fontWeight: FontWeight.w500,
                      color: _kAmber,
                      letterSpacing: -2,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ELO range pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text(
                      'ELO ${widget.minElo} – ${widget.maxElo}'
                      ' · ${widget.timeLabel}'
                      ' · ${widget.isRated ? 'RATED' : 'CASUAL'}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: _kInkDim,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatItem(
                        label: 'YOUR ELO',
                        value: myRating.toString(),
                        valueColor: _kAmber,
                      ),
                      const SizedBox(width: 24),
                      const _StatItem(
                        label: 'IN QUEUE',
                        value: '—',
                        valueColor: _kInk,
                      ),
                      const SizedBox(width: 24),
                      _StatItem(
                        label: 'AVG WAIT',
                        value: '~${_seconds < 10 ? 10 : _seconds}s',
                        valueColor: _kInk,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Cancel ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'cancel'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
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

// ── Pulse ring ────────────────────────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  final Duration delay;
  const _PulseRing({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kAmberGlow,
        border: Border.all(
          color: _kAmber.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .custom(
          delay: delay,
          duration: const Duration(milliseconds: 2400),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.6 + value * 0.8,
              child: Opacity(
                opacity: (1.0 - value) * 0.65,
                child: child,
              ),
            );
          },
        );
  }
}

// ── Stat item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            color: _kInkMute,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: valueColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

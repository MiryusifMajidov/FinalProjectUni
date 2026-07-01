import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kCard        = Color(0xFF1A1A1E);
const _kCardElevated = Color(0xFF1E1E23);
const _kAmber       = Color(0xFFE8B960);
const _kInk         = Color(0xFFF5F3EF);
const _kInkDim      = Color(0xFFB0A898);
const _kBorder      = Color(0xFF2A2520);
const _kWin         = Color(0xFF5AB67A);
const _kLoss        = Color(0xFFF07079);
const _kLossSoft    = Color(0x22F07079);

enum GameOutcome { win, loss, draw }

class GameResultSheet extends StatelessWidget {
  final GameOutcome outcome;
  final String reason;         // e.g. "by Resignation", "by Checkmate", "½-½"
  final int currentRating;
  final int ratingDelta;       // negative for loss, positive for win, 0 for draw

  final VoidCallback? onRematch;
  final VoidCallback? onNewOpponent;

  const GameResultSheet({
    super.key,
    required this.outcome,
    required this.reason,
    required this.currentRating,
    required this.ratingDelta,
    this.onRematch,
    this.onNewOpponent,
  });

  Color get _outcomeColor => switch (outcome) {
        GameOutcome.win  => _kWin,
        GameOutcome.loss => _kLoss,
        GameOutcome.draw => _kAmber,
      };

  IconData get _outcomeIcon => switch (outcome) {
        GameOutcome.win  => PhosphorIcons.crown(PhosphorIconsStyle.fill),
        GameOutcome.loss => PhosphorIcons.flag(PhosphorIconsStyle.regular),
        GameOutcome.draw => PhosphorIcons.handshake(PhosphorIconsStyle.regular),
      };

  String get _outcomeLabel => switch (outcome) {
        GameOutcome.win  => 'you_won'.tr(),
        GameOutcome.loss => 'you_lost'.tr(),
        GameOutcome.draw => 'game_drawn'.tr(),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCardElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Stack(
        children: [
          // Glow
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _outcomeColor.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon box
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _outcomeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _outcomeColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Icon(_outcomeIcon, size: 26, color: _outcomeColor),
                ),
              ),

              const SizedBox(height: 14),

              // Outcome title
              Text(
                _outcomeLabel,
                style: GoogleFonts.fraunces(
                  fontSize: 38,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: _outcomeColor,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                reason,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _kInkDim,
                ),
              ),

              const SizedBox(height: 16),

              // Rating delta pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'rating'.tr().toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            color: _kInkDim,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          _fmt(currentRating),
                          style: GoogleFonts.fraunces(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _kInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ratingDelta >= 0
                            ? _kWin.withValues(alpha: 0.15)
                            : _kLossSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ratingDelta >= 0
                            ? '+$ratingDelta'
                            : '$ratingDelta',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              ratingDelta >= 0 ? _kWin : _kLoss,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // CTA buttons
              _AmberButton(
                label: 'rematch'.tr(),
                onTap: onRematch ?? () {},
              ),
              const SizedBox(height: 8),
              _OutlineButton(
                label: 'new_opponent'.tr(),
                onTap: onNewOpponent ?? () {},
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'back_to_home'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kInkDim,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      return '${(n ~/ 1000)},${(n % 1000).toString().padLeft(3, '0')}';
    }
    return n.toString();
  }
}

class _AmberButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AmberButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: _kAmber,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _kAmber.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1205),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kInk,
          ),
        ),
      ),
    );
  }
}

/// Show game result as a bottom sheet.
Future<void> showGameResult(
  BuildContext context, {
  required GameOutcome outcome,
  required String reason,
  required int currentRating,
  required int ratingDelta,
  VoidCallback? onRematch,
  VoidCallback? onNewOpponent,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => GameResultSheet(
      outcome: outcome,
      reason: reason,
      currentRating: currentRating,
      ratingDelta: ratingDelta,
      onRematch: onRematch,
      onNewOpponent: onNewOpponent,
    ),
  );
}

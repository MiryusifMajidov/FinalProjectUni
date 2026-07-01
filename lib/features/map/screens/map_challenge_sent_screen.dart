import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/models/user_model.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg          = Color(0xFF0D1014);
const _kCard        = Color(0xFF1A1A1E);
const _kAmber       = Color(0xFFE8B960);
const _kAmberDeep   = Color(0xFFC49A45);
const _kInk         = Color(0xFFF5F3EF);
const _kInkDim      = Color(0xFFB0A898);
const _kInkMute     = Color(0xFF706860);
const _kBorder      = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);
const _kWin         = Color(0xFF5AB67A);

class MapChallengeSentScreen extends StatefulWidget {
  final UserModel opponent;
  final String timeControl;   // e.g. "10+0"
  final String colorChoice;   // "White" | "Black" | "Random"

  const MapChallengeSentScreen({
    super.key,
    required this.opponent,
    this.timeControl = '10+0',
    this.colorChoice = 'Random',
  });

  @override
  State<MapChallengeSentScreen> createState() =>
      _MapChallengeSentScreenState();
}

class _MapChallengeSentScreenState
    extends State<MapChallengeSentScreen>
    with TickerProviderStateMixin {
  // Countdown: auto-cancel in 2 minutes
  static const _kTotalSeconds = 120;
  int _secondsLeft = _kTotalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        if (mounted) context.pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.opponent.username.isNotEmpty
            ? widget.opponent.username[0].toUpperCase()
            : '?';

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient glow
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _kAmber.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 56),

                        // "CHALLENGE SENT" label
                        Text(
                          'CHALLENGE SENT',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kAmber,
                            letterSpacing: 1.4,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Pulsing rings + avatar
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Ring 1
                              _PulseRing(delay: 0),
                              // Ring 2
                              _PulseRing(delay: 800),
                              // Ring 3
                              _PulseRing(delay: 1600),

                              // Avatar circle (inset 24px)
                              Container(
                                width: 132, // 180 - 2*24
                                height: 132,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: Alignment(-0.4, -0.5),
                                    radius: 1,
                                    colors: [
                                      _kAmber,
                                      _kAmberDeep,
                                      Color(0xFF5C3A14),
                                    ],
                                    stops: [0.0, 0.7, 1.0],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.fraunces(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1205),
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          'Waiting for ${widget.opponent.username}…',
                          style: GoogleFonts.fraunces(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: _kInk,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          width: 280,
                          child: Text(
                            "They'll get a notification. We'll start the game the moment they accept.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _kInkDim,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Detail card
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Time control
                              Icon(
                                PhosphorIcons.tree(
                                    PhosphorIconsStyle.fill),
                                size: 14,
                                color: _kAmber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.timeControl,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kInk,
                                ),
                              ),
                              _divider(),
                              // Color
                              Text(
                                '⚂',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _kAmber,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.colorChoice,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kInk,
                                ),
                              ),
                              _divider(),
                              // Rated
                              Icon(
                                PhosphorIcons.trophy(
                                    PhosphorIconsStyle.regular),
                                size: 12,
                                color: _kWin,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Rated',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kInk,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Countdown
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kInkMute,
                              letterSpacing: 0.4,
                            ),
                            children: [
                              const TextSpan(text: 'Auto-cancels in '),
                              TextSpan(
                                text: _countdown,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kInk,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // Cancel button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: _kBorderStrong, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel challenge',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kInkDim,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: _kBorder,
    );
  }
}

// ── Pulsing ring ──────────────────────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  final int delay;
  const _PulseRing({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kAmber, width: 2),
      ),
    )
        .animate(
          onPlay: (ctrl) => ctrl.repeat(),
        )
        .custom(
          delay: Duration(milliseconds: delay),
          duration: const Duration(milliseconds: 2400),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.5 + value * 0.8,
              child: Opacity(
                opacity: (1 - value).clamp(0, 0.7),
                child: child,
              ),
            );
          },
        );
  }
}

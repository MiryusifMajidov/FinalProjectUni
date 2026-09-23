import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kCard        = Color(0xFF1A1A1E);
const _kCardElevated = Color(0xFF1E1E23);
const _kAmber       = Color(0xFFE8B960);
const _kAmberGlow   = Color(0x24E8B960);
const _kInk         = Color(0xFFF5F3EF);
const _kInkDim      = Color(0xFFB0A898);
const _kBorder      = Color(0xFF2A2520);

/// Animated banner overlay shown when the opponent offers a draw.
///
/// Place this inside a [Stack] positioned near the top of the board area.
class DrawOfferedBanner extends StatefulWidget {
  final String opponentName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const DrawOfferedBanner({
    super.key,
    required this.opponentName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<DrawOfferedBanner> createState() => _DrawOfferedBannerState();
}

class _DrawOfferedBannerState extends State<DrawOfferedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kCardElevated, _kCard],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kAmber),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: _kAmber.withValues(alpha: 0.12),
                blurRadius: 30,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kAmberGlow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kAmber.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Icon(
                    PhosphorIcons.handshake(PhosphorIconsStyle.regular),
                    size: 18,
                    color: _kAmber,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'draw_offered'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'draw_offered_msg'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _kInkDim,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Accept button
              GestureDetector(
                onTap: widget.onAccept,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _kAmber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'accept'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1205),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Decline X
              GestureDetector(
                onTap: widget.onDecline,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(
                    PhosphorIcons.x(PhosphorIconsStyle.regular),
                    size: 14,
                    color: _kInkDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

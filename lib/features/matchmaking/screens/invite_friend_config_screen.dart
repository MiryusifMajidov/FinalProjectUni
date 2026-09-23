import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/models/user_model.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = Color(0xFF0A0A0B);
const _kCard         = Color(0xFF1A1A1E);
const _kAmber        = Color(0xFFE8B960);
const _kAmberGlow    = Color(0x24E8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kBorder       = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);

// ── Time control data ──────────────────────────────────────────────────────────
class _TimeOption {
  final String label;
  const _TimeOption(this.label);
}

class _TimeCategory {
  final String name;
  final Color color;
  final List<_TimeOption> options;

  const _TimeCategory({
    required this.name,
    required this.color,
    required this.options,
  });
}

const _timeCategories = [
  _TimeCategory(
    name: 'Bullet',
    color: Color(0xFFF5A462),
    options: [
      _TimeOption('1 min'), _TimeOption('1+1'), _TimeOption('2+1'),
    ],
  ),
  _TimeCategory(
    name: 'Blitz',
    color: Color(0xFF6FB4E0),
    options: [
      _TimeOption('3 min'), _TimeOption('3+2'),
      _TimeOption('5 min'), _TimeOption('5+3'),
    ],
  ),
  _TimeCategory(
    name: 'Rapid',
    color: Color(0xFF5AB67A),
    options: [
      _TimeOption('10 min'), _TimeOption('15+10'), _TimeOption('30 min'),
    ],
  ),
];

/// Screen shown after selecting a friend to challenge — lets you pick
/// colour preference and time control before sending the invite.
class InviteFriendConfigScreen extends StatefulWidget {
  final UserModel opponent;

  const InviteFriendConfigScreen({super.key, required this.opponent});

  @override
  State<InviteFriendConfigScreen> createState() =>
      _InviteFriendConfigScreenState();
}

class _InviteFriendConfigScreenState
    extends State<InviteFriendConfigScreen> {
  // 0=White, 1=Random, 2=Black
  int _colorChoice = 0;

  // category index → option index
  final Map<int, int> _selectedTime = {1: 2}; // default: Blitz 5 min

  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header ──────────────────────────────────────────────
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
                            PhosphorIcons.caretLeft(
                                PhosphorIconsStyle.regular),
                            color: _kInkDim,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'play_with_friend'.tr(),
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

                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(0, 16, 0, 110),
                    children: [
                      // ── CHALLENGING player card ──────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _amberLabel('Challenging'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _kAmberGlow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _kAmber, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  // Avatar circle
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF8B4A5A),
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.opponent.username
                                                .isNotEmpty
                                            ? widget.opponent
                                                .username[0]
                                                .toUpperCase()
                                            : '?',
                                        style: GoogleFonts.fraunces(
                                          fontSize: 18,
                                          color: _kInk,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.opponent.username,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _kInk,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${widget.opponent.overallRating} rating',
                                          style:
                                              GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            color: _kInkDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: _kAmber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      PhosphorIcons.check(
                                          PhosphorIconsStyle.bold),
                                      size: 13,
                                      color: const Color(0xFF1A1205),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── YOU PLAY AS ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _amberLabel('You play as'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _ColorOption(
                                  label: 'white'.tr(),
                                  piece: '♔',
                                  bgColor: const Color(0xFFF5F3EF),
                                  textColor: const Color(0xFF1A1205),
                                  selected: _colorChoice == 0,
                                  onTap: () =>
                                      setState(() => _colorChoice = 0),
                                ),
                                const SizedBox(width: 8),
                                _ColorOption(
                                  label: 'random_color'.tr(),
                                  piece: '⇋',
                                  bgColor: Colors.transparent,
                                  textColor: _kInkDim,
                                  bordered: true,
                                  selected: _colorChoice == 1,
                                  onTap: () =>
                                      setState(() => _colorChoice = 1),
                                ),
                                const SizedBox(width: 8),
                                _ColorOption(
                                  label: 'black'.tr(),
                                  piece: '♚',
                                  bgColor: const Color(0xFF1A1205),
                                  textColor: _kInk,
                                  selected: _colorChoice == 2,
                                  onTap: () =>
                                      setState(() => _colorChoice = 2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── TIME CONTROL ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        child: _amberLabel('Time control'),
                      ),
                      const SizedBox(height: 10),

                      for (int ci = 0;
                          ci < _timeCategories.length;
                          ci++)
                        _buildTimeCategory(ci),
                    ],
                  ),
                ),
              ],
            ),

            // ── Sticky CTA ───────────────────────────────────────────────
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
                padding:
                    const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _sending ? null : _sendInvite,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 52,
                        decoration: BoxDecoration(
                          color: _sending
                              ? _kAmber.withValues(alpha: 0.5)
                              : _kAmber,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _sending
                              ? []
                              : [
                                  BoxShadow(
                                    color:
                                        _kAmber.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                        ),
                        alignment: Alignment.center,
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1A1205),
                                ),
                              )
                            : Text(
                                'Send Invite',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1205),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "They'll receive a notification",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _kInkMute,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCategory(int ci) {
    final cat = _timeCategories[ci];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ci == 0
                    ? PhosphorIcons.lightning(PhosphorIconsStyle.fill)
                    : ci == 1
                        ? PhosphorIcons.flame(PhosphorIconsStyle.fill)
                        : PhosphorIcons.tree(PhosphorIconsStyle.fill),
                size: 14,
                color: cat.color,
              ),
              const SizedBox(width: 5),
              Text(
                cat.name.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cat.color,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: cat.color.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int oi = 0; oi < cat.options.length; oi++)
                _TimePill(
                  label: cat.options[oi].label,
                  selected: _selectedTime[ci] == oi,
                  onTap: () => setState(() {
                    // deselect all other categories
                    _selectedTime.clear();
                    _selectedTime[ci] = oi;
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amberLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: _kAmber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kAmber,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  void _sendInvite() {
    setState(() => _sending = true);
    // TODO: wire to realtime_game_service invite
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _sending = false);
        context.pop();
      }
    });
  }
}

// ── Color choice card ─────────────────────────────────────────────────────────

class _ColorOption extends StatelessWidget {
  final String label;
  final String piece;
  final Color bgColor;
  final Color textColor;
  final bool bordered;
  final bool selected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.label,
    required this.piece,
    required this.bgColor,
    required this.textColor,
    this.bordered = false,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? _kAmberGlow : _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kAmber : _kBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: bordered
                      ? Border.all(color: _kBorderStrong, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  piece,
                  style: TextStyle(
                    fontSize: 20,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time pill ─────────────────────────────────────────────────────────────────

class _TimePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kAmberGlow : _kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? _kAmber : _kBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _kAmber : _kInkDim,
          ),
        ),
      ),
    );
  }
}

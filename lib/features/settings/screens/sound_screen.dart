import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/sound_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'settings_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = Color(0xFF0A0A0B);
const _kSurface      = Color(0xFF131316);
const _kCard         = Color(0xFF1A1A1E);
const _kCardElevated = Color(0xFF1E1E23);
const _kAmber        = Color(0xFFE8B960);
const _kAmberGlow    = Color(0x24E8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kBorder       = Color(0xFF2A2520);
const _kBorderStrong = Color(0xFF3D3530);

class SoundScreen extends ConsumerStatefulWidget {
  const SoundScreen({super.key});

  @override
  ConsumerState<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends ConsumerState<SoundScreen> {
  // Master — synced with settingsProvider on init
  late bool _masterEnabled;
  double _masterVolume = 0.75;

  @override
  void initState() {
    super.initState();
    _masterEnabled = ref.read(settingsProvider).soundEnabled;
    _masterVolume  = ref.read(soundServiceProvider).volume;
    final c = ref.read(cacheServiceProvider);
    _pieceMoves    = c.soundPieceMoves;
    _captures      = c.soundCaptures;
    _checkMate     = c.soundCheckMate;
    _lowTimeTick   = c.soundLowTimeTick;
    _victoryFanfare = c.soundVictoryFanfare;
    _soundPack     = c.soundPack;
  }

  void _haptic() {
    if (ref.read(cacheServiceProvider).hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  // Effects
  bool _pieceMoves    = true;
  bool _captures      = true;
  bool _checkMate     = true;
  bool _lowTimeTick   = false;
  bool _victoryFanfare = true;

  // Sound pack
  String _soundPack = 'classic';

  static const _packs = [
    (id: 'classic', label: 'Classic', sub: 'Wooden clacks'),
    (id: 'tournament', label: 'Tournament', sub: 'Digital clock ticks'),
    (id: 'minimal', label: 'Minimal', sub: 'Subtle taps'),
  ];

  /// True when sound is actually active — master toggle ON and volume > 0.
  bool get _soundActive => _masterEnabled && _masterVolume > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
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
                    'sound'.tr(),
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
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const SizedBox(height: 16),

                  // ── Master volume card ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kCardElevated, _kCard],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _kAmberGlow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _kAmber.withValues(alpha: 0.3)),
                                ),
                                child: Center(
                                  child: Icon(
                                    _masterEnabled
                                        ? PhosphorIcons.speakerHigh(
                                            PhosphorIconsStyle.fill)
                                        : PhosphorIcons.speakerSlash(
                                            PhosphorIconsStyle.fill),
                                    color: _kAmber,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Master volume',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _kInk,
                                  ),
                                ),
                              ),
                              _DesignToggle(
                                on: _masterEnabled,
                                onToggle: () {
                                  _haptic();
                                  final v = !_masterEnabled;
                                  setState(() => _masterEnabled = v);
                                  ref.read(settingsProvider.notifier).toggleSound();
                                  ref.read(soundServiceProvider).setEnabled(v);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                PhosphorIcons.speakerLow(PhosphorIconsStyle.regular),
                                color: _kInkMute,
                                size: 16,
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: _kAmber,
                                    inactiveTrackColor: _kBorderStrong,
                                    thumbColor: _kAmber,
                                    overlayColor: _kAmber.withValues(alpha: 0.1),
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 7),
                                  ),
                                  child: Slider(
                                    value: _masterVolume,
                                    onChanged: _masterEnabled
                                        ? (v) {
                                            setState(() => _masterVolume = v);
                                            ref.read(soundServiceProvider).setVolume(v);
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                              Icon(
                                PhosphorIcons.speakerHigh(PhosphorIconsStyle.regular),
                                color: _kInkMute,
                                size: 16,
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${(_masterVolume * 100).round()}/100',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: _kInkMute,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── EFFECTS + SOUND PACK — dimmed & blocked when sound inactive ──
                  AnimatedOpacity(
                    opacity: _soundActive ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 250),
                    child: AbsorbPointer(
                      absorbing: !_soundActive,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── EFFECTS group ────────────────────────────────
                          _sectionLabel('EFFECTS'),
                          _SettingsGroup(children: [
                            _SettingsRow(
                              icon: PhosphorIcons.horse(PhosphorIconsStyle.regular),
                              label: 'Piece moves',
                              right: _DesignToggle(
                                on: _pieceMoves,
                                onToggle: () {
                                  _haptic();
                                  final v = !_pieceMoves;
                                  setState(() => _pieceMoves = v);
                                  ref.read(cacheServiceProvider).setSoundPieceMoves(v);
                                  if (v && _masterEnabled) {
                                    ref.read(soundServiceProvider).play(ChessSound.move);
                                  }
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.sword(PhosphorIconsStyle.regular),
                              label: 'Captures',
                              right: _DesignToggle(
                                on: _captures,
                                onToggle: () {
                                  _haptic();
                                  final v = !_captures;
                                  setState(() => _captures = v);
                                  ref.read(cacheServiceProvider).setSoundCaptures(v);
                                  if (v && _masterEnabled) {
                                    ref.read(soundServiceProvider).play(ChessSound.capture);
                                  }
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.crown(PhosphorIconsStyle.regular),
                              label: 'Check / Checkmate',
                              right: _DesignToggle(
                                on: _checkMate,
                                onToggle: () {
                                  _haptic();
                                  final v = !_checkMate;
                                  setState(() => _checkMate = v);
                                  ref.read(cacheServiceProvider).setSoundCheckMate(v);
                                  if (v && _masterEnabled) {
                                    ref.read(soundServiceProvider).play(ChessSound.check);
                                  }
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.clockCountdown(PhosphorIconsStyle.regular),
                              label: 'Low-time tick',
                              right: _DesignToggle(
                                on: _lowTimeTick,
                                onToggle: () {
                                  _haptic();
                                  final v = !_lowTimeTick;
                                  setState(() => _lowTimeTick = v);
                                  ref.read(cacheServiceProvider).setSoundLowTimeTick(v);
                                },
                              ),
                            ),
                            _SettingsRow(
                              icon: PhosphorIcons.confetti(PhosphorIconsStyle.regular),
                              label: 'Victory fanfare',
                              right: _DesignToggle(
                                on: _victoryFanfare,
                                onToggle: () {
                                  _haptic();
                                  final v = !_victoryFanfare;
                                  setState(() => _victoryFanfare = v);
                                  ref.read(cacheServiceProvider).setSoundVictoryFanfare(v);
                                  if (v && _masterEnabled) {
                                    ref.read(soundServiceProvider).play(ChessSound.win);
                                  }
                                },
                              ),
                              isLast: true,
                            ),
                          ]),

                          const SizedBox(height: 24),

                          // ── SOUND PACK group ─────────────────────────────
                          _sectionLabel('SOUND PACK'),
                          _SettingsGroup(
                            children: List.generate(_packs.length, (i) {
                              final pack = _packs[i];
                              final selected = _soundPack == pack.id;
                              return _RadioRow(
                                icon: PhosphorIcons.speakerHigh(PhosphorIconsStyle.regular),
                                label: pack.label,
                                sub: pack.sub,
                                selected: selected,
                                onTap: () {
                                  if (selected) return;
                                  _haptic();
                                  setState(() => _soundPack = pack.id);
                                  ref.read(cacheServiceProvider).setSoundPack(pack.id);
                                  ref.read(soundServiceProvider).setPackId(pack.id);
                                  ref.read(soundServiceProvider).play(ChessSound.move);
                                },
                                isLast: i == _packs.length - 1,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kInkMute,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Radio Row ──────────────────────────────────────────────────────────────────

class _RadioRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;

  const _RadioRow({
    required this.icon,
    required this.label,
    this.sub,
    required this.selected,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Center(
                    child: Icon(icon, color: _kAmber, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kInk,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub!,
                          style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _kAmber : _kBorderStrong,
                      width: selected ? 5 : 1.5,
                    ),
                    color: selected ? _kAmber : Colors.transparent,
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1205),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Container(height: 1, color: _kBorder),
          ),
      ],
    );
  }
}

// ── Shared local widgets ───────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Widget? right;
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
    this.right,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Center(
                    child: Icon(icon, color: _kAmber, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kInk,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub!,
                          style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                        ),
                      ],
                    ],
                  ),
                ),
                right ??
                    Icon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                      color: _kInkMute,
                      size: 16,
                    ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Container(height: 1, color: _kBorder),
          ),
      ],
    );
  }
}

class _DesignToggle extends StatelessWidget {
  final bool on;
  final VoidCallback onToggle;

  const _DesignToggle({required this.on, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: on ? _kAmber : _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? _kAmber : _kBorderStrong),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: on ? const Color(0xFF1A1205) : _kInk,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

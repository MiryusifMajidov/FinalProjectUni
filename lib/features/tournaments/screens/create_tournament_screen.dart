import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/models/game_type.dart';

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late GameType _gameType;
  String _timeControl = '5+0';
  String _checkersVariant = 'standard';
  String _dominoVariant = 'draw';
  int _durationMinutes = 30;
  int _maxPlayers = 16;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gameType = ref.read(activeGameProvider);
  }

  static const _timeControls = [
    '1+0', '2+1', '3+0', '3+2', '5+0', '5+3', '10+0', '10+5',
  ];
  static const _durations = [15, 30, 45, 60];
  static const _maxPlayerOptions = [8, 16, 32];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a tournament name.');
      return;
    }
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (tc, inc) = parseTCLabel(_timeControl);
      // Checkers/domino arenas carry the chosen ruleset instead of a chess
      // clock; the label shown in lists becomes the ruleset name.
      final rulesKey = switch (_gameType) {
        GameType.checkers => _checkersVariant,
        GameType.domino   => _dominoVariant,
        GameType.chess    => null,
      };
      final label = switch (_gameType) {
        GameType.checkers => GameTypeX.checkersVariants
            .firstWhere((v) => v.$1 == _checkersVariant)
            .$2,
        GameType.domino =>
          _dominoVariant == 'block' ? 'Block · 100' : 'Draw · 100',
        GameType.chess => _timeControl,
      };
      final tournament = TournamentModel(
        id: '',
        name: name,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        status: TournamentStatus.waiting,
        creatorUid: me.uid,
        creatorUsername: me.username,
        maxPlayers: _maxPlayers,
        timeControlLabel: label,
        timeSeconds: tc,
        incrementSeconds: inc,
        durationMinutes: _durationMinutes,
        createdAt: DateTime.now(),
        gameType: _gameType.name,
        rulesKey: rulesKey,
      );

      final id =
          await ref.read(tournamentServiceProvider).createTournament(tournament);

      // Auto-join the creator (per-game rating)
      final rating = switch (_gameType) {
        GameType.checkers => me.checkersStats.rating,
        GameType.domino   => me.dominoStats.rating,
        GameType.chess    => me.overallRating,
      };
      await ref.read(tournamentServiceProvider).joinTournament(
            tournamentId: id,
            uid: me.uid,
            username: me.username,
            rating: rating,
          );

      if (mounted) context.replace('/home/tournaments/$id');
    } catch (e) {
      setState(() {
        _error = 'Failed to create tournament. Please try again.';
        _loading = false;
      });
    }
  }

  /// Selectable chips used for time controls / variants / rulesets.
  Widget _choiceChips({
    required List<(String, String)> options,
    required String selected,
    required void Function(String) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSel = opt.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isSel ? _gameType.accent : AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel ? _gameType.accent : AppColors.border,
              ),
            ),
            child: Text(
              opt.$2,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isSel ? const Color(0xFF1A1205) : AppColors.inkDim,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
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
                  const SizedBox(width: 14),
                  Text(
                    'Create Arena',
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Tournament Name field ────────────────────────────
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOURNAMENT NAME',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMute,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameCtrl,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: _gameType == GameType.chess
                                  ? 'e.g. Friday Night Blitz'
                                  : 'e.g. Friday Night Arena',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.inkMute,
                              ),
                              // Kill every themed border variant — the global
                              // input theme would otherwise draw a second
                              // pill outline inside the card.
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Description field ────────────────────────────────
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DESCRIPTION (OPTIONAL)',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMute,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _descCtrl,
                            maxLines: 2,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Brief description…',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.inkMute,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Per-game rules ───────────────────────────────────
                    // Chess arenas pick a clock; checkers/domino arenas pick
                    // their ruleset instead (those games use per-move timers).
                    if (_gameType == GameType.chess) ...[
                      _SectionLabel(label: 'TIME CONTROL'),
                      const SizedBox(height: 10),
                      _choiceChips(
                        options: [for (final tc in _timeControls) (tc, tc)],
                        selected: _timeControl,
                        onSelect: (v) => setState(() => _timeControl = v),
                      ),
                    ] else if (_gameType == GameType.checkers) ...[
                      _SectionLabel(label: 'GAME VARIANT'),
                      const SizedBox(height: 10),
                      _choiceChips(
                        options: GameTypeX.checkersVariants,
                        selected: _checkersVariant,
                        onSelect: (v) => setState(() => _checkersVariant = v),
                      ),
                    ] else ...[
                      _SectionLabel(label: 'RULESET'),
                      const SizedBox(height: 10),
                      _choiceChips(
                        options: GameTypeX.dominoVariants,
                        selected: _dominoVariant,
                        onSelect: (v) => setState(() => _dominoVariant = v),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Tournament Duration ──────────────────────────────
                    _SectionLabel(label: 'TOURNAMENT DURATION'),
                    const SizedBox(height: 10),
                    Row(
                      children: _durations.map((d) {
                        final selected = _durationMinutes == d;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _durationMinutes = d),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _gameType.accent
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? _gameType.accent
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                '${d}m',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? const Color(0xFF1A1205)
                                      : AppColors.inkDim,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Max Players ──────────────────────────────────────
                    _SectionLabel(label: 'MAX PLAYERS'),
                    const SizedBox(height: 10),
                    Row(
                      children: _maxPlayerOptions.map((n) {
                        final selected = _maxPlayers == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _maxPlayers = n),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _gameType.accent
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? _gameType.accent
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? const Color(0xFF1A1205)
                                      : AppColors.inkDim,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // ── Error ────────────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.lossSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.loss.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.warningCircle(
                                  PhosphorIconsStyle.fill),
                              size: 16,
                              color: AppColors.loss,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.loss,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Create button ────────────────────────────────────
                    GestureDetector(
                      onTap: _loading ? null : _create,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _gameType.accent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _gameType.accent.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1A1205),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIcons.trophy(
                                        PhosphorIconsStyle.bold),
                                    size: 18,
                                    color: const Color(0xFF1A1205),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Create Tournament',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1205),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.inkMute,
        letterSpacing: 0.8,
      ),
    );
  }
}

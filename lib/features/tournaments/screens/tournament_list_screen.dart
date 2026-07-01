import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/models/game_type.dart';
import '../../../core/widgets/game_switch.dart';

// Filter tabs
enum _ArenaFilter { all, waiting, live, finished }

final _arenaFilterProvider = StateProvider((_) => _ArenaFilter.all);

class TournamentListScreen extends ConsumerWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_arenaFilterProvider);
    final activeGame = ref.watch(activeGameProvider);
    final hp = context.hPadding;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, 14, hp, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'arena'.tr(),
                        style: GoogleFonts.fraunces(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: AppColors.ink,
                          letterSpacing: -0.8,
                        ),
                      ),
                      StreamBuilder<List<TournamentModel>>(
                        stream: ref.read(tournamentServiceProvider).watchTournaments(),
                        builder: (_, snap) {
                          final all = snap.data
                                  ?.where((t) => t.gameType == activeGame.name)
                                  .toList() ??
                              [];
                          final total = all.length;
                          final live = all
                              .where((t) => t.status == TournamentStatus.active)
                              .length;
                          return Text(
                            '$total tournament${total == 1 ? '' : 's'}'
                            '${live > 0 ? ' · $live live' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.inkMute,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Game-accent + button
                  GestureDetector(
                    onTap: () => context.push('/home/tournaments/create'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: activeGame.accent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: activeGame.accent.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIcons.plus(PhosphorIconsStyle.bold),
                          color: const Color(0xFF0A0A0B),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Game switcher ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, 0, hp, 10),
              child: const GameSwitch(),
            ),

            // ── Filter chips ────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(hp, 0, hp, 12),
              child: Row(
                children: _ArenaFilter.values.map((f) {
                  final selected = filter == f;
                  final label = switch (f) {
                    _ArenaFilter.all      => 'all'.tr(),
                    _ArenaFilter.waiting  => 'waiting'.tr(),
                    _ArenaFilter.live     => 'live_game'.tr(),
                    _ArenaFilter.finished => 'finished'.tr(),
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(_arenaFilterProvider.notifier).state = f,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.cardElevated
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: selected
                                ? AppColors.borderStrong
                                : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.ink
                                : AppColors.inkMute,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<TournamentModel>>(
                stream: ref.read(tournamentServiceProvider).watchTournaments(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child:
                          CircularProgressIndicator(color: activeGame.accent),
                    );
                  }

                  var tournaments = (snap.data ?? [])
                      .where((t) => t.gameType == activeGame.name)
                      .toList();

                  // Apply filter
                  tournaments = switch (filter) {
                    _ArenaFilter.all => tournaments,
                    _ArenaFilter.waiting => tournaments
                        .where(
                            (t) => t.status == TournamentStatus.waiting)
                        .toList(),
                    _ArenaFilter.live => tournaments
                        .where(
                            (t) => t.status == TournamentStatus.active)
                        .toList(),
                    _ArenaFilter.finished => tournaments
                        .where(
                            (t) => t.status == TournamentStatus.finished)
                        .toList(),
                  };

                  if (tournaments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.trophy(PhosphorIconsStyle.regular),
                            size: 48,
                            color: AppColors.inkMute,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'no_arenas_yet'.tr(),
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              color: AppColors.inkDim,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap + to create one',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.inkMute,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final isTablet = context.isTablet;
                  final hp = context.hPadding;
                  if (isTablet) {
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                      ),
                      itemCount: tournaments.length,
                      itemBuilder: (_, i) =>
                          _TournamentCard(tournament: tournaments[i]),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(hp, 0, hp, 24),
                    itemCount: tournaments.length,
                    itemBuilder: (_, i) =>
                        _TournamentCard(tournament: tournaments[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tournament Card ───────────────────────────────────────────────────────────

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  const _TournamentCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusBg) = switch (tournament.status) {
      TournamentStatus.waiting  => (
          'waiting'.tr(),
          AppColors.amber,
          AppColors.amberGlow,
        ),
      TournamentStatus.active   => (
          'live_game'.tr(),
          AppColors.live,
          const Color(0x24FF6B6B),
        ),
      TournamentStatus.finished => (
          'finished'.tr(),
          AppColors.inkMute,
          const Color(0x24706B62),
        ),
    };

    final fillPct = tournament.maxPlayers > 0
        ? tournament.participantCount / tournament.maxPlayers
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/home/tournaments/${tournament.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row + status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: GoogleFonts.fraunces(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tournament.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          tournament.description!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.inkMute,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status badge (top-right)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tournament.status == TournamentStatus.active) ...[
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: AppColors.live,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.live,
                                blurRadius: 6,
                              )
                            ],
                          ),
                        ),
                      ],
                      Text(
                        statusLabel.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Metadata row
            Row(
              children: [
                _MetaChip(
                  icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                  label: tournament.timeControlLabel,
                  iconColor: AppColors.amber,
                ),
                const SizedBox(width: 12),
                _MetaChip(
                  icon: PhosphorIcons.timer(PhosphorIconsStyle.regular),
                  label: '${tournament.durationMinutes}m',
                ),
                const Spacer(),
                Text(
                  '${tournament.participantCount}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '/${tournament.maxPlayers}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: fillPct.clamp(0.0, 1.0),
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    switch (tournament.status) {
                      TournamentStatus.active   => AppColors.live,
                      TournamentStatus.waiting  => AppColors.amber,
                      TournamentStatus.finished => AppColors.inkMute,
                    },
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _MetaChip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: iconColor ?? AppColors.inkDim),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkDim,
          ),
        ),
      ],
    );
  }
}

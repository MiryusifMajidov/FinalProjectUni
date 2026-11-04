import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/models/game_type.dart';
import '../../../core/widgets/game_switch.dart';
import '../../../core/utils/text_case.dart';
import 'arena_lobby_screen.dart' show ArenaStatusBadge;

/// The arena's name in the player's language when the server supplied a
/// translation key (hourly arenas), otherwise the name its creator typed.
String tournamentDisplayName(TournamentModel t) {
  final key = t.nameKey;
  if (key != null && key.isNotEmpty) {
    final translated = key.tr();
    if (translated != key) return translated;
  }
  return t.name;
}

/// mm:ss under an hour, h:mm:ss above.
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

// Filter tabs
enum _ArenaFilter { all, waiting, live, finished }

final _arenaFilterProvider = StateProvider((_) => _ArenaFilter.all);

/// Live first, then upcoming (soonest first), then finished (newest first).
List<TournamentModel> sortArenas(Iterable<TournamentModel> list) {
  int rank(TournamentModel t) => switch (t.effectiveStatus) {
        TournamentStatus.active => 0,
        TournamentStatus.waiting => 1,
        TournamentStatus.finished => 2,
      };
  final sorted = list.toList();
  sorted.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    if (a.effectiveStatus == TournamentStatus.waiting) {
      final sa = a.startsAt ?? a.createdAt;
      final sb = b.startsAt ?? b.createdAt;
      return sa.compareTo(sb);
    }
    // Hourly arenas before player arenas when both are live.
    if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

class TournamentListScreen extends ConsumerWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_arenaFilterProvider);
    final activeGame = ref.watch(activeGameProvider);
    final hp = context.hPadding;
    final async = ref.watch(tournamentsStreamProvider);

    final all = sortArenas(
        (async.valueOrNull ?? const <TournamentModel>[])
            .where((t) => t.gameType == activeGame.name));
    final live = all.where((t) => t.isActive).length;

    final tournaments = switch (filter) {
      _ArenaFilter.all => all,
      _ArenaFilter.waiting =>
        all.where((t) => t.effectiveStatus == TournamentStatus.waiting).toList(),
      _ArenaFilter.live =>
        all.where((t) => t.effectiveStatus == TournamentStatus.active).toList(),
      _ArenaFilter.finished =>
        all.where((t) => t.effectiveStatus == TournamentStatus.finished).toList(),
    };

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
                  Expanded(
                    child: Column(
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
                        Text(
                          live > 0
                              ? 'arena_count_live'.tr(namedArgs: {
                                  'count': '${all.length}',
                                  'live': '$live',
                                })
                              : 'arena_count'.tr(
                                  namedArgs: {'count': '${all.length}'}),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Game-accent + button
                  Semantics(
                    button: true,
                    label: 'create_arena'.tr(),
                    child: GestureDetector(
                      onTap: () => context.push('/home/tournaments/create'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: activeGame.accent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: activeGame.accent.withValues(alpha: 0.35),
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
                    _ArenaFilter.all      => 'filter_all'.tr(),
                    _ArenaFilter.waiting  => 'arena_status_waiting'.tr(),
                    _ArenaFilter.live     => 'arena_status_live'.tr(),
                    _ArenaFilter.finished => 'arena_status_finished'.tr(),
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(_arenaFilterProvider.notifier).state = f,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
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
                            fontSize: 12.5,
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
              child: async.isLoading && !async.hasValue
                  ? Center(
                      child:
                          CircularProgressIndicator(color: activeGame.accent),
                    )
                  : tournaments.isEmpty
                      ? _EmptyState(accent: activeGame.accent)
                      : context.isTablet
                          ? GridView.builder(
                              padding: EdgeInsets.fromLTRB(hp, 0, hp, 24),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.8,
                              ),
                              itemCount: tournaments.length,
                              itemBuilder: (_, i) =>
                                  TournamentCard(tournament: tournaments[i]),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(hp, 0, hp, 24),
                              itemCount: tournaments.length,
                              itemBuilder: (_, i) =>
                                  TournamentCard(tournament: tournaments[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color accent;
  const _EmptyState({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              'arena_empty_hint'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.inkMute,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tournament Card ───────────────────────────────────────────────────────────

class TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  const TournamentCard({super.key, required this.tournament});

  /// "Ends in 12:04" / "Starts in 03:10" / "🏆 winner" — or null.
  static String? timingFor(TournamentModel t) {
    final now = DateTime.now();
    return switch (t.effectiveStatus) {
      TournamentStatus.active when t.endsAt != null => 'arena_ends_in'.tr(
          namedArgs: {'time': formatCountdown(t.endsAt!.difference(now))}),
      TournamentStatus.waiting when t.startsAt != null => 'arena_starts_in_short'
          .tr(namedArgs: {'time': formatCountdown(t.startsAt!.difference(now))}),
      TournamentStatus.finished when (t.winnerUsername ?? '').isNotEmpty =>
        '🏆 ${t.winnerUsername}',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final status = t.effectiveStatus;
    final accent = GameTypeX.fromString(t.gameType).accent;
    final hasTiming = timingFor(t) != null;

    final fillPct =
        t.maxPlayers > 0 ? t.participantCount / t.maxPlayers : 0.0;

    return GestureDetector(
      onTap: () => context.push('/home/tournaments/${t.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: status == TournamentStatus.active
                ? accent.withValues(alpha: 0.35)
                : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (t.isSystem) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'arena_hourly_badge'.tr().toUpperCaseFor(context),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              tournamentDisplayName(t),
                              style: GoogleFonts.fraunces(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if ((t.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          t.description!,
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
                ArenaStatusBadge(status),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _MetaChip(
                  icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                  label: t.timeControlLabel,
                  iconColor: accent,
                ),
                const SizedBox(width: 12),
                _MetaChip(
                  icon: PhosphorIcons.timer(PhosphorIconsStyle.regular),
                  label: 'arena_minutes_short'
                      .tr(namedArgs: {'minutes': '${t.durationMinutes}'}),
                ),
                const Spacer(),
                if (hasTiming)
                  Flexible(
                    child: _EverySecond(
                      builder: (_) => Text(
                        timingFor(t) ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: status == TournamentStatus.finished
                              ? AppColors.inkDim
                              : accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: fillPct.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          status == TournamentStatus.finished
                              ? AppColors.inkMute
                              : accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(PhosphorIcons.users(PhosphorIconsStyle.regular),
                    size: 12, color: AppColors.inkMute),
                const SizedBox(width: 4),
                Text(
                  '${t.participantCount}/${t.maxPlayers}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkDim,
                  ),
                ),
              ],
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

/// Rebuilds its child once a second (for countdowns in otherwise static lists).
class _EverySecond extends StatefulWidget {
  final WidgetBuilder builder;
  const _EverySecond({required this.builder});

  @override
  State<_EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<_EverySecond> {
  late final Timer _timer =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer; // start
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

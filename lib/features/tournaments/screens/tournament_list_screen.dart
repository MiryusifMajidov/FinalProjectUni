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
/// translation key (live arenas), otherwise the name its creator typed.
String tournamentDisplayName(TournamentModel t) {
  final key = t.nameKey;
  if (key != null && key.isNotEmpty) {
    final translated = key.tr();
    if (translated != key) return translated;
  }
  return t.name;
}

/// "Blitz · 3+0" for chess (the speed the way chess.com groups it), the
/// ruleset for checkers and domino.
String arenaClockLabel(TournamentModel t) {
  if (t.gameType != 'chess') return t.timeControlLabel;
  final estimate = t.timeSeconds + 40 * t.incrementSeconds;
  final kind = estimate < 180
      ? 'bullet'
      : estimate < 600
          ? 'blitz'
          : 'rapid';
  return '${kind.tr()} · ${t.timeControlLabel}';
}

/// mm:ss under an hour, h:mm:ss above.
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Live first (the server's arenas before players' ones, then the one that
/// started first), then upcoming (soonest first), then finished (newest).
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
    switch (a.effectiveStatus) {
      case TournamentStatus.waiting:
        return (a.startsAt ?? a.createdAt).compareTo(b.startsAt ?? b.createdAt);
      case TournamentStatus.active:
        if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
        return (a.startsAt ?? a.createdAt).compareTo(b.startsAt ?? b.createdAt);
      case TournamentStatus.finished:
        return (b.finishedAt ?? b.createdAt)
            .compareTo(a.finishedAt ?? a.createdAt);
    }
  });
  return sorted;
}

class TournamentListScreen extends ConsumerWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGame = ref.watch(activeGameProvider);
    final hp = context.hPadding;
    final openAsync = ref.watch(openArenasProvider);
    final finishedAsync = ref.watch(finishedArenasProvider(activeGame.name));

    final open = sortArenas((openAsync.valueOrNull ?? const <TournamentModel>[])
        .where((t) => t.gameType == activeGame.name));
    final live = open.where((t) => t.isActive).toList();
    final upcoming = open.where((t) => t.isWaiting).toList();
    // Arenas past their end that the server has not closed yet (it sweeps
    // once a minute) count as finished already.
    final finished = sortArenas([
      ...open.where((t) => t.isFinished),
      ...(finishedAsync.valueOrNull ?? const <TournamentModel>[])
          .where((t) => !t.cancelled),
    ]).take(10).toList();

    final loading = openAsync.isLoading && !openAsync.hasValue;
    final sections = <(String, List<TournamentModel>)>[
      if (live.isNotEmpty) ('arena_section_live'.tr(), live),
      if (upcoming.isNotEmpty) ('arena_section_upcoming'.tr(), upcoming),
      if (finished.isNotEmpty) ('arena_section_finished'.tr(), finished),
    ];

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
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            letterSpacing: -0.8,
                          ),
                        ),
                        Text(
                          live.isNotEmpty
                              ? 'arena_count_live'.tr(namedArgs: {
                                  'count': '${open.length}',
                                  'live': '${live.length}',
                                })
                              : 'arena_count'
                                  .tr(namedArgs: {'count': '${open.length}'}),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'create_arena'.tr(),
                    excludeSemantics: true,
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
              padding: EdgeInsets.fromLTRB(hp, 0, hp, 6),
              child: const GameSwitch(),
            ),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: loading
                  ? Center(
                      child:
                          CircularProgressIndicator(color: activeGame.accent),
                    )
                  : sections.isEmpty
                      ? _EmptyState(accent: activeGame.accent)
                      : _EverySecond(
                          // One clock for every countdown in the list.
                          builder: (_) => CustomScrollView(
                            slivers: [
                              for (final (title, items) in sections) ...[
                                SliverToBoxAdapter(
                                  child: _SectionTitle(
                                      title: title, padding: hp),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.symmetric(horizontal: hp),
                                  sliver: context.isTablet
                                      ? SliverGrid(
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 12,
                                            mainAxisExtent: 128,
                                          ),
                                          delegate: SliverChildBuilderDelegate(
                                            (_, i) => TournamentCard(
                                                tournament: items[i]),
                                            childCount: items.length,
                                          ),
                                        )
                                      : SliverList(
                                          delegate: SliverChildBuilderDelegate(
                                            (_, i) => TournamentCard(
                                                tournament: items[i]),
                                            childCount: items.length,
                                          ),
                                        ),
                                ),
                              ],
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 24)),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final double padding;
  const _SectionTitle({required this.title, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 14, padding, 8),
      child: Text(
        title.toUpperCaseFor(context),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMute,
          letterSpacing: 1.2,
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
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 18,
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

  /// "Ends in 12:04" / "Starts in 03:10" / the winner's name — or null.
  static String? timingFor(TournamentModel t) {
    final now = DateTime.now();
    return switch (t.effectiveStatus) {
      TournamentStatus.active when t.endsAt != null => 'arena_ends_in'.tr(
          namedArgs: {'time': formatCountdown(t.endsAt!.difference(now))}),
      TournamentStatus.waiting when t.startsAt != null => 'arena_starts_in_short'
          .tr(namedArgs: {'time': formatCountdown(t.startsAt!.difference(now))}),
      TournamentStatus.finished when (t.winnerUsername ?? '').isNotEmpty =>
        t.winnerUsername,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final status = t.effectiveStatus;
    final accent = GameTypeX.fromString(t.gameType).accent;
    final timing = timingFor(t);
    final finished = status == TournamentStatus.finished;
    // Live arenas have no real seat limit (like chess.com): just the count.
    final players = t.isSystem
        ? 'arena_players_n'.tr(namedArgs: {'count': '${t.participantCount}'})
        : '${t.participantCount}/${t.maxPlayers}';
    final subtitle = (t.description ?? '').isNotEmpty
        ? t.description!
        : t.isSystem
            ? null
            : 'arena_by'.tr(namedArgs: {'name': t.creatorUsername});

    return Semantics(
      button: true,
      label: tournamentDisplayName(t),
      child: GestureDetector(
        onTap: () => context.push('/home/tournaments/${t.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: status == TournamentStatus.active
                  ? accent.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournamentDisplayName(t),
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle == null
                              ? arenaClockLabel(t)
                              : '${arenaClockLabel(t)} · $subtitle',
                          style: GoogleFonts.inter(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: finished ? AppColors.inkMute : accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  Icon(PhosphorIcons.users(PhosphorIconsStyle.regular),
                      size: 13, color: AppColors.inkMute),
                  const SizedBox(width: 4),
                  Text(
                    players,
                    style: GoogleFonts.inter(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkDim,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(PhosphorIcons.timer(PhosphorIconsStyle.regular),
                      size: 13, color: AppColors.inkMute),
                  const SizedBox(width: 4),
                  Text(
                    'arena_minutes_short'
                        .tr(namedArgs: {'minutes': '${t.durationMinutes}'}),
                    style: GoogleFonts.inter(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkDim,
                    ),
                  ),
                  const Spacer(),
                  if (timing != null) ...[
                    if (finished) ...[
                      Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                          size: 12, color: AppColors.amber),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        timing,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: finished ? AppColors.inkDim : accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (!t.isSystem && !finished) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: t.maxPlayers > 0
                          ? (t.participantCount / t.maxPlayers).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

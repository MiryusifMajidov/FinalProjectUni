import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_game_service.dart';
import '../../../core/widgets/user_avatar.dart';

/// 2v2 domino table with friends: the host picks up to three friends
/// (partner sits across — seats 0&2 vs 1&3), empty chairs are filled with
/// AI stand-ins, invites go out and everyone meets in the table's waiting
/// room inside the game screen.
class DominoTableSetupScreen extends ConsumerStatefulWidget {
  const DominoTableSetupScreen({super.key});

  @override
  ConsumerState<DominoTableSetupScreen> createState() =>
      _DominoTableSetupScreenState();
}

class _DominoTableSetupScreenState
    extends ConsumerState<DominoTableSetupScreen> {
  static const _accent = Color(0xFF5FD4A3);

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  bool _searching = false;
  bool _creating = false;

  // Seat assignments: seat 2 = partner, seats 1 & 3 = opponents.
  // Null slot → AI stand-in.
  UserModel? _partner;   // seat 2
  UserModel? _opponent1; // seat 1
  UserModel? _opponent2; // seat 3

  String _variant = 'draw';
  int _target = 100;

  List<UserModel> get _selected => [
        if (_partner != null) _partner!,
        if (_opponent1 != null) _opponent1!,
        if (_opponent2 != null) _opponent2!,
      ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final me = ref.read(currentUserProvider).valueOrNull;
      final results = await ref
          .read(firestoreServiceProvider)
          .searchUsers(q, excludeUid: me?.uid);
      if (!mounted) return;
      final pickedUids = _selected.map((u) => u.uid).toSet();
      setState(() {
        _results =
            results.where((u) => !pickedUids.contains(u.uid)).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Adds a friend to the first empty chair (partner first, then opponents).
  void _addFriend(UserModel user) {
    setState(() {
      if (_partner == null) {
        _partner = user;
      } else if (_opponent1 == null) {
        _opponent1 = user;
      } else if (_opponent2 == null) {
        _opponent2 = user;
      }
      _results.removeWhere((u) => u.uid == user.uid);
      if (_selected.length == 3) {
        _searchCtrl.clear();
        _results = [];
      }
    });
  }

  Future<void> _createTable() async {
    if (_creating || _selected.isEmpty) return;
    setState(() => _creating = true);

    try {
      final me = await ref.read(currentUserProvider.future);
      if (me == null) return;

      final rtdb = ref.read(realtimeGameServiceProvider);
      final gameId = const Uuid().v4();

      // Empty chairs get AI stand-ins with believable names.
      final botNames = ([...GameType.domino.fakeBotNames]..shuffle());
      int botIdx = 0;
      Map<String, dynamic> seatFor(UserModel? u) => u != null
          ? {'uid': u.uid, 'name': u.username, 'bot': false}
          : {'uid': null, 'name': botNames[botIdx++], 'bot': true};

      final seats = <String, Map<String, dynamic>>{
        '0': {'uid': me.uid, 'name': me.username, 'bot': false},
        '1': seatFor(_opponent1),
        '2': seatFor(_partner),
        '3': seatFor(_opponent2),
      };

      // Room is created in 'waiting' state — the game screen acts as the
      // waiting room and the host starts the table when everyone is in.
      await rtdb.createGameRoom(gameId, {
        'gameType': 'domino',
        'status': 'waiting',
        'hostUid': me.uid,
        'config': {
          'playerCount': 4,
          'variant': _variant,
          'targetScore': _target,
          'teams': true,
        },
        'seats': seats,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Invite every real friend with their assigned seat.
      final rulesLabel =
          '2v2 Table · ${_variant == 'block' ? 'Block' : 'Draw'} · $_target';
      final invites = <(UserModel, int)>[
        if (_opponent1 != null) (_opponent1!, 1),
        if (_partner != null) (_partner!, 2),
        if (_opponent2 != null) (_opponent2!, 3),
      ];
      for (final (friend, seat) in invites) {
        await rtdb.sendInvite(
          fromUid: me.uid,
          fromUsername: me.username,
          toUid: friend.uid,
          timeControlLabel: rulesLabel,
          isWhite: true,
          gameType: 'domino',
          options: {
            'dominoTableGameId': gameId,
            'seat': seat,
            'dominoPlayerCount': '4-player',
            'dominoVariant': _variant,
            'dominoTarget': _target,
            'dominoTeams': true,
          },
        );
      }

      if (!mounted) return;
      context.pushReplacement('/domino-game/$gameId', extra: {
        'mode': GameMode.online.name,
        'gameType': 'domino',
        'gameId': gameId,
        'seat': 0,
        'playerIsWhite': true,
        'isRated': true,
        'myUsername': me.username,
        'dominoPlayerCount': '4-player',
        'dominoVariant': _variant,
        'dominoTarget': _target,
        'dominoTeams': true,
      });
    } catch (e) {
      debugPrint('[DominoTable] create failed: $e');
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the table')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;

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
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: AppColors.inkDim, size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '2v2 Table',
                    style: GoogleFonts.fraunces(
                      fontSize: 22, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic, color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partners sit across the table — you & your partner '
                      'vs the other two. Empty chairs are filled by AI.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.inkMute),
                    ),
                    const SizedBox(height: 18),

                    // ── Table preview (seats) ──────────────────────────
                    _SeatCard(
                      label: 'YOU · TEAM A',
                      name: me?.username ?? 'You',
                      photoUrl: me?.photoUrl,
                      accent: _accent,
                      isMe: true,
                    ),
                    const SizedBox(height: 8),
                    _SeatCard(
                      label: 'PARTNER · TEAM A',
                      name: _partner?.username,
                      photoUrl: _partner?.photoUrl,
                      accent: _accent,
                      onClear: _partner == null
                          ? null
                          : () => setState(() => _partner = null),
                    ),
                    const SizedBox(height: 8),
                    _SeatCard(
                      label: 'OPPONENT · TEAM B',
                      name: _opponent1?.username,
                      photoUrl: _opponent1?.photoUrl,
                      accent: const Color(0xFFF07079),
                      onClear: _opponent1 == null
                          ? null
                          : () => setState(() => _opponent1 = null),
                    ),
                    const SizedBox(height: 8),
                    _SeatCard(
                      label: 'OPPONENT · TEAM B',
                      name: _opponent2?.username,
                      photoUrl: _opponent2?.photoUrl,
                      accent: const Color(0xFFF07079),
                      onClear: _opponent2 == null
                          ? null
                          : () => setState(() => _opponent2 = null),
                    ),

                    const SizedBox(height: 20),

                    // ── Friend search ───────────────────────────────────
                    if (_selected.length < 3) ...[
                      Text(
                        'INVITE FRIENDS',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.inkMute, letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'Search by username…',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 14, color: AppColors.inkMute),
                            prefixIcon: Icon(
                              PhosphorIcons.magnifyingGlass(
                                  PhosphorIconsStyle.regular),
                              color: AppColors.inkMute, size: 18,
                            ),
                            suffixIcon: _searching
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _accent),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (_results.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              for (final u in _results.take(5))
                                ListTile(
                                  dense: true,
                                  leading: UserAvatar(
                                    username: u.username,
                                    photoUrl: u.photoUrl,
                                    size: 34,
                                  ),
                                  title: Text(
                                    u.username,
                                    style: GoogleFonts.inter(
                                        fontSize: 14, color: AppColors.ink),
                                  ),
                                  trailing: Icon(
                                    PhosphorIcons.plusCircle(
                                        PhosphorIconsStyle.regular),
                                    color: _accent, size: 20,
                                  ),
                                  onTap: () => _addFriend(u),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],

                    // ── Rules ───────────────────────────────────────────
                    Text(
                      'RULESET',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.inkMute, letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final v in GameTypeX.dominoVariants) ...[
                          if (v != GameTypeX.dominoVariants.first)
                            const SizedBox(width: 10),
                          Expanded(
                            child: _Chip(
                              label: v.$2,
                              selected: _variant == v.$1,
                              accent: _accent,
                              onTap: () => setState(() => _variant = v.$1),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MATCH TO',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.inkMute, letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final t in GameTypeX.dominoTargets) ...[
                          if (t != GameTypeX.dominoTargets.first)
                            const SizedBox(width: 10),
                          Expanded(
                            child: _Chip(
                              label: '$t',
                              selected: _target == t,
                              accent: _accent,
                              onTap: () => setState(() => _target = t),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Create button ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.5)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _selected.isEmpty || _creating ? null : _createTable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor:
                        _accent.withValues(alpha: 0.25),
                    foregroundColor: const Color(0xFF0A0A0B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0A0A0B)),
                        )
                      : Text(
                          _selected.isEmpty
                              ? 'Invite at least one friend'
                              : 'Create Table & Send Invites',
                          style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600,
                            color: const Color(0xFF0A0A0B),
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

// ── Seat card ─────────────────────────────────────────────────────────────────

class _SeatCard extends StatelessWidget {
  final String label;
  final String? name; // null → AI stand-in chair
  final String? photoUrl;
  final Color accent;
  final bool isMe;
  final VoidCallback? onClear;

  const _SeatCard({
    required this.label,
    required this.name,
    required this.accent,
    this.photoUrl,
    this.isMe = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final filled = name != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: filled
              ? accent.withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          filled
              ? UserAvatar(username: name!, photoUrl: photoUrl, size: 38)
              : Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    PhosphorIcons.robot(PhosphorIconsStyle.regular),
                    color: AppColors.inkMute, size: 18,
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.9),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name ?? 'AI stand-in',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                    color: filled ? AppColors.ink : AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: Icon(
                PhosphorIcons.xCircle(PhosphorIconsStyle.regular),
                color: AppColors.inkMute, size: 20,
              ),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? accent : AppColors.inkDim,
          ),
        ),
      ),
    );
  }
}

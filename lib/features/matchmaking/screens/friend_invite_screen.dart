import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_game_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = AppColors.background;
const _kCard      = AppColors.card;
const _kCardElev  = AppColors.cardElevated;
const _kAmber     = AppColors.amber;
const _kAmberDeep = AppColors.amberDeep;
const _kAmberGlow = AppColors.amberGlow;
const _kInk       = AppColors.ink;
const _kInkDim    = AppColors.inkDim;
const _kInkMute   = AppColors.inkMute;
const _kBorder    = AppColors.border;

class FriendInviteScreen extends ConsumerStatefulWidget {
  /// When provided (e.g. from a chat screen) the search step is skipped and
  /// the user lands directly on the config state with this opponent selected.
  final UserModel? preselected;

  const FriendInviteScreen({super.key, this.preselected});

  @override
  ConsumerState<FriendInviteScreen> createState() =>
      _FriendInviteScreenState();
}

class _FriendInviteScreenState extends ConsumerState<FriendInviteScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<UserModel> _results = [];
  bool _searching = false;
  bool _showDropdown = false;

  UserModel? _selected;
  String _playerColor = 'white'; // 'white' | 'black' | 'random'
  TimeControl _timeControl = TimeControls.blitz5;
  bool _sending = false;
  late GameType _gameType;

  // Per-game rule options (sent inside the invite so both clients agree)
  String _checkersVariant = 'standard';
  String _dominoVariant = 'draw';
  int _dominoTarget = 100;

  /// Rule options carried in the invite payload + navigation extras.
  Map<String, dynamic> get _gameOptions => switch (_gameType) {
        GameType.checkers => {'checkersVariant': _checkersVariant},
        GameType.domino => {
            'dominoVariant': _dominoVariant,
            'dominoTarget': _dominoTarget,
            'dominoPlayerCount': '2-player',
          },
        GameType.chess => const {},
      };

  /// Human-readable rules label (overlay chip on the recipient's side).
  String get _rulesLabel => switch (_gameType) {
        GameType.chess => _timeControl.label,
        GameType.checkers => GameTypeX.checkersVariants
            .firstWhere((v) => v.$1 == _checkersVariant)
            .$2,
        GameType.domino =>
          '${_dominoVariant == 'block' ? 'Block' : 'Draw'} · $_dominoTarget',
      };

  Timer? _debounce;

  // ── Waiting-for-acceptance state ───────────────────────────────────────────
  bool _waitingForAcceptance = false;
  String? _sentInviteKey;        // RTDB push key of the sent invite
  bool _inviterIsWhite = true;   // colour chosen by the inviter (= current user)
  StreamSubscription<DatabaseEvent>? _inviteStatusSub;
  Timer? _waitTimeout;

  @override
  void initState() {
    super.initState();
    _gameType = ref.read(activeGameProvider);
    _searchCtrl.addListener(_onTextChanged);
    _focusNode.addListener(() => setState(() {}));

    // If an opponent was passed in (e.g. from a chat), pre-select them.
    if (widget.preselected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectUser(widget.preselected!);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inviteStatusSub?.cancel();
    _waitTimeout?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final q = _searchCtrl.text.trim();

    // If user clears the field, reset selection
    if (q.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _results = [];
        _showDropdown = false;
        _selected = null;
      });
      return;
    }

    // Don't re-search if we already selected this user
    if (_selected != null && _searchCtrl.text.trim() == _selected!.username) {
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.length < 2) return;
    setState(() {
      _searching = true;
      _selected = null;
    });

    try {
      final me = ref.read(currentUserProvider).valueOrNull;
      final results = await ref
          .read(firestoreServiceProvider)
          .searchUsers(q, excludeUid: me?.uid);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _showDropdown = results.isNotEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectUser(UserModel user) {
    _focusNode.unfocus();
    _searchCtrl.removeListener(_onTextChanged);   // prevent re-search on setText
    _searchCtrl.text = user.username;
    _searchCtrl.addListener(_onTextChanged);
    setState(() {
      _selected = user;
      _results = [];
      _showDropdown = false;
    });
  }

  Future<void> _sendInvite() async {
    if (_selected == null) return;
    setState(() => _sending = true);

    try {
      final me = await ref.read(currentUserProvider.future);
      if (me == null) return;

      final isWhite = switch (_playerColor) {
        'white' => true,
        'black' => false,
        _ => (DateTime.now().millisecondsSinceEpoch % 2 == 0),
      };

      final toUid = _selected!.uid;

      // 1. Write invite to RTDB — returns the push key so we can watch it.
      //    InviteListener on the recipient's device picks this up for in-app.
      final inviteKey = await ref.read(realtimeGameServiceProvider).sendInvite(
            fromUid: me.uid,
            fromUsername: me.username,
            toUid: toUid,
            timeControlLabel: _rulesLabel,
            isWhite: isWhite,
            gameType: _gameType.name,
            options: _gameOptions,
          );

      // 2. Firestore write — triggers Cloud Function for offline FCM push.
      try {
        await ref.read(firestoreServiceProvider).createGameInviteNotification(
              toUid: toUid,
              fromUid: me.uid,
              fromUsername: me.username,
              timeControlLabel: _rulesLabel,
              isWhite: isWhite,
              gameType: _gameType.name,
            );
      } catch (e) {
        debugPrint('[FriendInvite] CF trigger write failed: $e');
        // Non-fatal — RTDB invite + InviteListener overlay still work.
      }

      if (!mounted) return;

      // 3. Transition to "waiting for acceptance" mode.
      setState(() {
        _sending = false;
        _waitingForAcceptance = true;
        _sentInviteKey = inviteKey;
        _inviterIsWhite = isWhite;
      });

      // 4. Watch the invite for status changes (accepted / declined).
      _startWatchingInvite(
        me: me,
        toUid: toUid,
        inviteKey: inviteKey,
        isWhite: isWhite,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dəvət göndərilmədi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Watch the sent invite for acceptance / decline ─────────────────────────

  void _startWatchingInvite({
    required UserModel me,
    required String toUid,
    required String inviteKey,
    required bool isWhite,
  }) {
    _inviteStatusSub?.cancel();
    _waitTimeout?.cancel();

    final rtdb = ref.read(realtimeGameServiceProvider);

    _inviteStatusSub =
        rtdb.watchInviteStatus(toUid, inviteKey).listen((event) {
      if (!mounted) return;
      final raw = event.snapshot.value;
      if (raw == null) return;

      final data = Map<String, dynamic>.from(raw as Map);
      final status = data['status'] as String? ?? '';

      if (status == 'accepted') {
        final gameId = data['gameId'] as String?;
        if (gameId == null) return; // wait for gameId to appear

        _inviteStatusSub?.cancel();
        _waitTimeout?.cancel();
        if (!mounted) return;

        // Navigate the inviter (User A) into the game
        context.push(_gameType.gameRoute(gameId), extra: {
          'mode': GameMode.online.name,
          'gameType': _gameType.name,
          'timeControl': _timeControl.toMap(),
          'playerIsWhite': isWhite, // inviter keeps their chosen colour
          'isRated': true,
          'gameId': gameId,
          'myUsername': me.username,
          'opponentUsername': _selected!.username,
          'opponentUid': toUid,
          ..._gameOptions,
        });
      } else if (status == 'declined') {
        _inviteStatusSub?.cancel();
        _waitTimeout?.cancel();
        if (!mounted) return;
        setState(() {
          _waitingForAcceptance = false;
          _sentInviteKey = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selected?.username ?? 'Oyuncu'} dəvəti rədd etdi.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    // Auto-cancel after 60 seconds
    _waitTimeout = Timer(const Duration(seconds: 60), () {
      if (mounted) _cancelInvite();
    });
  }

  Future<void> _cancelInvite() async {
    _inviteStatusSub?.cancel();
    _waitTimeout?.cancel();

    final toUid = _selected?.uid;
    final key = _sentInviteKey;

    if (mounted) {
      setState(() {
        _waitingForAcceptance = false;
        _sentInviteKey = null;
      });
    }

    if (toUid != null && key != null) {
      try {
        await ref.read(realtimeGameServiceProvider).deleteInvite(toUid, key);
      } catch (e) {
        debugPrint('[FriendInvite] cancel delete failed: $e');
      }
    }
  }

  // ── Waiting UI ─────────────────────────────────────────────────────────────

  Widget _buildWaitingBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing avatar
            UserAvatar(
              username: _selected!.username,
              photoUrl: _selected!.photoUrl,
              size: 80,
              squircle: true,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.08, duration: 900.ms, curve: Curves.easeInOut),

            const SizedBox(height: 28),

            Text(
              _selected!.username,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'searching_opponent'.tr(),
              style: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Time + colour chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kAmberGlow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kAmber.withOpacity(0.3)),
              ),
              child: Text(
                _gameType == GameType.domino
                    ? _rulesLabel
                    : '$_rulesLabel · You play ${_inviterIsWhite ? (_gameType == GameType.checkers ? 'Light' : 'White') : (_gameType == GameType.checkers ? 'Dark' : 'Black')}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kAmber,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Animated dots
            const _LoadingDots(),

            const SizedBox(height: 40),

            // Cancel button
            GestureDetector(
              onTap: _cancelInvite,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIcons.x(PhosphorIconsStyle.regular),
                      size: 15,
                      color: _kInkDim,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'cancel'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kInkDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent hardware back while waiting; use Cancel button instead
      canPop: !_waitingForAcceptance,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _waitingForAcceptance) {
          _cancelInvite(); // fire-and-forget
        }
      },
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _waitingForAcceptance
                          ? () { _cancelInvite(); }
                          : () => context.pop(),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Icon(
                          _waitingForAcceptance
                              ? PhosphorIcons.x(PhosphorIconsStyle.regular)
                              : PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                          color: _kInkDim, size: 18,
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

              // ── Body ────────────────────────────────────────────────────
              Expanded(
                child: _waitingForAcceptance
                    ? _buildWaitingBody()
                    : _selected == null
                        ? _buildSearchState()
                        : _buildConfigState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── State 1: Search ────────────────────────────────────────────────────────

  Widget _buildSearchState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "FIND PLAYER" section label with amber bar
          _AmberSectionLabel('FIND PLAYER'),
          const SizedBox(height: 12),

          // Search field
          Container(
            decoration: BoxDecoration(
              color: _kCardElev,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? _kAmber.withOpacity(0.7)
                    : _kBorder,
                width: _focusNode.hasFocus ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              style: GoogleFonts.inter(fontSize: 14, color: _kInk),
              decoration: InputDecoration(
                hintText: 'Search by username…',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
                prefixIcon: Icon(
                  PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular),
                  color: _focusNode.hasFocus ? _kAmber : _kInkMute,
                  size: 18,
                ),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kAmber,
                          ),
                        ),
                      )
                    : _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              PhosphorIcons.x(PhosphorIconsStyle.regular),
                              size: 16,
                            ),
                            color: _kInkMute,
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _results = [];
                                _selected = null;
                                _showDropdown = false;
                              });
                            },
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // Results list
          if (_showDropdown && _results.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _results.asMap().entries.map((e) {
                    final i = e.key;
                    final user = e.value;
                    return _SearchResultTile(
                      user: user,
                      isLast: i == _results.length - 1,
                      onTap: () => _selectUser(user),
                    );
                  }).toList(),
                ),
              ),
            ).animate().fadeIn(duration: 150.ms).slideY(begin: -0.04, duration: 180.ms),
          ],
        ],
      ),
    );
  }

  // ── State 2: Config ────────────────────────────────────────────────────────

  Widget _buildConfigState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Challenging ────────────────────────────────────────────────────
          _AmberSectionLabel('CHALLENGING'),
          const SizedBox(height: 12),

          // Selected player card
          _SelectedPlayerCard(
            user: _selected!,
            onClear: () {
              _searchCtrl.clear();
              setState(() => _selected = null);
            },
          ),

          const SizedBox(height: 24),

          // ── You play as ────────────────────────────────────────────────────
          _AmberSectionLabel('YOU PLAY AS'),
          const SizedBox(height: 12),

          if (_gameType != GameType.domino) ...[
            Row(
              children: [
                _ColorCard(
                  value: 'white',
                  label: _gameType == GameType.checkers ? 'Light' : 'White',
                  symbol: _gameType == GameType.checkers ? '⛀' : '♔',
                  selected: _playerColor == 'white',
                  onTap: () => setState(() => _playerColor = 'white'),
                  accent: _gameType.accent,
                ),
                const SizedBox(width: 10),
                _ColorCard(
                  value: 'random',
                  label: 'Random',
                  symbol: '⇄',
                  selected: _playerColor == 'random',
                  onTap: () => setState(() => _playerColor = 'random'),
                  accent: _gameType.accent,
                ),
                const SizedBox(width: 10),
                _ColorCard(
                  value: 'black',
                  label: _gameType == GameType.checkers ? 'Dark' : 'Black',
                  symbol: _gameType == GameType.checkers ? '⛂' : '♚',
                  selected: _playerColor == 'black',
                  onTap: () => setState(() => _playerColor = 'black'),
                  accent: _gameType.accent,
                ),
              ],
            ).animate(delay: 50.ms).fadeIn(),
          ],

          const SizedBox(height: 24),

          // ── Per-game rules ──────────────────────────────────────────────────
          if (_gameType == GameType.chess) ...[
            _AmberSectionLabel('TIME CONTROL'),
            const SizedBox(height: 14),
            _TimeSection(
              icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
              iconColor: const Color(0xFFFF6B6B),
              label: 'bullet'.tr(),
              controls: TimeControls.allBullet,
              selected: _timeControl,
              onSelect: (tc) => setState(() => _timeControl = tc),
            ),
            const SizedBox(height: 14),
            _TimeSection(
              icon: PhosphorIcons.flame(PhosphorIconsStyle.fill),
              iconColor: const Color(0xFFFF9F43),
              label: 'blitz'.tr(),
              controls: TimeControls.allBlitz,
              selected: _timeControl,
              onSelect: (tc) => setState(() => _timeControl = tc),
            ),
            const SizedBox(height: 14),
            _TimeSection(
              icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
              iconColor: const Color(0xFF54A0FF),
              label: 'rapid'.tr(),
              controls: TimeControls.allRapid,
              selected: _timeControl,
              onSelect: (tc) => setState(() => _timeControl = tc),
            ),
          ] else if (_gameType == GameType.checkers) ...[
            _AmberSectionLabel('GAME VARIANT'),
            const SizedBox(height: 14),
            _RuleChips(
              options: GameTypeX.checkersVariants,
              selected: _checkersVariant,
              accent: _gameType.accent,
              onSelect: (v) => setState(() => _checkersVariant = v),
            ),
          ] else if (_gameType == GameType.domino) ...[
            _AmberSectionLabel('RULESET'),
            const SizedBox(height: 14),
            _RuleChips(
              options: GameTypeX.dominoVariants,
              selected: _dominoVariant,
              accent: _gameType.accent,
              onSelect: (v) => setState(() => _dominoVariant = v),
            ),
            const SizedBox(height: 20),
            _AmberSectionLabel('MATCH TO'),
            const SizedBox(height: 14),
            _RuleChips(
              options: [
                for (final t in GameTypeX.dominoTargets) ('$t', '$t points'),
              ],
              selected: '$_dominoTarget',
              accent: _gameType.accent,
              onSelect: (v) =>
                  setState(() => _dominoTarget = int.tryParse(v) ?? 100),
            ),
          ],

          const SizedBox(height: 32),

          // ── Send invite CTA ──────────────────────────────────────────────────
          GestureDetector(
            onTap: _sending ? null : _sendInvite,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _sending
                      ? [_kAmberDeep, _kAmberDeep]
                      : [_kAmber, _kAmberDeep],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _sending
                    ? []
                    : [
                        BoxShadow(
                          color: _kAmber.withOpacity(0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF1A1205),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                            size: 18,
                            color: const Color(0xFF1A1205),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Send Invite',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1205),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.15),

          const SizedBox(height: 8),
          Center(
            child: Text(
              "They'll receive a notification",
              style: GoogleFonts.inter(fontSize: 12, color: _kInkMute),
            ),
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ── Amber section label ───────────────────────────────────────────────────────

class _AmberSectionLabel extends StatelessWidget {
  final String text;
  const _AmberSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kAmber,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Search result tile ────────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final UserModel user;
  final bool isLast;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.user,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flag = UserModel.flagEmoji(user.countryCode);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: _kBorder),
                ),
        ),
        child: Row(
          children: [
            // Avatar
            UserAvatar(
              username: user.username,
              photoUrl: user.photoUrl,
              size: 36,
            ),
            const SizedBox(width: 12),

            // Flag + name
            if (flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                user.username,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kInk,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Rating
            Text(
              '${user.overallRating} rating',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: _kInkMute,
              ),
            ),
            const SizedBox(width: 10),

            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
              size: 14,
              color: _kInkMute,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selected player card ──────────────────────────────────────────────────────

class _SelectedPlayerCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onClear;

  const _SelectedPlayerCard({
    required this.user,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final flag = UserModel.flagEmoji(user.countryCode);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kAmberGlow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          UserAvatar(
            username: user.username,
            photoUrl: user.photoUrl,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (flag.isNotEmpty) ...[
                      Text(flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        user.username,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${user.overallRating} rating',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: _kInkMute,
                  ),
                ),
              ],
            ),
          ),
          // Amber check circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _kAmber.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: _kAmber.withOpacity(0.5)),
            ),
            child: Center(
              child: Icon(
                PhosphorIcons.check(PhosphorIconsStyle.bold),
                size: 14,
                color: _kAmber,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
          begin: const Offset(0.97, 0.97),
          duration: 200.ms,
          curve: Curves.easeOut,
        );
  }
}

// ── Color card (You play as) ──────────────────────────────────────────────────

class _ColorCard extends StatelessWidget {
  final String value;
  final String label;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const _ColorCard({
    required this.value,
    required this.label,
    required this.symbol,
    required this.selected,
    required this.onTap,
    this.accent = _kAmber,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.14) : _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : _kBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(symbol, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? accent : _kInkDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rule chips (checkers variant / domino ruleset & target) ──────────────────

class _RuleChips extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final Color accent;
  final void Function(String) onSelect;

  const _RuleChips({
    required this.options,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSel = opt.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? accent.withValues(alpha: 0.15) : _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? accent : _kBorder,
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt.$2,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                color: isSel ? accent : _kInkDim,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Time section ──────────────────────────────────────────────────────────────

class _TimeSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final List<TimeControl> controls;
  final TimeControl selected;
  final void Function(TimeControl) onSelect;

  const _TimeSection({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.controls,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor.withOpacity(0.35), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controls.map((tc) {
            final isSel = tc == selected;
            return GestureDetector(
              onTap: () => onSelect(tc),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? iconColor.withOpacity(0.15) : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? iconColor : _kBorder,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  tc.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                    color: isSel ? iconColor : _kInkDim,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Loading dots ──────────────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = ((_ctrl.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
            final scale = t < 0.5 ? 1.0 + t : 2.0 - t;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale.clamp(0.5, 1.5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _kAmber.withOpacity(0.4 + 0.6 * (scale - 0.5)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

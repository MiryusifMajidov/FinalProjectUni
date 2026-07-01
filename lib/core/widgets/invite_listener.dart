import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/game_model.dart';
import '../models/game_type.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_game_service.dart';

/// Wraps any widget that should listen for incoming game invites.
/// Place this high in the authenticated widget tree (HomeScreen).
class InviteListener extends ConsumerStatefulWidget {
  final Widget child;
  const InviteListener({super.key, required this.child});

  @override
  ConsumerState<InviteListener> createState() => _InviteListenerState();
}

class _InviteListenerState extends ConsumerState<InviteListener> {
  // ── Game invite (RTDB) ─────────────────────────────────────────────────────
  StreamSubscription<DatabaseEvent>? _sub;
  final _seenKeys = <String>{};
  OverlayEntry? _currentOverlay;
  String? _listeningUid;

  // ── Friend request (Firestore) ─────────────────────────────────────────────
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendReqSub;
  String? _listeningFriendReqUid;
  final _seenFriendReqKeys = <String>{};
  bool _friendReqInitialLoaded = false;

  @override
  void dispose() {
    _sub?.cancel();
    _friendReqSub?.cancel();
    _currentOverlay?.remove();
    super.dispose();
  }

  // ── Called from build() when UID becomes known ─────────────────────────────

  void _ensureListening(String uid) {
    if (_listeningUid == uid) return; // already subscribed
    _listeningUid = uid;
    _sub?.cancel();
    _seenKeys.clear();

    final rtdb = ref.read(realtimeGameServiceProvider);
    _sub = rtdb.watchInvites(uid).listen(_onInviteEvent);
    debugPrint('[InviteListener] subscribed for $uid');

    // Save / refresh FCM token so senders can reach this device when offline
    _saveFcmToken(uid);

    // Register a callback so NotificationService can persist the token
    // immediately whenever FCM rotates it (L-1 fix: was never hooked up before).
    NotificationService().setOnTokenRefreshed((newToken) => _saveFcmTokenValue(uid, newToken));

    // Start foreground friend-request listener
    _ensureFriendRequestListening(uid);
  }

  // ── Friend-request foreground listener ──────────────────────────────────────

  void _ensureFriendRequestListening(String uid) {
    if (_listeningFriendReqUid == uid) return;
    _listeningFriendReqUid = uid;
    _friendReqSub?.cancel();
    _seenFriendReqKeys.clear();
    _friendReqInitialLoaded = false;

    _friendReqSub = FirebaseFirestore.instance
        .collection('friendRequests')
        .doc(uid)
        .collection('received')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (!_friendReqInitialLoaded) {
        // First snapshot — mark all existing docs as seen without notifying.
        // This avoids re-notifying for requests that arrived before this session.
        for (final doc in snap.docs) {
          _seenFriendReqKeys.add(doc.id);
        }
        _friendReqInitialLoaded = true;
        return;
      }

      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final key = change.doc.id;
        if (_seenFriendReqKeys.contains(key)) continue;
        _seenFriendReqKeys.add(key);

        final fromUsername =
            change.doc.data()?['fromUsername'] as String? ?? 'Someone';
        _showFriendRequestNotification(fromUsername, key);
      }
    });
  }

  Future<void> _showFriendRequestNotification(
      String fromUsername, String docId) async {
    final prefs = await SharedPreferences.getInstance();

    // Master toggle
    if (!(prefs.getBool('pref_notifications') ?? true)) return;
    // Per-channel toggle
    if (!(prefs.getBool('pref_notif_friend_requests') ?? true)) return;
    // DND / Quiet Hours
    if (prefs.getBool('pref_notif_dnd') ?? false) {
      final start = prefs.getString('pref_notif_dnd_start') ?? '22:00';
      final end   = prefs.getString('pref_notif_dnd_end')   ?? '08:00';
      if (NotificationService.isDndActive(start, end)) return;
    }

    await NotificationService().showLocal(
      id: docId.hashCode,
      title: 'New Friend Request',
      body: '$fromUsername sent you a friend request',
    );
  }

  Future<void> _saveFcmToken(String uid) async {
    try {
      final token = await NotificationService().getToken();
      if (token != null && token.isNotEmpty) {
        await _saveFcmTokenValue(uid, token);
      }
    } catch (e) {
      debugPrint('[FCM] token save failed: $e');
    }
  }

  Future<void> _saveFcmTokenValue(String uid, String token) async {
    try {
      await ref.read(firestoreServiceProvider).saveFcmToken(uid, token);
      debugPrint('[FCM] token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] token save failed: $e');
    }
  }

  // ── RTDB invite events ─────────────────────────────────────────────────────

  void _onInviteEvent(DatabaseEvent event) {
    final raw = event.snapshot.value;
    if (raw == null) return;

    final invites = Map<String, dynamic>.from(raw as Map);
    for (final entry in invites.entries) {
      final key = entry.key;
      if (_seenKeys.contains(key)) continue;

      final data = Map<String, dynamic>.from(entry.value as Map);
      final status = data['status'] as String? ?? '';
      if (status != 'pending') continue;

      _seenKeys.add(key);
      _handleInvite(key, data);
    }
  }

  void _handleInvite(String inviteKey, Map<String, dynamic> data) {
    final fromUsername = data['fromUsername'] as String? ?? 'Someone';
    final timeLabel = data['timeControlLabel'] as String? ?? '5 min';
    final fromUid = data['fromUid'] as String? ?? '';
    final inviterIsWhite = data['isWhite'] as bool? ?? true;
    final gameType = GameTypeX.fromString(data['gameType'] as String?);
    // Per-game rule options chosen by the inviter (variant / target …).
    final rawOptions = data['options'];
    final options = rawOptions is Map
        ? Map<String, dynamic>.from(rawOptions)
        : const <String, dynamic>{};
    // Recipient plays the OPPOSITE colour from the inviter
    final recipientIsWhite = !inviterIsWhite;

    // ── Block check: silently decline invites from blocked users ──────────
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me != null && me.blockedUsers.contains(fromUid)) {
      ref.read(realtimeGameServiceProvider)
          .deleteInvite(me.uid, inviteKey)
          .catchError((_) {});
      return;
    }

    debugPrint('[InviteListener] got invite from $fromUsername ($timeLabel)');

    // Only show the in-app overlay — no showLocal() here.
    // When the app is open the overlay is sufficient.
    // When the app is in the background the Cloud Function's FCM V1 push
    // is already shown by the OS, so showLocal() would duplicate it.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showInviteOverlay(
            inviteKey: inviteKey,
            fromUid: fromUid,
            fromUsername: fromUsername,
            timeLabel: timeLabel,
            recipientIsWhite: recipientIsWhite,
            inviterIsWhite: inviterIsWhite,
            gameType: gameType,
            options: options,
          );
        }
      });
    }
  }

  void _showInviteOverlay({
    required String inviteKey,
    required String fromUid,
    required String fromUsername,
    required String timeLabel,
    required bool recipientIsWhite,  // shown in the overlay (what YOU will play)
    required bool inviterIsWhite,    // stored value, passed to _acceptInvite
    required GameType gameType,
    required Map<String, dynamic> options,
  }) {
    _currentOverlay?.remove();
    _currentOverlay = null;

    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _InviteOverlay(
        fromUsername: fromUsername,
        timeLabel: timeLabel,
        isWhite: recipientIsWhite,   // show the RECIPIENT's colour
        onAccept: () {
          if (entry.mounted) entry.remove();
          if (_currentOverlay == entry) _currentOverlay = null;
          _acceptInvite(
              inviteKey, fromUid, timeLabel, inviterIsWhite, gameType, options);
        },
        onDecline: () {
          if (entry.mounted) entry.remove();
          if (_currentOverlay == entry) _currentOverlay = null;
          _declineInvite(inviteKey);
        },
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);
  }

  Future<void> _acceptInvite(
    String inviteKey,
    String fromUid,
    String timeLabel,
    bool inviterIsWhite,
    GameType gameType,
    Map<String, dynamic> options,
  ) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;

    final rtdb = ref.read(realtimeGameServiceProvider);

    // ── 2v2 domino table invite ────────────────────────────────────────────
    // The host already created the room (with seats + config) — the invitee
    // just joins their assigned seat; the game screen's waiting room takes
    // over from there. No live-game shell must be created here.
    final tableGameId = options['dominoTableGameId'] as String?;
    if (tableGameId != null) {
      await rtdb.respondToInvite(me.uid, inviteKey, 'accepted');
      if (!mounted) return;
      context.push(gameType.gameRoute(tableGameId), extra: {
        'mode': GameMode.online.name,
        'gameType': gameType.name,
        'gameId': tableGameId,
        'seat': (options['seat'] as num?)?.toInt() ?? 1,
        'playerIsWhite': false,
        'isRated': true,
        'myUsername': me.username,
        'opponentUsername': 'Opponent',
        ...options,
      });
      return;
    }

    final tc = TimeControls.all.firstWhere(
      (t) => t.label == timeLabel,
      orElse: () => TimeControls.blitz5,
    );

    final gameId = const Uuid().v4();
    final iAmWhite = !inviterIsWhite;         // recipient's colour
    final whiteUid = inviterIsWhite ? fromUid : me.uid;
    final blackUid = inviterIsWhite ? me.uid : fromUid;

    // 1. Create the live game shell FIRST.
    // H-8: Only write the gameId into the invite (step 2) after the shell
    // exists. If we wrote the gameId first, the inviter could navigate to a
    // game whose RTDB node didn't exist yet, causing both clients to fail.
    try {
      await rtdb.createLiveGame(
        gameId: gameId,
        whiteUid: whiteUid,
        blackUid: blackUid,
        timeControlLabel: tc.label,
      );
    } catch (e) {
      debugPrint('[InviteListener] failed to create live game: $e');
      _declineInvite(inviteKey);
      return;
    }

    // 2. Write the gameId back into the invite so the *inviter* (User A) can
    //    read it from their watchInviteStatus() stream and navigate.
    await rtdb.acceptInviteWithGame(me.uid, inviteKey, gameId);

    if (!mounted) return;

    // 3. Navigate the recipient (User B) to the correct game screen.
    //    The inviter's rule options ride along so both clients build the
    //    exact same engine configuration.
    context.push(gameType.gameRoute(gameId), extra: {
      'mode': GameMode.online.name,
      'gameType': gameType.name,
      'timeControl': tc.toMap(),
      'playerIsWhite': iAmWhite,
      'isRated': true,
      'gameId': gameId,
      'myUsername': me.username,
      'opponentUsername': 'Opponent',
      'opponentUid': fromUid,
      ...options,
    });
  }

  void _declineInvite(String inviteKey) {
    final myUid = ref.read(currentUserProvider).valueOrNull?.uid;
    if (myUid == null) return;
    ref
        .read(realtimeGameServiceProvider)
        .respondToInvite(myUid, inviteKey, 'declined');
  }

  // ── build: watch UID reactively so we start listening as soon as user loads ─

  @override
  Widget build(BuildContext context) {
    // Watch (not read) so this rebuilds when auth state changes
    final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
    if (uid != null) {
      // Defer to avoid calling setState/subscription changes during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureListening(uid);
      });
    }
    return widget.child;
  }
}

// ── Overlay widget ────────────────────────────────────────────────────────────

class _InviteOverlay extends StatefulWidget {
  final String fromUsername;
  final String timeLabel;
  final bool isWhite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteOverlay({
    required this.fromUsername,
    required this.timeLabel,
    required this.isWhite,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_InviteOverlay> createState() => _InviteOverlayState();
}

class _InviteOverlayState extends State<_InviteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _timer;
  bool _acted = false;
  static const _seconds = 10;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _seconds),
    )..forward();
    _timer = Timer(const Duration(seconds: _seconds), () {
      if (!_acted && mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _accept() {
    if (_acted) return;
    _acted = true;
    _timer?.cancel();
    widget.onAccept();
  }

  void _dismiss() {
    if (_acted) return;
    _acted = true;
    _timer?.cancel();
    widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.fromUsername.isNotEmpty
                              ? widget.fromUsername[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'invite_from'.tr(namedArgs: {'from': widget.fromUsername}),
                            style: AppTextStyles.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.timeLabel,
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: widget.isWhite
                                      ? Colors.white
                                      : Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white30, width: 1),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.isWhite ? 'white'.tr() : 'black'.tr(),
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Buttons
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _accept,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.success.withOpacity(0.4)),
                            ),
                            child: Text(
                              'accept'.tr(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Countdown bar
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: LinearProgressIndicator(
                    value: 1.0 - _ctrl.value,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withOpacity(0.7)),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .slideY(
              begin: -1.6,
              end: 0,
              duration: 380.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 200.ms),
      ),
    );
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'grandmaster_main';
  static const _channelName = 'Grandmaster';

  /// Set by InviteListener to persist a refreshed FCM token to Firestore.
  void Function(String token)? _onTokenRefreshedCallback;

  /// Register a callback that is invoked whenever FCM rotates this device's token.
  void setOnTokenRefreshed(void Function(String token) callback) {
    _onTokenRefreshedCallback = callback;
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // While the app is open, suppress the OS-level FCM notification banner.
    // In-app overlays (InviteListener etc.) handle foreground display instead.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Chess app notifications',
      importance: Importance.high,
    );
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Refresh the token in Firestore whenever FCM issues a new one.
    // Without this, a token rotation (app update, cache clear, etc.) leaves a
    // stale token in Firestore and the device stops receiving push notifications.
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] token refreshed: $newToken');
      // _onTokenRefreshedCallback is set by InviteListener so it can persist
      // the token without NotificationService needing a Firestore reference.
      _onTokenRefreshedCallback?.call(newToken);
    });

    final token = await _messaging.getToken();
    debugPrint('[FCM] token: $token');
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // game_invite notifications are handled by InviteListener's in-app overlay.
    // Showing a local push here would duplicate it — skip entirely.
    if (message.data['type'] == 'game_invite') return;

    // ── Check user preferences before displaying ───────────────────────────
    final prefs = await SharedPreferences.getInstance();

    // 1. Master push toggle.
    final masterEnabled = prefs.getBool('pref_notifications') ?? true;
    if (!masterEnabled) return;

    // 2. Per-channel toggle (messages, friend requests, your-turn, tournaments).
    final type   = message.data['type'] as String?;
    final prefKey = _prefKeyForType(type);
    if (prefKey != null) {
      final channelEnabled = prefs.getBool(prefKey) ?? true;
      if (!channelEnabled) return;
    }

    // 3. DND / Quiet Hours.
    final dndEnabled = prefs.getBool('pref_notif_dnd') ?? false;
    if (dndEnabled) {
      final dndStart = prefs.getString('pref_notif_dnd_start') ?? '22:00';
      final dndEnd   = prefs.getString('pref_notif_dnd_end')   ?? '08:00';
      if (isDndActive(dndStart, dndEnd)) return;
    }

    final n = message.notification;
    if (n == null) return;
    showLocal(id: message.hashCode, title: n.title ?? 'Grandmaster', body: n.body ?? '');
  }

  /// Maps an FCM data `type` value → [SharedPreferences] key for the matching
  /// channel toggle.  Returns null for unknown types (allow through).
  static String? _prefKeyForType(String? type) {
    switch (type) {
      case 'message':
      case 'new_message':
      case 'chat':
        return 'pref_notif_messages';
      case 'friend_request':
      case 'friend_accepted':
        return 'pref_notif_friend_requests';
      case 'your_turn':
      case 'game_move':
        return 'pref_notif_your_turn';
      case 'tournament':
      case 'tournament_start':
      case 'tournament_update':
        return 'pref_notif_tournaments';
      default:
        return null; // unknown type → allow through to avoid silently dropping
    }
  }

  /// Returns true if the current local time falls inside the DND window.
  /// Handles overnight spans (e.g. 22:00 → 08:00 the next day).
  /// Public so other listeners (e.g. InviteListener) can reuse the same logic.
  static bool isDndActive(String start, String end) {
    final now  = DateTime.now();
    final nowM = now.hour * 60 + now.minute;

    int _parseMinutes(String time) {
      try {
        final parts = time.split(':');
        if (parts.length != 2) return 0;
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        if (h < 0 || h > 23 || m < 0 || m > 59) return 0;
        return h * 60 + m;
      } catch (_) {
        return 0;
      }
    }

    final startM = _parseMinutes(start);
    final endM   = _parseMinutes(end);

    if (startM <= endM) {
      // Same-day window (e.g. 09:00–17:00)
      return nowM >= startM && nowM < endM;
    } else {
      // Overnight window (e.g. 22:00–08:00)
      return nowM >= startM || nowM < endM;
    }
  }

  Future<void> showLocal({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Chess app notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _local.show(id, title, body, details, payload: payload);
  }

  /// Returns this device's FCM token (null on web or if unavailable).
  /// The token is saved to Firestore by [InviteListener._saveFcmToken] on
  /// startup so Cloud Functions can reach this device when offline.
  Future<String?> getToken() => _messaging.getToken();
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ties an Android guest account to the phone, so it survives cleared app
/// data.
///
/// A guest starts as a Firebase anonymous account, and an anonymous account
/// lives only in the app's own storage: "Clear storage", a cleaner app or a
/// reinstall wiped it, and the next "Play as guest" made a brand-new account.
/// Players expect a guest to last until they delete the game.
///
/// So on Android the guest also gets an e-mail/password login derived from
/// ANDROID_ID. Android keeps that ID per device and per app signing key: it
/// does not change when app data is cleared or the app is reinstalled, and no
/// other app sees the same value. The derived address is on the project's own
/// Firebase domain, which receives no mail, and the app never sends anything
/// to it. With the ID, the app signs back in to the same account; without it,
/// nobody can.
///
/// iOS needs none of this: Firebase keeps the session in the Keychain, which
/// survives the app's data.
class DeviceGuest {
  DeviceGuest._();

  /// Domain of the derived addresses. Every address on it is a device guest.
  static const domain = 'guest.chess-ac4eb.firebaseapp.com';

  static const _channel = MethodChannel('checkmate/device');

  /// The ID a batch of old Android 2.2 phones reported for every device.
  static const _sharedBrokenId = '9774d56d682e549c';

  static ({String email, String password})? _cached;

  /// This phone's guest login, or null where there is none (iOS, web, or no
  /// usable ANDROID_ID).
  static Future<({String email, String password})?> credentials() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    if (_cached != null) return _cached;
    try {
      final id = await _channel.invokeMethod<String>('androidId');
      if (id == null || id.isEmpty || id == _sharedBrokenId) return null;
      return _cached = derive(id);
    } catch (e) {
      debugPrint('[Guest] no device ID: $e');
      return null;
    }
  }

  /// The login for one ANDROID_ID. Stable: changing it would orphan every
  /// device guest already created.
  @visibleForTesting
  static ({String email, String password}) derive(String androidId) {
    final name = sha256
        .convert(utf8.encode('checkmate-guest-email|$androidId'))
        .toString()
        .substring(0, 40);
    final key = base64Url
        .encode(sha256.convert(utf8.encode('checkmate-guest-key|$androidId')).bytes)
        .replaceAll('=', '');
    // The suffix covers any password policy (upper, lower, digit, symbol).
    return (email: 'g$name@$domain', password: '${key}Aa1!');
  }

  static bool isGuestEmail(String? email) =>
      (email ?? '').toLowerCase().endsWith('@$domain');

  /// True for an account whose only login is a device-guest one.
  static bool isDeviceGuest(User user) =>
      user.providerData.isNotEmpty &&
      user.providerData.every((p) =>
          p.providerId == EmailAuthProvider.PROVIDER_ID &&
          isGuestEmail(p.email ?? user.email));
}

/// True while [user] is a guest: anonymous, or a guest tied to this device.
bool isGuestUser(User? user) =>
    user != null && (user.isAnonymous || DeviceGuest.isDeviceGuest(user));

/// A short trail of what happened to the guest on this phone: steps and
/// result codes only, never a name, an address or a key. Shown in About
/// (long-press the version) so a player can send it to support.
class GuestDiag {
  GuestDiag._();

  static const _key = 'guest_diag';
  static const _max = 30;
  static final List<String> _lines = [];

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _lines
        ..clear()
        ..addAll(p.getStringList(_key) ?? const []);
    } catch (_) {}
  }

  static void add(String step, [String result = 'ok', DateTime? at]) {
    final t = (at ?? DateTime.now()).toUtc().toIso8601String();
    final line = '${t.substring(5, 10)} ${t.substring(11, 19)}Z $step: $result';
    _lines.add(line);
    while (_lines.length > _max) {
      _lines.removeAt(0);
    }
    debugPrint('[Guest] $line');
    SharedPreferences.getInstance()
        .then((p) => p.setStringList(_key, List.of(_lines)))
        .catchError((_) => false);
  }

  /// A short code for an error: Firebase's own code when it has one.
  static String code(Object e) =>
      e is FirebaseException ? e.code : e.runtimeType.toString();

  static String get text => _lines.join('\n');

  @visibleForTesting
  static void reset() => _lines.clear();
}

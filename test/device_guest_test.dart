import 'package:chess_app/core/services/device_guest.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guest log', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GuestDiag.reset();
    });

    test('a line is a UTC time, the step and its result', () {
      GuestDiag.add('bind', 'ok', DateTime.utc(2026, 11, 14, 9, 5, 7));
      expect(GuestDiag.text, '11-14 09:05:07Z bind: ok');
    });

    test('keeps only the latest thirty lines', () {
      for (var i = 0; i < 40; i++) {
        GuestDiag.add('step', '$i');
      }
      final lines = GuestDiag.text.split('\n');
      expect(lines.length, 30);
      expect(lines.first, endsWith('step: 10'));
      expect(lines.last, endsWith('step: 39'));
    });

    test('survives a restart', () async {
      GuestDiag.add('restore(start)', 'no-such-guest');
      await Future<void>.delayed(Duration.zero);
      GuestDiag.reset();
      await GuestDiag.load();
      expect(GuestDiag.text, contains('restore(start): no-such-guest'));
    });

    test('names an error by its Firebase code, else by its type', () {
      expect(
          GuestDiag.code(FirebaseAuthException(code: 'email-already-in-use')),
          'email-already-in-use');
      expect(GuestDiag.code(StateError('x')), 'StateError');
    });
  });

  group('device guest login', () {
    test('is the same every time for one device', () {
      final a = DeviceGuest.derive('3f2a9c01b7d4e655');
      final b = DeviceGuest.derive('3f2a9c01b7d4e655');
      expect(a.email, b.email);
      expect(a.password, b.password);
    });

    test('differs between devices', () {
      final a = DeviceGuest.derive('3f2a9c01b7d4e655');
      final b = DeviceGuest.derive('3f2a9c01b7d4e656');
      expect(a.email, isNot(b.email));
      expect(a.password, isNot(b.password));
    });

    test('uses the guest domain and hides the device ID', () {
      const id = '3f2a9c01b7d4e655';
      final login = DeviceGuest.derive(id);
      expect(login.email, endsWith('@${DeviceGuest.domain}'));
      expect(DeviceGuest.isGuestEmail(login.email), isTrue);
      expect(login.email, isNot(contains(id)));
      expect(login.password, isNot(contains(id)));
    });

    test('password passes a strict password policy', () {
      final p = DeviceGuest.derive('a1b2c3d4e5f60718').password;
      expect(p.length, greaterThanOrEqualTo(12));
      expect(p, matches(RegExp(r'[A-Z]')));
      expect(p, matches(RegExp(r'[a-z]')));
      expect(p, matches(RegExp(r'[0-9]')));
      expect(p, matches(RegExp(r'[^A-Za-z0-9]')));
      expect(p, isNot(contains('=')));
    });

    test('only addresses on the guest domain count as guests', () {
      expect(DeviceGuest.isGuestEmail('player@gmail.com'), isFalse);
      expect(DeviceGuest.isGuestEmail(null), isFalse);
      expect(
          DeviceGuest.isGuestEmail('G123@${DeviceGuest.domain.toUpperCase()}'),
          isTrue);
    });
  });
}

import 'package:chess_app/core/services/device_guest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

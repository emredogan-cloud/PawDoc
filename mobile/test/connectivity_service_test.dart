/// Tests for the connectivity service surface.
///
/// We don't drive the real plugin in unit tests — it depends on the
/// platform channels — so we exercise `AlwaysOnlineConnectivityService`
/// and `RecordingConnectivityService` directly. The
/// `ConnectivityServiceImpl` integration is verified manually (see
/// Sprint B1 §5 validation checklist).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/services/connectivity_service.dart';

void main() {
  group('AlwaysOnlineConnectivityService', () {
    test('isOnline returns true', () async {
      const svc = AlwaysOnlineConnectivityService();
      expect(await svc.isOnline(), isTrue);
    });

    test('onlineChanges emits a single true value', () async {
      const svc = AlwaysOnlineConnectivityService();
      expect(await svc.onlineChanges.first, isTrue);
    });
  });

  group('RecordingConnectivityService', () {
    test('initially online by default', () async {
      final svc = RecordingConnectivityService();
      expect(await svc.isOnline(), isTrue);
      addTearDown(svc.dispose);
    });

    test('reflects setOnline toggles', () async {
      final svc = RecordingConnectivityService();
      addTearDown(svc.dispose);
      expect(await svc.isOnline(), isTrue);
      svc.setOnline(false);
      expect(await svc.isOnline(), isFalse);
      svc.setOnline(true);
      expect(await svc.isOnline(), isTrue);
    });

    test('onlineChanges replays current state to new subscribers', () async {
      final svc = RecordingConnectivityService(initiallyOnline: false);
      addTearDown(svc.dispose);
      final first = await svc.onlineChanges.first;
      expect(first, isFalse);
    });

    test('onlineChanges forwards subsequent transitions', () async {
      final svc = RecordingConnectivityService();
      addTearDown(svc.dispose);
      final emitted = <bool>[];
      final sub = svc.onlineChanges.listen(emitted.add);
      // Let the replay yield first.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      svc.setOnline(false);
      svc.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(emitted, [true, false, true]);
    });
  });
}

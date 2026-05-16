/// Tests for the OneSignal service — verify the noop variant.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/services/onesignal_service.dart';

void main() {
  group('NoopOneSignalService', () {
    const noop = NoopOneSignalService();

    test('reports not enabled', () {
      expect(noop.isEnabled, isFalse);
    });

    test('all methods are no-ops', () async {
      await noop.initialize();
      await noop.linkUser('user-1');
      await noop.logout();
      expect(await noop.requestPermission(), isFalse);
    });
  });
}

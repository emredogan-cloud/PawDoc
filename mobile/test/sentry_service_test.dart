/// Tests for the mobile Sentry service.
///
/// We don't run the full SentryFlutter.init since it requires real DSN
/// + native channels. Instead we drive the boot wrapper and the scrub
/// function — both pure-Dart paths.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/app/config.dart';
import 'package:pawdoc/shared/services/sentry_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

AppConfig _config({String dsn = ''}) => AppConfig(
  env: AppEnv.local,
  supabaseUrl: 'http://127.0.0.1:54321',
  supabaseAnonKey: 'anon',
  aiServiceUrl: 'http://localhost:8080',
  sentryDsn: dsn,
  posthogApiKey: '',
  posthogHost: 'https://eu.posthog.com',
);

void main() {
  test('runWithSentry without DSN runs the app body directly', () async {
    var ran = false;
    await runWithSentry(_config(), () async {
      ran = true;
    });
    expect(ran, isTrue);
  });

  test('scrub strips request body + sensitive headers, keeps allowlist', () {
    final event = SentryEvent(
      request: SentryRequest(
        data: const {'secret_field': 'private'},
        queryString: 'token=abc',
        headers: const {
          'authorization': 'Bearer ey…',
          'user-agent': 'PawDoc/0.1',
          'x-request-id': 'req_test',
          'cookie': 's=...',
        },
      ),
      user: SentryUser(
        id: 'uid-1',
        email: 'private@example.test',
        ipAddress: '1.2.3.4',
      ),
    );
    final scrubbed = scrubForTest(event);
    expect(scrubbed, isNotNull);
    final req = scrubbed!.request!;
    expect(req.data, isNull);
    expect(req.queryString, isNull);
    expect(req.headers.keys, containsAll(['user-agent', 'x-request-id']));
    expect(req.headers.containsKey('authorization'), isFalse);
    expect(req.headers.containsKey('cookie'), isFalse);
    // User keeps id, drops email + IP.
    expect(scrubbed.user!.id, 'uid-1');
    expect(scrubbed.user!.email, isNull);
    expect(scrubbed.user!.ipAddress, isNull);
  });

  test('scrub handles missing request gracefully', () {
    final event = SentryEvent(message: const SentryMessage('boom'));
    expect(scrubForTest(event), isNotNull);
  });
}

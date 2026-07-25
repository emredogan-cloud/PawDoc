// Internal-test hardening: the account's Subscription row is never a dead end.
//
// Device-found (Redmi Note 11R): the build carried no REVENUECAT_PUBLIC_SDK_KEY,
// so main() skipped `Purchases.configure` and the profile provider's
// `getCustomerInfo()` never answered — it hung rather than throwing. The
// provider stayed in `loading` forever, so the tile fell through to an `orElse`
// fallback that had no onTap: a row that looked tappable and did nothing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/account_screen.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:pawdoc/src/monetization/paywall_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _dummyClient() => SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      // No auto-refresh timer — it would leak past widget-test teardown.
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

Widget _host(List<Override> overrides) => ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(_dummyClient()),
        ...overrides,
      ],
      child: const MaterialApp(home: AccountScreen()),
    );

void main() {
  test('the entitlement probe is bounded', () {
    expect(kEntitlementProbeTimeout, lessThanOrEqualTo(const Duration(seconds: 10)));
  });

  testWidgets('a never-resolving profile still leaves a route to the paywall',
      (tester) async {
    await tester.pumpWidget(_host([
      // Exactly the device case: a future that never completes.
      userProfileProvider.overrideWith((ref) => Completer<UserProfile>().future),
    ]));
    await tester.pump();

    final tile = find.byKey(const Key('account_subscription_tile'));
    expect(tile, findsOneWidget, reason: 'the row is present while loading');

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget,
        reason: 'the row goes somewhere instead of doing nothing');
  });
}

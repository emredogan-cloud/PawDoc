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
import 'package:pawdoc/src/account/account_identity.dart';
import 'package:pawdoc/src/account/profile_screen.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:pawdoc/src/monetization/premium_home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _dummyClient() => SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      // No auto-refresh timer — it would leak past widget-test teardown.
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

/// A signed-in identity, so the screen renders its account body.
///
/// Profile shows a signed-out state when there is no session — correct, and
/// what the dummy client alone produces. The invariant this file protects is
/// about the *signed-in* screen, so the identity is supplied and the
/// subscription providers are left to misbehave exactly as they did on device.
const _identity = AccountIdentity(
  userId: 'u1',
  email: 'tester@example.com',
  provider: 'email',
  createdAt: null,
  isAnonymous: false,
);

Widget _host(List<Override> overrides) => ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(_dummyClient()),
        accountIdentityProvider.overrideWithValue(_identity),
        ...overrides,
      ],
      child: const MaterialApp(home: ProfileScreen()),
    );

void main() {
  test('the entitlement probe is bounded', () {
    expect(kEntitlementProbeTimeout, lessThanOrEqualTo(const Duration(seconds: 10)));
  });

  testWidgets('a never-resolving profile still leaves a route to Premium',
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
    // The destination moved from the paywall to the Premium hub when the four
    // monetization mockups landed; the invariant this test exists for — the
    // row is never inert — is unchanged.
    expect(find.byType(PremiumHomeScreen), findsOneWidget,
        reason: 'the row goes somewhere instead of doing nothing');
  });
}

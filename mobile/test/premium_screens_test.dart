// Mockups `premium_home`, `subscription_plans`, `upgrade_benefits`,
// `usage_limits`.
//
// The four monetization plates are the most claim-dense in the reference set,
// and almost every claim is untrue of this product: chat with verified
// veterinarians, tools made by vets, a 7-day money-back guarantee, 4.9/5 from
// 10,000+ reviews, three tiers at three invented prices, 1 GB of free storage,
// advanced analytics, priority support, a 15-pet ceiling.
//
// The `product truth` group scans every string these screens render, on both
// plans, and fails on any of them. It is deliberately a page scan rather than
// a widget assertion: a later batch will move these blocks around, and what
// must not change is that none of those sentences can reach a user.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/monetization/entitlements.dart';
import 'package:pawdoc/src/monetization/paywall_screen.dart';
import 'package:pawdoc/src/monetization/premium_home_screen.dart';
import 'package:pawdoc/src/monetization/premium_sections.dart';
import 'package:pawdoc/src/monetization/subscription_state.dart';
import 'package:pawdoc/src/monetization/upgrade_benefits_screen.dart';
import 'package:pawdoc/src/monetization/usage_limits_screen.dart';
import 'package:pawdoc/src/monetization/usage_state.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';

void _surface(WidgetTester tester, {double height = 4200}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

UserProfile _profile({bool premium = false, int photoUsed = 2}) => UserProfile(
      subscriptionStatus: premium ? 'premium' : 'free',
      photoLogsUsedThisMonth: photoUsed,
      photoLogsResetAt: DateTime(2026, 9, 1),
    );

Widget _app(
  Widget home, {
  bool premium = false,
  int photoUsed = 2,
  int journal = 4,
  int? assistant = 3,
  int pets = 2,
  bool profileHangs = false,
  bool usageFails = false,
}) =>
    ProviderScope(
      overrides: [
        if (profileHangs)
          userProfileProvider
              .overrideWith((ref) => Completer<UserProfile>().future)
        else
          userProfileProvider.overrideWith(
              (ref) async => _profile(premium: premium, photoUsed: photoUsed)),
        if (usageFails)
          // `Future.error`, not `async { throw }`: Riverpod 3 retries a
          // provider that threw, so an async throw bounces straight back to
          // `loading` and the error branch is never rendered. The offline
          // Home test learned this the same way.
          accountUsageProvider.overrideWith(
              (ref) => Future<AccountUsage>.error(Exception('offline')))
        else
          accountUsageProvider.overrideWith((ref) async => AccountUsage(
                journalEntries: journal,
                petCount: pets,
                assistantMessagesToday: assistant,
              )),
        subscriptionSnapshotProvider.overrideWith(
            (ref) async => SubscriptionSnapshot.unreadable),
      ],
      child: MaterialApp(home: home),
    );

/// Every word on screen, so a truth assertion can scan the page rather than
/// guess which widget holds the offending sentence.
String _pageText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .toLowerCase();

/// The same scan, minus the two surfaces whose whole job is to *deny* the
/// claims below.
///
/// `PremiumHonestyNote` says "there is no money-back guarantee of PawDoc's
/// own"; the FAQ answers "does PawDoc offer refunds?". Scanning those for the
/// words they exist to disclaim would forbid the disclaimer. What must not
/// appear is the affirmative sales copy, so the scan targets that — and the
/// denials get their own assertions.
String _salesText(WidgetTester tester) {
  final excluded = <Element>{};
  void mark(Element e) {
    excluded.add(e);
    e.visitChildren(mark);
  }

  for (final type in [PremiumHonestyNote, PremiumFaq]) {
    find.byType(type).evaluate().forEach(mark);
  }
  return find
      .byType(Text)
      .evaluate()
      .where((e) => !excluded.contains(e))
      .map((e) => e.widget as Text)
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' ')
      .toLowerCase();
}

/// Every invention the four references sell.
const _bannedPhrases = <String>[
  'verified veterinarian',
  'verified vets',
  'vet chat',
  'made by vets',
  'money-back',
  'money back',
  'full refund',
  'loved by pet parents',
  'thousands of',
  '10,000',
  'reviews',
  'advanced analytics',
  'priority support',
  'dedicated support',
  'early access',
  'multi-user',
  '1 gb',
  'up to 15 pets',
  '100% private',
  'risk-free',
];

void main() {
  group('premium_home', () {
    testWidgets('the reference blocks are present on the free plan',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('PawDoc Premium'), findsOneWidget);
      // Hero, feature strip, plan status, the two feature blocks, the band.
      expect(find.byKey(const Key('premium_hero_cta')), findsOneWidget);
      expect(find.byType(PremiumFeatureStrip), findsOneWidget);
      expect(find.byKey(const Key('premium_status_card')), findsOneWidget);
      expect(find.byKey(const Key('premium_free_for_everyone')), findsOneWidget);
      expect(find.byType(PremiumHonestyNote), findsOneWidget);
      // C-7 / V-24: the reference puts Premium in this slot. It does not move.
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('a paying account is thanked, not sold to', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen(), premium: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('premium_active_hero')), findsOneWidget);
      expect(find.byKey(const Key('premium_hero_cta')), findsNothing);
      expect(find.byKey(const Key('premium_home_band')), findsNothing,
          reason: 'a subscriber is not shown an upgrade band');
      expect(_pageText(tester), contains('active'));
    });

    testWidgets('the plan line admits when the store could not be read',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen(), premium: true));
      await tester.pumpAndSettle();
      // No renewal date is invented when RevenueCat is unreachable.
      expect(_pageText(tester), contains('could not be reached'));
      expect(_pageText(tester), isNot(contains('next billing date')));
    });

    testWidgets('the free plan line quotes the real remaining allowance',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen(), photoUsed: 4));
      await tester.pumpAndSettle();
      expect(_pageText(tester), contains('1 of 5 photo checks left'));
    });

    testWidgets('a feature card opens a sheet that states both plans',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
          of: find.byType(PremiumFeatureGrid),
          matching: find.text('PDF health report')));
      await tester.pumpAndSettle();
      expect(find.text('On the free plan'), findsOneWidget);
      expect(find.text('On Premium'), findsOneWidget);
      expect(find.text('Not included'), findsOneWidget);
    });

    testWidgets('"See plans" reaches the plans screen', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('premium_hero_cta')));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);
    });

    testWidgets('"Compare plans" reaches the benefits screen', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compare plans'));
      await tester.pumpAndSettle();
      expect(find.byType(UpgradeBenefitsScreen), findsOneWidget);
    });

    testWidgets('"Your usage" reaches the usage screen', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PremiumHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('premium_usage')));
      await tester.pumpAndSettle();
      expect(find.byType(UsageLimitsScreen), findsOneWidget);
    });
  });

  group('subscription_plans', () {
    testWidgets('with no store offering it says so, and sells nothing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PaywallScreen()));
      await tester.pumpAndSettle();

      // No RevenueCat plugin in a widget test ⇒ getOfferings throws ⇒ the
      // production-safe state, which is exactly the founder-gated case.
      expect(find.byKey(const Key('paywall_coming_soon')), findsOneWidget);
      expect(find.byKey(const Key('paywall_plan_premium')), findsNothing);
      expect(_pageText(tester), isNot(contains(r'$')),
          reason: 'no price may appear that the store did not return');
    });

    testWidgets('restore and dismiss are always reachable', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PaywallScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paywall_restore')), findsOneWidget);
      expect(find.byKey(const Key('paywall_not_now')), findsOneWidget);
    });

    testWidgets('the assurances never promise a trial or a refund',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('paywall_assurances')), findsOneWidget);
      // The store reported no introductory price, so no trial box exists —
      // and the plan card carries no INTRO OFFER badge either.
      expect(find.text('Intro offer'), findsNothing);
      expect(find.text('INTRO OFFER'), findsNothing);
      expect(_pageText(tester), contains('cancel anytime'));
      // The FAQ still *asks* about a trial; its answer must be the honest one.
      await tester.tap(find.text('Is there a free trial?'));
      await tester.pumpAndSettle();
      expect(_pageText(tester), contains('not on this product today'));
    });

    testWidgets('the FAQ answers refunds and emergencies honestly',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PaywallScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Does PawDoc offer refunds?'));
      await tester.pumpAndSettle();
      expect(_pageText(tester), contains('handled by google play'));
      expect(_pageText(tester),
          contains('does not operate a separate money-back guarantee'));

      await tester.tap(find.text('Do I need Premium in an emergency?'));
      await tester.pumpAndSettle();
      expect(_pageText(tester), contains('never will'));
    });

    testWidgets('the help action reaches the comparison', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PaywallScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('paywall_benefits')));
      await tester.pumpAndSettle();
      expect(find.byType(UpgradeBenefitsScreen), findsOneWidget);
    });
  });

  group('upgrade_benefits', () {
    testWidgets('every catalogue row is in the table', (tester) async {
      _surface(tester, height: 6000);
      await tester.pumpWidget(_app(const UpgradeBenefitsScreen()));
      await tester.pumpAndSettle();

      for (final e in kEntitlements) {
        expect(find.text(e.title), findsWidgets, reason: e.id);
      }
      expect(find.text('See the difference'), findsOneWidget);
    });

    testWidgets('it states what an upgrade does NOT change', (tester) async {
      _surface(tester, height: 6000);
      await tester.pumpWidget(_app(const UpgradeBenefitsScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('benefits_unaffected')), findsOneWidget);
      final text = _pageText(tester);
      expect(text, contains('you are not buying a vet'));
      expect(text, contains('the ai does not change'));
    });

    testWidgets('a subscriber sees no upgrade band', (tester) async {
      _surface(tester, height: 6000);
      await tester.pumpWidget(
          _app(const UpgradeBenefitsScreen(), premium: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('benefits_upgrade_band')), findsNothing);
      expect(
          find.byKey(const Key('benefits_already_premium')), findsOneWidget);
    });
  });

  group('usage_limits', () {
    testWidgets('every meter renders, with the real counts', (tester) async {
      _surface(tester, height: 5000);
      await tester.pumpWidget(_app(const UsageLimitsScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('usage_meters')), findsOneWidget);
      for (final id in [
        'photo_checks',
        'text_checks',
        'assistant',
        'journal',
        'pdf_report',
        'pets',
        'storage',
      ]) {
        expect(find.byKey(Key('usage_meter_$id')), findsOneWidget, reason: id);
      }
      expect(find.text('3 left per month'), findsOneWidget);
      expect(find.text('17 left per day'), findsOneWidget);
    });

    testWidgets('an unmetered row shows a state, never a number',
        (tester) async {
      _surface(tester, height: 5000);
      await tester.pumpWidget(_app(const UsageLimitsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('NOT METERED'), findsNWidgets(2),
          reason: 'text checks and storage both declare they are not counted');
      expect(_pageText(tester), isNot(contains('gb')));
    });

    testWidgets('the PDF row is locked for a free account', (tester) async {
      _surface(tester, height: 5000);
      await tester.pumpWidget(_app(const UsageLimitsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('usage_locked_pdf_report')), findsOneWidget);
    });

    testWidgets('a premium account has no ceilings and no upgrade band',
        (tester) async {
      _surface(tester, height: 5000);
      await tester.pumpWidget(_app(const UsageLimitsScreen(), premium: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('usage_premium_banner')), findsOneWidget);
      expect(find.byKey(const Key('usage_upgrade_band')), findsNothing);
      expect(find.byKey(const Key('usage_locked_pdf_report')), findsNothing);
      expect(find.textContaining('Unlimited per month'), findsWidgets);
    });

    testWidgets('a failed count is admitted, not shown as zero',
        (tester) async {
      _surface(tester, height: 5000);
      await tester.pumpWidget(_app(const UsageLimitsScreen(), usageFails: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('usage_meters')), findsNothing);
      expect(_pageText(tester), contains('could not be read'));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a hanging profile does not render an empty meter set',
        (tester) async {
      _surface(tester, height: 5000);
      await tester.pumpWidget(
          _app(const UsageLimitsScreen(), profileHangs: true));
      await tester.pump();
      expect(find.byKey(const Key('usage_meters')), findsNothing);
      expect(_pageText(tester), contains('reading your plan'));
    });

    testWidgets('the comparison tab swaps in the plan table', (tester) async {
      _surface(tester, height: 6000);
      await tester.pumpWidget(_app(const UsageLimitsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('usage_tab_comparison')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('usage_meters')), findsNothing);
      expect(find.text('Free and Premium'), findsOneWidget);
    });

    testWidgets('the billing strip quotes the server reset, not a guess',
        (tester) async {
      _surface(tester, height: 5000);
      await tester.pumpWidget(_app(const UsageLimitsScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Photo checks reset'), findsOneWidget);
    });
  });

  group('product truth: nothing the references invent may reach a user', () {
    Future<void> scan(WidgetTester tester, Widget screen,
        {required bool premium}) async {
      _surface(tester, height: 6000);
      await tester.pumpWidget(_app(screen, premium: premium));
      await tester.pumpAndSettle();
      final text = _salesText(tester);
      for (final phrase in _bannedPhrases) {
        expect(text.contains(phrase), isFalse,
            reason: '"$phrase" reached ${screen.runtimeType} '
                '(premium=$premium)');
      }
    }

    for (final premium in [false, true]) {
      testWidgets('premium_home (premium=$premium)', (tester) async {
        await scan(tester, const PremiumHomeScreen(), premium: premium);
      });
      testWidgets('subscription_plans (premium=$premium)', (tester) async {
        await scan(tester, const PaywallScreen(), premium: premium);
      });
      testWidgets('upgrade_benefits (premium=$premium)', (tester) async {
        await scan(tester, const UpgradeBenefitsScreen(), premium: premium);
      });
      testWidgets('usage_limits (premium=$premium)', (tester) async {
        await scan(tester, const UsageLimitsScreen(), premium: premium);
      });
    }

    testWidgets('the comparison tab is scanned too', (tester) async {
      _surface(tester, height: 6000);
      await tester.pumpWidget(_app(const UsageLimitsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('usage_tab_comparison')));
      await tester.pumpAndSettle();
      final text = _salesText(tester);
      for (final phrase in _bannedPhrases) {
        expect(text.contains(phrase), isFalse, reason: '"$phrase"');
      }
    });
  });

  group('the usage palette is not the action ladder', () {
    test('no premium tint collides with a safety-locked hue', () {
      // A "1 left" chip in the MONITOR amber, or "none left" in the EMERGENCY
      // red, teaches an owner that running out of photo checks is an urgency
      // signal. Same guard as HealthTone, AssistantTone and WalkBand.
      const ladder = [
        AppColors.emergencyDark,
        AppColors.emergencyLight,
        AppColors.monitorDark,
        AppColors.monitorLight,
        AppColors.actionBookVisit,
        AppColors.actionWatch,
      ];
      for (final tint in PremiumTone.all) {
        expect(ladder.contains(tint), isFalse,
            reason: '$tint is a triage colour');
      }
    });
  });
}

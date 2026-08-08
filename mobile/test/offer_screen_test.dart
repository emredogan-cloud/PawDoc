// The offer surface, rendered.
//
// Two jobs. First, the ordinary one: the screen shows what the store returned,
// on both surfaces, in the presence and absence of a discount.
//
// Second, and the reason most of these assertions exist: a page scan for the
// dark patterns this surface would be the natural home for. Countdowns,
// scarcity, "you were selected", a struck-through original price, a close
// button that is not there. The scan is over every rendered string rather than
// against a specific widget, because a later batch will move these blocks
// around and what must not change is that none of those sentences can reach a
// user.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/monetization/offer_policy.dart';
import 'package:pawdoc/src/monetization/offer_screen.dart';
import 'package:pawdoc/src/monetization/offer_state.dart';
import 'package:pawdoc/src/monetization/store_offer.dart';
import 'package:pawdoc/src/monetization/subscriber_phase.dart';
import 'package:pawdoc/src/monetization/usage_state.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void _surface(WidgetTester tester, {double height = 2600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

PricingPhase _phase({
  required int micros,
  required String formatted,
  PeriodUnit unit = PeriodUnit.month,
  int value = 1,
  String iso = 'P1M',
  RecurrenceMode mode = RecurrenceMode.infiniteRecurring,
  int? cycles,
}) =>
    PricingPhase(
      Period(unit, value, iso),
      mode,
      cycles,
      Price(formatted, micros, 'USD'),
      micros == 0 ? OfferPaymentMode.freeTrial : null,
    );

SubscriptionOption _option(
  String id,
  List<PricingPhase> phases, {
  List<String> tags = const [],
  bool isBasePlan = false,
}) =>
    SubscriptionOption(
      id,
      'pawdoc_premium',
      'pawdoc_premium',
      phases,
      tags,
      isBasePlan,
      phases.last.billingPeriod,
      false,
      phases.lastWhere((p) => p.price.amountMicros > 0,
          orElse: () => phases.last),
      phases.where((p) => p.price.amountMicros == 0).firstOrNull,
      null,
      null,
      null,
    );

final _basePlan = _option(
  'monthly-base',
  [_phase(micros: 16990000, formatted: r'$16.99')],
  isBasePlan: true,
);

final _halfPriceOffer = _option(
  'winback',
  [
    _phase(
        micros: 8495000,
        formatted: r'$8.49',
        mode: RecurrenceMode.finiteRecurring,
        cycles: 3),
    _phase(micros: 16990000, formatted: r'$16.99'),
  ],
  tags: const [kWinBackOfferTag, kIgnoreOfferTag],
);

/// An offer whose phases cannot be stated exactly — the degradation path.
final _opaqueOffer = _option(
  'winback-opaque',
  [
    _phase(
        micros: 8490000,
        formatted: r'$8.49',
        unit: PeriodUnit.unknown,
        iso: '',
        mode: RecurrenceMode.finiteRecurring,
        cycles: 3),
    _phase(micros: 16990000, formatted: r'$16.99'),
  ],
  tags: const [kWinBackOfferTag],
);

Package _package(List<SubscriptionOption> options) => Package(
      r'$rc_monthly',
      PackageType.monthly,
      StoreProduct(
        'pawdoc_premium',
        'PawDoc Premium',
        'PawDoc Premium',
        16.99,
        r'$16.99',
        'USD',
        subscriptionOptions: options,
      ),
      const PresentedOfferingContext('default', null, null),
    );

OfferCandidate _candidate({
  OfferSurface surface = OfferSurface.winBack,
  SubscriptionOption? offer,
  DateTime? endedAt,
}) {
  final option = offer ?? _halfPriceOffer;
  return OfferCandidate(
    surface: surface,
    offer: StoreOffer(option: option, basePlan: _basePlan),
    package: _package([_basePlan, option]),
    snapshot: SubscriberSnapshot(
      phase: surface == OfferSurface.winBack
          ? SubscriberPhase.lapsed
          : SubscriberPhase.trialEnded,
      endedAt: endedAt,
    ),
  );
}

Widget _app(
  OfferCandidate candidate, {
  int photoUsed = 2,
  bool usageHangs = false,
}) =>
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) async => UserProfile(
              subscriptionStatus: 'free',
              photoLogsUsedThisMonth: photoUsed,
            )),
        if (usageHangs)
          accountUsageProvider
              .overrideWith((ref) => Completer<AccountUsage>().future)
        else
          accountUsageProvider.overrideWith((ref) async => const AccountUsage(
                journalEntries: 3,
                petCount: 2,
                assistantMessagesToday: 1,
              )),
      ],
      child: MaterialApp(home: OfferScreen(candidate: candidate)),
    );

/// Every string the screen actually rendered.
List<String> _rendered(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toList();

void main() {
  group('win-back surface', () {
    testWidgets('states what ended, when, and what the offer costs',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate(endedAt: DateTime(2026, 6, 30))));
      await tester.pump();

      expect(find.text('Come back to Premium'), findsOneWidget);
      expect(find.textContaining('Premium ended on 30 June 2026'),
          findsOneWidget);
      expect(find.byKey(const Key('offer_discount')), findsOneWidget);
      expect(find.text('SAVE 50%'), findsOneWidget);
      expect(find.text(r'3 months at $8.49 / month, then $16.99 / month.'),
          findsOneWidget);
      expect(find.textContaining(r'The standard price is $16.99'),
          findsOneWidget);
    });

    testWidgets('with no readable end date it says what ended and stops',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate()));
      await tester.pump();
      expect(find.text('Premium has ended on this account.'), findsOneWidget);
    });

    testWidgets('phases it cannot state exactly defer to the Play sheet',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate(offer: _opaqueOffer)));
      await tester.pump();
      expect(find.byKey(const Key('offer_terms')), findsNothing);
      expect(find.byKey(const Key('offer_terms_deferred')), findsOneWidget);
    });
  });

  group('second-chance surface', () {
    testWidgets('uses trial wording, not subscription wording', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate(
          surface: OfferSurface.secondChance, endedAt: DateTime(2026, 8, 1))));
      await tester.pump();
      expect(find.text('Your trial has ended'), findsOneWidget);
      expect(find.textContaining('Your free trial ended on 1 August 2026'),
          findsOneWidget);
    });
  });

  group('the controls a user needs are always present', () {
    testWidgets('close, restore and not-now, on both surfaces', (tester) async {
      for (final s in [OfferSurface.winBack, OfferSurface.secondChance]) {
        _surface(tester);
        await tester.pumpWidget(_app(_candidate(surface: s)));
        await tester.pump();
        expect(find.byKey(const Key('offer_close')), findsOneWidget,
            reason: '$s has no dismiss control');
        expect(find.byKey(const Key('offer_restore')), findsOneWidget,
            reason: '$s hides Restore purchases');
        expect(find.byKey(const Key('offer_not_now')), findsOneWidget);
      }
    });

    testWidgets('the auto-renew disclosure sits with the purchase CTA',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate()));
      await tester.pump();
      final legal = tester
          .widget<Text>(find.byKey(const Key('offer_renewal_disclosure')))
          .data!;
      expect(legal, contains('renews automatically'));
      expect(legal, contains('cancel'));
      expect(legal, contains('Google'));
      expect(find.text('Subscription Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets('Not now pops without buying anything', (tester) async {
      _surface(tester);
      var popped = false;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async => const UserProfile(
              subscriptionStatus: 'free', photoLogsUsedThisMonth: 0)),
          accountUsageProvider.overrideWith((ref) async => const AccountUsage(
              journalEntries: 0, petCount: 1, assistantMessagesToday: 0)),
        ],
        child: MaterialApp(
          navigatorObservers: [_PopSpy(() => popped = true)],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => OfferScreen(candidate: _candidate())),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offer_not_now')), findsOneWidget);

      await tester.tap(find.byKey(const Key('offer_not_now')));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      // And it went back rather than buying: the offer screen is gone and the
      // caller's screen is on top again.
      expect(find.byType(OfferScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('the recommendation is personal or admits it is not', () {
    testWidgets('real counters produce a real line, with its basis printed',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate(), photoUsed: 5));
      await tester.pump();
      expect(find.text('You used all 5 photo checks this month.'),
          findsOneWidget);
      final basis = tester
          .widget<Text>(find.byKey(const Key('offer_recommendation_basis')))
          .data!;
      expect(basis, contains('this account’s own counts'));
    });

    testWidgets('an unreadable account is never dressed as a personal one',
        (tester) async {
      _surface(tester);
      // Both reads hang: photo count unresolved, usage unresolved. Nothing may
      // be asserted about this person.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileProvider
              .overrideWith((ref) => Completer<UserProfile>().future),
          accountUsageProvider
              .overrideWith((ref) => Completer<AccountUsage>().future),
        ],
        child: MaterialApp(home: OfferScreen(candidate: _candidate())),
      ));
      await tester.pump();
      final basis = tester
          .widget<Text>(find.byKey(const Key('offer_recommendation_basis')))
          .data!;
      expect(basis, contains('could not be read'));
      expect(find.text('What PawDoc can see on this account'), findsNothing);
    });
  });

  group('dark patterns', () {
    // The whole point of the surface. Each phrase is one this screen would be
    // the natural place for, and each is either false of PawDoc or
    // unenforceable — see `offer_policy.dart` on why no countdown exists.
    const banned = <String>[
      'expires in',
      'hurry',
      'act now',
      'only today',
      'last chance',
      'spots left',
      'places left',
      'specially selected',
      'you were chosen',
      'limited time only',
      'one time only',
      'price disappears',
      'never again',
      'risk-free',
      'money-back',
      'money back',
      'full refund',
      'verified vet',
      'vet-approved',
      'made by vets',
      'guaranteed',
      '100% private',
      'thousands of',
      'reviews',
      'rated',
    ];

    testWidgets('none of them reaches either surface', (tester) async {
      for (final s in [OfferSurface.winBack, OfferSurface.secondChance]) {
        _surface(tester);
        await tester
            .pumpWidget(_app(_candidate(surface: s, endedAt: DateTime(2026, 7, 1))));
        await tester.pump();
        final page = _rendered(tester).join(' \n ').toLowerCase();
        for (final phrase in banned) {
          expect(page.contains(phrase), isFalse,
              reason: '"$phrase" rendered on $s');
        }
      }
    });

    testWidgets('no timer, no clock, no ticking anything', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate()));
      await tester.pump();
      final page = _rendered(tester).join(' ').toLowerCase();
      for (final shape in ['00:', 'left to claim', 'ends in', 'counting down']) {
        expect(page.contains(shape), isFalse, reason: '"$shape" is a countdown');
      }
      // And nothing changes if the screen simply sits there.
      final before = _rendered(tester);
      await tester.pump(const Duration(minutes: 5));
      expect(_rendered(tester), before,
          reason: 'the screen mutated over time — that is a countdown');
    });

    testWidgets('a period the store did not name produces no percentage',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate(offer: _opaqueOffer)));
      await tester.pump();
      // The intro phase here is genuinely cheaper — $8.49 against $16.99 — and
      // an eager implementation would print "SAVE 50%". It does not, because
      // the phase's billing period is `unknown` and the base plan's is P1M: a
      // percentage across two periods that may not be the same period is the
      // exact comparison `discountPercent` refuses. Nothing at all is claimed.
      expect(find.byKey(const Key('offer_discount')), findsNothing);
      expect(find.byKey(const Key('offer_free_phase')), findsNothing);
      expect(find.byKey(const Key('offer_terms_deferred')), findsOneWidget);
    });

    testWidgets('a free-trial offer is badged as free, never as a percentage',
        (tester) async {
      _surface(tester);
      final trial = _option(
        'second-chance',
        [
          _phase(
              micros: 0,
              formatted: r'$0.00',
              unit: PeriodUnit.day,
              value: 7,
              iso: 'P7D',
              mode: RecurrenceMode.finiteRecurring,
              cycles: 1),
          _phase(micros: 16990000, formatted: r'$16.99'),
        ],
        tags: const [kSecondChanceOfferTag],
      );
      await tester.pumpWidget(_app(
          _candidate(surface: OfferSurface.secondChance, offer: trial)));
      await tester.pump();
      expect(find.byKey(const Key('offer_discount')), findsNothing);
      expect(find.byKey(const Key('offer_free_phase')), findsOneWidget);
      expect(find.text(r'7 days free, then $16.99 / month.'), findsOneWidget);
    });
  });

  group('what changes on premium', () {
    testWidgets('lists the four metered rows and no invented one',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate()));
      await tester.pump();
      expect(find.byKey(const Key('offer_what_changes')), findsOneWidget);
      expect(find.text('Photo health checks'), findsOneWidget);
      expect(find.text('Assistant messages'), findsOneWidget);
      expect(find.text('Journal entries'), findsOneWidget);
      expect(find.text('PDF health report'), findsOneWidget);
      // Named absences: the reference set's inventions.
      final page = _rendered(tester).join(' ').toLowerCase();
      for (final invented in [
        'vet chat',
        'advanced analytics',
        'priority support',
        'family sharing',
        'unlimited storage',
      ]) {
        expect(page.contains(invented), isFalse, reason: invented);
      }
    });

    testWidgets('emergency is stated as free on the offer screen too',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_candidate()));
      await tester.pump();
      expect(find.textContaining('emergency help'), findsOneWidget);
    });
  });
}

class _PopSpy extends NavigatorObserver {
  _PopSpy(this.onPop);
  final VoidCallback onPop;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onPop();
}

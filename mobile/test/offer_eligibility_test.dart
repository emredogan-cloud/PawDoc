// The offer machinery, tested as pure logic.
//
// Every branch here is a sentence somebody could read on a paywall, and most
// of the wrong answers are consumer-protection problems rather than bugs:
// "your trial ended" to someone who never had one, a win-back discount to
// someone who never left, a percentage computed across two currencies, a
// counter that a user can reset by backing out.
//
// So the shape of this file is deliberate: the SDK's model classes are plain
// data with public constructors, which means the whole decision path — store
// record → phase → eligibility → rendered price — can be exercised without a
// device, a store account, or a network.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/monetization/offer_policy.dart';
import 'package:pawdoc/src/monetization/offer_prefs.dart';
import 'package:pawdoc/src/monetization/offer_recommendation.dart';
import 'package:pawdoc/src/monetization/paywall_pricing.dart';
import 'package:pawdoc/src/monetization/store_offer.dart';
import 'package:pawdoc/src/monetization/subscriber_phase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 8, 8, 12);

EntitlementInfo _ent({
  bool isActive = false,
  bool willRenew = false,
  PeriodType periodType = PeriodType.normal,
  String? expiration,
  String? billingIssue,
  String product = 'pawdoc_premium:annual',
}) =>
    EntitlementInfo(
      'premium',
      isActive,
      willRenew,
      '2026-07-01T00:00:00Z',
      '2026-07-01T00:00:00Z',
      product,
      false,
      periodType: periodType,
      expirationDate: expiration,
      billingIssueDetectedAt: billingIssue,
    );

PricingPhase _phase({
  required int micros,
  required String formatted,
  String currency = 'USD',
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
      Price(formatted, micros, currency),
      micros == 0 ? OfferPaymentMode.freeTrial : null,
    );

SubscriptionOption _option({
  required String id,
  required List<PricingPhase> phases,
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
      // fullPricePhase: the ongoing full-price leg, which is how the Play
      // Billing Library labels it.
      phases.lastWhere((p) => p.price.amountMicros > 0,
          orElse: () => phases.last),
      phases.where((p) => p.price.amountMicros == 0).firstOrNull,
      null,
      null,
      null,
    );

StoreProduct _product(List<SubscriptionOption> options) => StoreProduct(
      'pawdoc_premium',
      'PawDoc Premium',
      'PawDoc Premium',
      49.99,
      r'$49.99',
      'USD',
      subscriptionOptions: options,
    );

void main() {
  // ---------------------------------------------------------------------
  group('subscriber phase', () {
    test('no entitlement record at all is neverSubscribed', () {
      final s = subscriberPhaseFrom({}, now: _now);
      expect(s.phase, SubscriberPhase.neverSubscribed);
      expect(s.mayBeSoldTo, isTrue);
    });

    test('an active trial is inTrial, and nothing may be sold', () {
      final s = subscriberPhaseFrom({
        'premium': _ent(
            isActive: true,
            willRenew: true,
            periodType: PeriodType.trial,
            expiration: '2026-08-15T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.inTrial);
      expect(s.mayBeSoldTo, isFalse);
      expect(s.hasAccess, isTrue);
    });

    test('active and renewing is active', () {
      final s = subscriberPhaseFrom({
        'premium': _ent(
            isActive: true, willRenew: true, expiration: '2027-05-24T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.active);
      expect(s.mayBeSoldTo, isFalse);
    });

    test('cancelled but still inside the paid period is NOT a win-back state',
        () {
      // The entitlement is still owned, so Play will not sell it again. A
      // discounted "come back" offer here is un-purchasable.
      final s = subscriberPhaseFrom({
        'premium': _ent(
            isActive: true,
            willRenew: false,
            expiration: '2026-09-01T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.cancelledStillActive);
      expect(s.mayBeSoldTo, isFalse);
      expect(s.accessEndsAt, DateTime.parse('2026-09-01T00:00:00Z').toLocal());
    });

    test('a billing issue outranks the cancellation flag', () {
      final s = subscriberPhaseFrom({
        'premium': _ent(
            isActive: true,
            willRenew: false,
            billingIssue: '2026-08-05T00:00:00Z',
            expiration: '2026-08-20T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.billingRetry);
      expect(s.mayBeSoldTo, isFalse);
    });

    test('an expired trial is trialEnded and carries the date it ended', () {
      final s = subscriberPhaseFrom({
        'premium': _ent(
            periodType: PeriodType.trial, expiration: '2026-08-01T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.trialEnded);
      expect(s.endedAt, DateTime.parse('2026-08-01T00:00:00Z').toLocal());
      expect(s.mayBeSoldTo, isTrue);
    });

    test('an expired paid subscription is lapsed', () {
      final s = subscriberPhaseFrom({
        'premium': _ent(expiration: '2026-06-30T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.lapsed);
      expect(s.mayBeSoldTo, isTrue);
    });

    test('a trial then a paid subscription reports the most recent one', () {
      final s = subscriberPhaseFrom({
        'trial': _ent(
            periodType: PeriodType.trial, expiration: '2026-05-01T00:00:00Z'),
        'premium': _ent(expiration: '2026-07-15T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.lapsed);
      expect(s.endedAt, DateTime.parse('2026-07-15T00:00:00Z').toLocal());
    });

    test('an expiry in the future on an inactive record is not printed', () {
      // The store says access stopped; a future expiry means the device clock
      // is wrong, and a wrong date on a "your trial ended on…" line is worse
      // than no date.
      final s = subscriberPhaseFrom({
        'premium': _ent(
            periodType: PeriodType.trial, expiration: '2027-01-01T00:00:00Z'),
      }, now: _now);
      expect(s.phase, SubscriberPhase.trialEnded);
      expect(s.endedAt, isNull);
    });

    test('unknown is never sellable', () {
      expect(SubscriberSnapshot.unknown.mayBeSoldTo, isFalse);
      expect(SubscriberSnapshot.unknown.hasAccess, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  group('offer eligibility', () {
    OfferContext ctx({
      SubscriberPhase phase = SubscriberPhase.lapsed,
      bool configured = true,
      bool onboarding = false,
      bool emergency = false,
      DateTime? lastShown,
      int times = 0,
    }) =>
        OfferContext(
          phase: phase,
          offerConfigured: configured,
          inOnboarding: onboarding,
          lastTriageWasEmergency: emergency,
          lastShownAt: lastShown,
          timesShown: times,
        );

    test('lapsed with a configured offer gets the win-back surface', () {
      expect(offerSurfaceFor(ctx(), now: _now), OfferSurface.winBack);
    });

    test('trialEnded gets the second-chance surface', () {
      expect(offerSurfaceFor(ctx(phase: SubscriberPhase.trialEnded), now: _now),
          OfferSurface.secondChance);
    });

    test('no configured Play offer means no surface, in every phase', () {
      for (final p in SubscriberPhase.values) {
        expect(offerSurfaceFor(ctx(phase: p, configured: false), now: _now),
            OfferSurface.none,
            reason: '$p rendered an offer that does not exist in the store');
      }
    });

    test('nothing is ever sold to a paying, trialling or unknown account', () {
      for (final p in [
        SubscriberPhase.unknown,
        SubscriberPhase.neverSubscribed,
        SubscriberPhase.inTrial,
        SubscriberPhase.active,
        SubscriberPhase.cancelledStillActive,
        SubscriberPhase.billingRetry,
      ]) {
        expect(offerSurfaceFor(ctx(phase: p), now: _now), OfferSurface.none,
            reason: '$p must not receive an unprompted offer');
      }
    });

    test('never during onboarding', () {
      expect(offerSurfaceFor(ctx(onboarding: true), now: _now),
          OfferSurface.none);
    });

    test('never after an emergency result', () {
      expect(
          offerSurfaceFor(ctx(emergency: true), now: _now), OfferSurface.none);
    });

    test('the cooldown blocks a second showing inside the window', () {
      final justShown = _now.subtract(kOfferCooldown - const Duration(hours: 1));
      expect(offerSurfaceFor(ctx(lastShown: justShown, times: 1), now: _now),
          OfferSurface.none);
    });

    test('the cooldown clears exactly at the window', () {
      final old = _now.subtract(kOfferCooldown);
      expect(offerSurfaceFor(ctx(lastShown: old, times: 1), now: _now),
          OfferSurface.winBack);
    });

    test('the lifetime cap is final — no cooldown clears it', () {
      final ancient = _now.subtract(const Duration(days: 900));
      expect(
        offerSurfaceFor(
            ctx(lastShown: ancient, times: kOfferMaxPrompts), now: _now),
        OfferSurface.none,
      );
    });

    test('each surface looks for its own Play offer tag', () {
      expect(offerTagFor(OfferSurface.winBack), kWinBackOfferTag);
      expect(offerTagFor(OfferSurface.secondChance), kSecondChanceOfferTag);
      expect(offerTagFor(OfferSurface.none), isEmpty);
    });
  });

  // ---------------------------------------------------------------------
  group('offer prompt memory', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('reopening the surface does not reset the count or the clock',
        () async {
      final first = DateTime(2026, 8, 1);
      await OfferPrefs.markShown(OfferSurface.winBack, first);
      expect(await OfferPrefs.timesShown(OfferSurface.winBack), 1);
      expect(await OfferPrefs.lastShownAt(OfferSurface.winBack), first);

      // Reading it again — which is what a reopened screen does — changes
      // nothing. This is the anti-fake-urgency guarantee.
      expect(await OfferPrefs.timesShown(OfferSurface.winBack), 1);
      expect(await OfferPrefs.lastShownAt(OfferSurface.winBack), first);
    });

    test('the two surfaces keep separate budgets', () async {
      await OfferPrefs.markShown(OfferSurface.winBack, _now);
      await OfferPrefs.markShown(OfferSurface.winBack, _now);
      expect(await OfferPrefs.timesShown(OfferSurface.winBack), 2);
      expect(await OfferPrefs.timesShown(OfferSurface.secondChance), 0);
    });

    test('signing out clears the history for every surface', () async {
      await OfferPrefs.markShown(OfferSurface.winBack, _now);
      await OfferPrefs.markShown(OfferSurface.secondChance, _now);
      await OfferPrefs.clearAll();
      for (final s in OfferSurface.values) {
        expect(await OfferPrefs.timesShown(s), 0);
        expect(await OfferPrefs.lastShownAt(s), isNull);
      }
    });

    test('three showings then the rule refuses, end to end', () async {
      var last = DateTime(2026, 1, 1);
      for (var i = 0; i < kOfferMaxPrompts; i++) {
        final allowed = offerSurfaceFor(
          OfferContext(
            phase: SubscriberPhase.lapsed,
            offerConfigured: true,
            lastShownAt: await OfferPrefs.lastShownAt(OfferSurface.winBack),
            timesShown: await OfferPrefs.timesShown(OfferSurface.winBack),
          ),
          now: last,
        );
        expect(allowed, OfferSurface.winBack, reason: 'showing ${i + 1}');
        await OfferPrefs.markShown(OfferSurface.winBack, last);
        last = last.add(kOfferCooldown * 2);
      }
      final fourth = offerSurfaceFor(
        OfferContext(
          phase: SubscriberPhase.lapsed,
          offerConfigured: true,
          lastShownAt: await OfferPrefs.lastShownAt(OfferSurface.winBack),
          timesShown: await OfferPrefs.timesShown(OfferSurface.winBack),
        ),
        now: last,
      );
      expect(fourth, OfferSurface.none);
    });
  });

  // ---------------------------------------------------------------------
  group('store offer', () {
    final basePlan = _option(
      id: 'monthly-base',
      isBasePlan: true,
      phases: [_phase(micros: 16990000, formatted: r'$16.99')],
    );

    test('an offer is found by its Play tag, paired with the base plan', () {
      final winback = _option(
        id: 'winback',
        tags: const [kWinBackOfferTag, kIgnoreOfferTag],
        phases: [
          _phase(
              micros: 8490000,
              formatted: r'$8.49',
              mode: RecurrenceMode.finiteRecurring,
              cycles: 3),
          _phase(micros: 16990000, formatted: r'$16.99'),
        ],
      );
      final found =
          findTaggedOffer(_product([basePlan, winback]), kWinBackOfferTag);
      expect(found, isNotNull);
      expect(found!.option.id, 'winback');
      expect(found.basePlan.id, 'monthly-base');
      expect(found.standardPriceString, r'$16.99');
    });

    test('an untagged product yields nothing, so nothing renders', () {
      expect(findTaggedOffer(_product([basePlan]), kWinBackOfferTag), isNull);
      expect(findTaggedOffer(null, kWinBackOfferTag), isNull);
    });

    test('a base plan on its own is never returned as an offer', () {
      final tagged = _option(
        id: 'base',
        isBasePlan: true,
        tags: const [kWinBackOfferTag],
        phases: [_phase(micros: 16990000, formatted: r'$16.99')],
      );
      expect(findTaggedOffer(_product([tagged]), kWinBackOfferTag), isNull);
    });

    test('a real 50% offer reports 50%, and states its phases exactly', () {
      final offer = StoreOffer(
        option: _option(
          id: 'winback',
          tags: const [kWinBackOfferTag],
          phases: [
            _phase(
                micros: 8495000,
                formatted: r'$8.49',
                mode: RecurrenceMode.finiteRecurring,
                cycles: 3),
            _phase(micros: 16990000, formatted: r'$16.99'),
          ],
        ),
        basePlan: basePlan,
      );
      expect(offer.discountPercent, 50);
      expect(offer.termsSentence,
          r'3 months at $8.49 / month, then $16.99 / month.');
      expect(offer.startsFree, isFalse);
    });

    test('a cross-currency comparison produces no percentage', () {
      final offer = StoreOffer(
        option: _option(
          id: 'winback',
          phases: [
            _phase(
                micros: 8490000,
                formatted: '€8.49',
                currency: 'EUR',
                mode: RecurrenceMode.finiteRecurring,
                cycles: 3),
            _phase(micros: 16990000, formatted: r'$16.99'),
          ],
        ),
        basePlan: basePlan,
      );
      expect(offer.discountPercent, isNull);
    });

    test('a discounted MONTH against a full YEAR produces no percentage', () {
      // The trick this guard exists to refuse: "$8.49 vs $49.99 — save 83%!"
      final annualBase = _option(
        id: 'annual-base',
        isBasePlan: true,
        phases: [
          _phase(
              micros: 49990000,
              formatted: r'$49.99',
              unit: PeriodUnit.year,
              iso: 'P1Y')
        ],
      );
      final offer = StoreOffer(
        option: _option(
          id: 'winback',
          phases: [
            _phase(
                micros: 8490000,
                formatted: r'$8.49',
                mode: RecurrenceMode.finiteRecurring,
                cycles: 3),
            _phase(
                micros: 49990000,
                formatted: r'$49.99',
                unit: PeriodUnit.year,
                iso: 'P1Y'),
          ],
        ),
        basePlan: annualBase,
      );
      expect(offer.discountPercent, isNull);
    });

    test('a free trial is a free trial, not a 100% discount', () {
      final offer = StoreOffer(
        option: _option(
          id: 'trial',
          phases: [
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
        ),
        basePlan: basePlan,
      );
      expect(offer.discountPercent, isNull);
      expect(offer.startsFree, isTrue);
      expect(offer.termsSentence, r'7 days free, then $16.99 / month.');
    });

    test('an offer that is not cheaper claims nothing', () {
      final offer = StoreOffer(
        option: _option(
          id: 'same',
          phases: [
            _phase(
                micros: 16990000,
                formatted: r'$16.99',
                mode: RecurrenceMode.finiteRecurring,
                cycles: 3),
            _phase(micros: 16990000, formatted: r'$16.99'),
          ],
        ),
        basePlan: basePlan,
      );
      expect(offer.discountPercent, isNull);
    });

    test('an unknown billing period is described as nothing at all', () {
      final offer = StoreOffer(
        option: _option(
          id: 'weird',
          phases: [
            _phase(
                micros: 8490000,
                formatted: r'$8.49',
                unit: PeriodUnit.unknown,
                iso: '',
                mode: RecurrenceMode.finiteRecurring,
                cycles: 3),
            _phase(micros: 16990000, formatted: r'$16.99'),
          ],
        ),
        basePlan: basePlan,
      );
      expect(offer.termsSentence, isNull);
    });
  });

  // ---------------------------------------------------------------------
  group('weekly annualised note', () {
    test('names the multiplier and uses the store’s own currency format', () {
      expect(
        PaywallPricing.weeklyAnnualisedNote(
            weeklyPrice: 3.99, currencySymbolSource: r'$3.99'),
        r'52 weeks at this price is ≈ $207.48',
      );
    });

    test('follows a comma-decimal, symbol-last locale', () {
      expect(
        PaywallPricing.weeklyAnnualisedNote(
            weeklyPrice: 3.99, currencySymbolSource: '3,99 €'),
        '52 weeks at this price is ≈ 207,48 €',
      );
    });

    test('groups thousands the way the template does', () {
      expect(
        PaywallPricing.formatLike('₺149,99', 7799.48),
        '₺7.799,48',
      );
    });

    test('a zero-decimal currency stays zero-decimal', () {
      expect(PaywallPricing.formatLike('¥500', 26000), '¥26,000');
    });

    test('no price, or no template, produces no claim', () {
      expect(
          PaywallPricing.weeklyAnnualisedNote(
              weeklyPrice: null, currencySymbolSource: r'$3.99'),
          isNull);
      expect(
          PaywallPricing.weeklyAnnualisedNote(
              weeklyPrice: 0, currencySymbolSource: r'$3.99'),
          isNull);
      expect(
          PaywallPricing.weeklyAnnualisedNote(
              weeklyPrice: 3.99, currencySymbolSource: null),
          isNull);
      expect(PaywallPricing.formatLike('Free', 10), isNull);
    });
  });

  // ---------------------------------------------------------------------
  group('recommendation', () {
    test('an unreadable account gets the generic line and says so', () {
      final r = recommendUpgrade();
      expect(r.personalised, isFalse);
      expect(r.basis, contains('could not be read'));
      expect(r.entitlementId, isNull);
    });

    test('a reached photo limit is named with the real allowance', () {
      final r = recommendUpgrade(photoChecksUsedThisMonth: 5, journalEntries: 0);
      expect(r.personalised, isTrue);
      expect(r.headline, contains('5 photo checks'));
      expect(r.entitlementId, 'photo_checks');
    });

    test('a full journal outranks partial photo use', () {
      final r = recommendUpgrade(photoChecksUsedThisMonth: 1, journalEntries: 20);
      expect(r.entitlementId, 'journal');
    });

    test('partial photo use states what is actually left', () {
      final r = recommendUpgrade(photoChecksUsedThisMonth: 3, journalEntries: 0);
      expect(r.headline, contains('3 photo checks'));
      expect(r.body, contains('2 are left'));
    });

    test('an account that has hit nothing is told so, not sold a limit', () {
      final r = recommendUpgrade(
          photoChecksUsedThisMonth: 0,
          journalEntries: 0,
          assistantMessagesToday: 0);
      expect(r.headline, contains('has hit a free limit yet'));
      expect(r.entitlementId, 'pdf_report');
    });

    test('no branch claims a veterinarian, a person, or an outcome', () {
      // Phrases, not bare words. "a printable file for a vet visit" is a true
      // description of what the PDF is for; "vet-approved" is a claim about who
      // wrote the product. A scan on the substring "vet" cannot tell them
      // apart, so it bans the second and lets the first through.
      const banned = [
        'vet-approved',
        'vet approved',
        'verified vet',
        'our vet',
        'by a vet',
        'reviewed by',
        'veterinarian',
        'a doctor',
        'diagnos',
        'guarantee',
        'our expert',
        'specially selected',
        'spots left',
        'last chance',
        'expires in',
        'hurry',
        'act now',
        'only today',
      ];
      final all = <OfferRecommendation>[
        recommendUpgrade(),
        recommendUpgrade(photoChecksUsedThisMonth: 5),
        recommendUpgrade(journalEntries: 20),
        recommendUpgrade(assistantMessagesToday: 20),
        recommendUpgrade(photoChecksUsedThisMonth: 2),
        recommendUpgrade(
            photoChecksUsedThisMonth: 0,
            journalEntries: 0,
            assistantMessagesToday: 0),
      ];
      for (final r in all) {
        final text =
            '${r.headline} ${r.body} ${r.basis}'.toLowerCase();
        for (final word in banned) {
          expect(text.contains(word), isFalse,
              reason: '"$word" reached a recommendation: $text');
        }
      }
    });
  });
}

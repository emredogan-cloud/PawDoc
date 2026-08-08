// The entitlement catalogue and the usage meters.
//
// These are the arithmetic behind four screens, and the reason none of them
// can invent a benefit: a surface asks `kEntitlements` what a capability is
// worth, and asks `buildUsageMeters` what has been used. Both are pure.
//
// The parity group is the important half. `kFreePhotoChecksPerMonth` and
// `kFreeAssistantMessagesPerDay` are *presentation* copies of limits the
// server enforces; if a founder raises the server limit and this file keeps
// printing the old one, every premium screen quietly lies about the product.
// So the constants are read back out of the `.mjs` that enforces them — the
// same discipline the emergency keyword lists use across three languages.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/memories/memory.dart' show kFreeMemoryLimit;
import 'package:pawdoc/src/monetization/entitlements.dart';

/// Reads `export const NAME = <int>;` out of an ESM source.
int? _mjsInt(String source, String name) {
  final m = RegExp('export\\s+const\\s+$name\\s*=\\s*(\\d+)').firstMatch(source);
  return m == null ? null : int.parse(m.group(1)!);
}

void main() {
  group('parity with the server, which is what actually enforces this', () {
    final freeTier = File('../supabase/functions/_shared/free_tier.mjs');
    final assistant = File('../supabase/functions/_shared/assistant_chat.mjs');
    final quotaGate = File('../supabase/functions/_shared/quota_gate.mjs');

    test('the Edge sources exist in the repo tree', () {
      expect(freeTier.existsSync(), isTrue);
      expect(assistant.existsSync(), isTrue);
      expect(quotaGate.existsSync(), isTrue);
    });

    test('the photo allowance matches FREE_PHOTO_MONTHLY_LIMIT', () {
      expect(_mjsInt(freeTier.readAsStringSync(), 'FREE_PHOTO_MONTHLY_LIMIT'),
          kFreePhotoChecksPerMonth,
          reason: 'the screens would advertise an allowance the server does '
              'not grant');
    });

    test('the assistant allowance matches ASSISTANT_FREE_DAILY_LIMIT', () {
      expect(
          _mjsInt(assistant.readAsStringSync(), 'ASSISTANT_FREE_DAILY_LIMIT'),
          kFreeAssistantMessagesPerDay);
    });

    test('only photos are metered, so only photos carry a number', () {
      // `isMetered(inputType) { return inputType === "photo"; }` — if that ever
      // grows a second case, the "Unlimited" on the text row is a lie.
      final src = quotaGate.readAsStringSync();
      final body = RegExp(r'export function isMetered\(inputType\)\s*\{(.*?)\}',
              dotAll: true)
          .firstMatch(src)
          ?.group(1);
      expect(body, isNotNull);
      expect(body!.replaceAll(RegExp(r'\s'), ''), 'returninputType==="photo";');

      final text = entitlementById('text_checks');
      expect(text.freeValue, 'Unlimited');
      expect(text.premiumValue, 'Unlimited');
    });

    test('the journal allowance is the one the create gate uses', () {
      expect(kFreeJournalEntries, kFreeMemoryLimit);
      expect(entitlementById('journal').freeValue, '$kFreeMemoryLimit entries');
    });
  });

  group('the catalogue says only what the product does', () {
    test('every row is uniquely identified', () {
      final ids = kEntitlements.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('exactly four things change when you upgrade', () {
      // Photo checks, assistant messages, journal entries, the PDF. If a fifth
      // ever appears it must be because something was built, not written.
      expect(premiumUnlocks.map((e) => e.id).toList(),
          ['photo_checks', 'assistant', 'journal', 'pdf_report']);
    });

    test('a metered row always names both allowances', () {
      for (final e in kEntitlements.where(
          (e) => e.kind == EntitlementKind.metered)) {
        expect(e.freeValue, isNot('—'), reason: e.id);
        expect(e.premiumValue, 'Unlimited', reason: e.id);
      }
    });

    test('a premium-only row is absent on free, never "limited"', () {
      for (final e in kEntitlements
          .where((e) => e.kind == EntitlementKind.premiumOnly)) {
        expect(e.freeValue, '—', reason: e.id);
      }
    });

    test('a shared row reads identically on both plans', () {
      for (final e in includedForEveryone) {
        expect(e.freeValue, e.premiumValue,
            reason: '${e.id} must not imply an upgrade changes it');
      }
    });

    test('a Soon row promises nothing on either plan', () {
      final soon =
          kEntitlements.where((e) => e.kind == EntitlementKind.soon).toList();
      expect(soon, isNotEmpty);
      for (final e in soon) {
        expect(e.freeValue, '—');
        expect(e.premiumValue, '—',
            reason: '${e.id} is drawn by the reference and not built — '
                'no plan may appear to include it');
      }
    });

    test('emergency help is free, on both plans, and says so', () {
      final e = entitlementById('emergency');
      expect(e.kind, EntitlementKind.everyone);
      expect(e.freeValue, 'Always');
      expect(e.premiumValue, 'Always');
    });

    test('pets are unlimited on both plans (the reference sells 1 vs 15)', () {
      final e = entitlementById('pets');
      expect(e.freeValue, 'Unlimited');
      expect(e.premiumValue, 'Unlimited');
    });

    test('storage is not metered on either plan (the reference sells 1 GB)',
        () {
      final e = entitlementById('storage');
      expect(e.freeValue, 'Not metered');
      expect(e.premiumValue, 'Not metered');
    });

    test('no row mentions a capability that does not exist', () {
      // Every invention the four references sell, by name.
      final banned = [
        RegExp(r'vet chat', caseSensitive: false),
        RegExp(r'verified vet', caseSensitive: false),
        RegExp(r'made by vets', caseSensitive: false),
        RegExp(r'priority support', caseSensitive: false),
        RegExp(r'dedicated support', caseSensitive: false),
        RegExp(r'advanced analytics', caseSensitive: false),
        RegExp(r'early access', caseSensitive: false),
        RegExp(r'multi-user', caseSensitive: false),
        RegExp(r'money-?back', caseSensitive: false),
        RegExp(r'\bGB\b'),
      ];
      for (final e in kEntitlements) {
        final text = '${e.title} ${e.blurb} ${e.freeValue} ${e.premiumValue}';
        for (final p in banned) {
          expect(p.hasMatch(text), isFalse,
              reason: '${e.id} carries "${p.pattern}"');
        }
      }
    });
  });

  group('usage meters count only what is counted', () {
    List<UsageMeter> meters({
      bool premium = false,
      int photo = 2,
      int journal = 4,
      int? assistant = 3,
      int pets = 2,
      DateTime? resetAt,
    }) =>
        buildUsageMeters(
          isPremium: premium,
          photoChecksUsed: photo,
          photoChecksResetAt: resetAt,
          journalEntries: journal,
          assistantMessagesToday: assistant,
          petCount: pets,
          now: DateTime(2026, 8, 8, 10),
        );

    UsageMeter byId(List<UsageMeter> list, String id) =>
        list.firstWhere((m) => m.id == id);

    test('a free account sees the real ceilings', () {
      final list = meters();
      expect(byId(list, 'photo_checks').limit, kFreePhotoChecksPerMonth);
      expect(byId(list, 'photo_checks').remaining, 3);
      expect(byId(list, 'assistant').limit, kFreeAssistantMessagesPerDay);
      expect(byId(list, 'journal').limit, kFreeJournalEntries);
    });

    test('a premium account has no ceiling, not a bigger one', () {
      final list = meters(premium: true);
      for (final id in ['photo_checks', 'assistant', 'journal']) {
        final m = byId(list, id);
        expect(m.unlimited, isTrue, reason: id);
        expect(m.remaining, isNull, reason: id);
        expect(m.fraction, 0, reason: '$id must draw no bar');
      }
    });

    test('the text-check row is never metered on either plan', () {
      for (final premium in [false, true]) {
        final m = byId(meters(premium: premium), 'text_checks');
        expect(m.tracked, isFalse);
        expect(m.limit, isNull);
        expect(m.note, contains('Never metered'));
      }
    });

    test('storage draws no bar and shows no figure', () {
      final m = byId(meters(), 'storage');
      expect(m.tracked, isFalse);
      expect(m.used, isNull);
      expect(m.limit, isNull);
      expect(m.fraction, 0);
    });

    test('pets are counted but never limited', () {
      final m = byId(meters(pets: 7), 'pets');
      expect(m.used, 7);
      expect(m.limit, isNull);
      expect(m.note, contains('No limit'));
    });

    test('an unreadable assistant count is not a zero', () {
      final m = byId(meters(assistant: null), 'assistant');
      expect(m.used, isNull);
      expect(m.tracked, isFalse,
          reason: 'a failed read must not render as "0 used"');
      expect(m.note, contains('could not be read'));
    });

    test('the PDF row is locked for free and open for premium, never counted',
        () {
      expect(byId(meters(), 'pdf_report').locked, isTrue);
      expect(byId(meters(premium: true), 'pdf_report').locked, isFalse);
      for (final premium in [false, true]) {
        expect(byId(meters(premium: premium), 'pdf_report').used, isNull,
            reason: 'nothing counts PDF generations on either plan');
      }
    });

    test('an exhausted meter reports zero left, not a negative', () {
      final m = byId(meters(photo: 9), 'photo_checks');
      expect(m.remaining, 0);
      expect(m.exhausted, isTrue);
      expect(m.fraction, 1.0, reason: 'the bar clamps rather than overflowing');
    });

    test('the photo row carries the server reset date, and only that one', () {
      final at = DateTime(2026, 9, 1);
      final list = meters(resetAt: at);
      expect(byId(list, 'photo_checks').resetsAt, at);
      // The journal allowance is a total; a reset date there would be a lie.
      expect(byId(list, 'journal').resetsAt, isNull);
      expect(byId(list, 'journal').note, contains('does not reset'));
    });

    test('premium clears the reset dates — nothing is rolling over', () {
      final list = meters(premium: true, resetAt: DateTime(2026, 9, 1));
      expect(byId(list, 'photo_checks').resetsAt, isNull);
      expect(byId(list, 'assistant').resetsAt, isNull);
    });

    test('the assistant window ends at the next local midnight', () {
      final m = byId(meters(), 'assistant');
      expect(m.resetsAt, DateTime(2026, 8, 9));
    });
  });
}

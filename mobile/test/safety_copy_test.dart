// Phase E safety guard — the most important test in the UI migration.
//
// UI_SAFETY_CONTRACT_REVIEW found 24 violations across 19 of the 57 mockups,
// 9 of them CRITICAL. Auditing the shipping code showed something worth
// stating plainly: **the app is already compliant and the redesign is what
// would break it.** `confidence` is parsed but never rendered, there is no
// differential UI, and conditions are never named.
//
// So the risk is not a bug to fix — it is a regression to prevent, over the
// remaining phases, by anyone implementing a screen faithfully from its mockup.
// These assertions are that tripwire. They are source-level on purpose: a
// widget test only covers the states it happens to pump, whereas the mockups'
// exact strings must not appear anywhere, in any language, in any branch.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Everything under lib/, excluding generated localisation output.
List<File> _sourceFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('/generated/'))
    .toList();

/// Presentation code only.
///
/// `lib/src/models/` is excluded deliberately: `AnalysisResult` must keep
/// parsing `confidence` off the wire — the contract is frozen across
/// Dart/Python/TS, and the server uses the value to gate "insufficient
/// information". The rule is that it never reaches a *user*, not that it stops
/// existing.
List<File> _uiFiles() =>
    _sourceFiles().where((f) => !f.path.contains('/models/')).toList();

/// Surfaces that render AI output about a specific animal.
///
/// The "never name a condition" rule is scoped to these. Generic breed
/// education is explicitly allowed and is not AI output — `result_screen`
/// already draws the same line with "about this KIND of presentation, never
/// findings or condition names about this animal".
List<File> _aiOutputFiles() => _sourceFiles()
    .where((f) =>
        f.path.contains('/analysis/') ||
        f.path.contains('/assistant/') ||
        f.path.contains('/l10n/'))
    .toList();

List<File> _arbFiles() => Directory('lib/l10n')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.arb'))
    .toList();

/// Strip `//` and `///` comments so the contract's own prose — which quotes the
/// forbidden phrases in order to forbid them — does not trip the scan.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .map((l) {
      final i = l.indexOf('//');
      return i == -1 ? l : l.substring(0, i);
    })
    .join('\n');

void _expectAbsent(Iterable<RegExp> patterns, String reason, {List<File>? scope}) {
  final hits = <String>[];
  for (final f in scope ?? [..._uiFiles(), ..._arbFiles()]) {
    final text = f.path.endsWith('.dart')
        ? _codeOnly(f.readAsStringSync())
        : f.readAsStringSync();
    for (final p in patterns) {
      for (final m in p.allMatches(text)) {
        hits.add('${f.path}: "${m.group(0)}"');
      }
    }
  }
  expect(hits, isEmpty, reason: '$reason\n${hits.join('\n')}');
}

void main() {
  group('rule: confidence is never shown to users', () {
    test('no confidence value is formatted into a string', () {
      // The mockups render "68% confidence" on the primary result (V-01) and a
      // confidence value inside the risk chip (V-04).
      _expectAbsent([
        RegExp(r'''["'][^"']*\bconfidence\b[^"']*["']''', caseSensitive: false),
        RegExp(r'\$\{?[a-zA-Z_.]*[Cc]onfidence'),
        RegExp(r'confidence[a-zA-Z]*\s*\*\s*100'),
      ], 'confidence must never reach the UI (CLAUDE.md; review V-01/V-04)');
    });
  });

  group('rule: never name a condition', () {
    test('no diagnostic condition name appears in UI copy', () {
      // V-05: the emergency mockup renders "Potential Concern: Skin Infection".
      // These are the condition names the review caught across the mockups.
      _expectAbsent([
        RegExp(r'''["'][^"']*\b(skin infection|ear infection|hot spot|dermatitis|'''
            r'''pyoderma|mange|ringworm|allergic reaction|mantar enfeksiyon)'''
            r'''[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*potential concern[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*likely caused by[^"']*["']''', caseSensitive: false),
      ], 'AI output describes an observation, never a cause (review V-05/V-10/V-11)',
          scope: [..._aiOutputFiles(), ..._arbFiles()]);
    });
  });

  group('rule: never render "normal", and no "do nothing" rung', () {
    test('no all-clear headline exists', () {
      // V-03/V-09/V-19/V-20/V-21. Each of these terminates with reassurance and
      // no action — the action ladder has no "do nothing" rung.
      _expectAbsent([
        RegExp(r'''["'][^"']*no health issues[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*no signs of a serious[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*everything looks (good|fine|great)[^"']*["']''',
            caseSensitive: false),
        RegExp(r'''["'][^"']*(is|are) doing great[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*all clear[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*nothing to worry about[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*conditions\s*[:0][^"']*none[^"']*["']''',
            caseSensitive: false),
      ], 'no output may terminate with reassurance instead of an action');
    });

    test('the triage vocabulary never renders the word "normal" as a verdict', () {
      // "LIKELY NORMAL" was purged from the product in PR #80; the mockups
      // reintroduce the idea as "Low risk / No signs of a serious condition".
      _expectAbsent([
        RegExp(r'''["'][^"']*likely normal[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*appears normal[^"']*["']''', caseSensitive: false),
      ], 'the verdict→record reframe (PR #80) must not be reverted');
    });
  });

  group('rule: differential percentages are never rendered', () {
    test('no probability list reaches the UI', () {
      // V-02: the mockups show 21% / 7% / 4% bars beneath the result.
      _expectAbsent([
        RegExp(r'''["'][^"']*\bdifferential\b[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*\blikelihood\b[^"']*["']''', caseSensitive: false),
        RegExp(r'''["'][^"']*\bprobability\b[^"']*["']''', caseSensitive: false),
      ], 'certainty is qualitative, never quantified (review V-02, §3.5)');
    });
  });

  group('rule: the Health Score is a wellness metric, not a verdict', () {
    test('it is never labelled clinically', () {
      // Owner decision D-2: lightweight wellness metric only — not a diagnosis,
      // clinical score, severity or probability.
      _expectAbsent([
        RegExp(r'''["'][^"']*(health|wellness) score[^"']*\b'''
            r'''(diagnos|clinical|severity|risk level)[^"']*["']''',
            caseSensitive: false),
        RegExp(r'''["'][^"']*clinical score[^"']*["']''', caseSensitive: false),
      ], 'D-2: the Health Score must not read as a clinical verdict');
    });
  });

  group('rule: emergency surfaces stay model-free and unmonetised', () {
    test('no AI affordance or monetisation on the emergency screens', () {
      // V-16/V-17 and CLAUDE.md rule 4: the red path is offline-capable and
      // model-free — no AI-driven content, no upsell, no meter.
      final emergency = _sourceFiles()
          .where((f) => f.path.contains('/emergency/'))
          .toList();
      expect(emergency, isNotEmpty, reason: 'emergency sources not found');

      final hits = <String>[];
      for (final f in emergency) {
        final code = _codeOnly(f.readAsStringSync());
        for (final p in [
          RegExp(r'''["'][^"']*(start ai|ai triage|ai-powered|ai powered)[^"']*["']''',
              caseSensitive: false),
          RegExp(r'''["'][^"']*(upgrade|premium|subscribe|unlock)[^"']*["']''',
              caseSensitive: false),
          RegExp(r'''["'][^"']*heat alert[^"']*["']''', caseSensitive: false),
        ]) {
          for (final m in p.allMatches(code)) {
            hits.add('${f.path}: "${m.group(0)}"');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'nothing may be added to the emergency surfaces '
              '(CLAUDE.md rule 4; review V-16/V-17)\n${hits.join('\n')}');
    });

    test('the elements owner decision D-1 removed cannot come back', () {
      // Decision 1 (final, owner-approved) strips every rule-violating element
      // from `emergency_hub`. Two were catalogued by the review — the AI Triage
      // quick action (V-16) and the Heat Alert promo strip (C-6). Reading the
      // mockup for this phase surfaced a third the review did not list: an
      // "At Risk Pets / Needs Attention / View Triage" card, which puts a
      // model-derived triage verdict ("Based on recent symptoms") directly on
      // the red path. All three are pinned here so a later hub build cannot
      // reintroduce them.
      final emergency =
          _sourceFiles().where((f) => f.path.contains('/emergency/')).toList();
      final hits = <String>[];
      for (final f in emergency) {
        final code = _codeOnly(f.readAsStringSync());
        for (final p in [
          RegExp(r'''["'][^"']*at risk pets[^"']*["']''', caseSensitive: false),
          RegExp(r'''["'][^"']*needs attention[^"']*["']''', caseSensitive: false),
          RegExp(r'''["'][^"']*view triage[^"']*["']''', caseSensitive: false),
          RegExp(r'''["'][^"']*based on recent symptoms[^"']*["']''',
              caseSensitive: false),
          RegExp(r'''["'][^"']*check symptoms now[^"']*["']''',
              caseSensitive: false),
        ]) {
          for (final m in p.allMatches(code)) {
            hits.add('${f.path}: "${m.group(0)}"');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'owner decision D-1: the emergency surface carries help '
              'contacts, first aid, the disclaimer and the acknowledgment gate '
              '— no triage verdict, no AI shortcut, no promo\n${hits.join('\n')}');
    });

    test('emergency sources import no analysis or monetisation code', () {
      for (final f in _sourceFiles().where((f) => f.path.contains('/emergency/'))) {
        final src = f.readAsStringSync();
        for (final forbidden in [
          "import '../analysis/",
          "import '../monetization/",
          "import '../assistant/",
        ]) {
          expect(src.contains(forbidden), isFalse,
              reason: '${f.path} must not depend on $forbidden — the red path '
                  'stays offline-capable and model-free');
        }
      }
    });
  });

  group('rule: the assistant never implies a veterinarian (V-23)', () {
    test('no assistant surface claims a veterinary role', () {
      // The mockups label it "AI Vet Assistant". The shipping app calls it
      // "Assistant / Your pet-life companion", which is correct — this pins
      // that a redesign pass does not adopt the mockup's title.
      final assistant = _sourceFiles()
          .where((f) => f.path.contains('/assistant/'))
          .toList();
      expect(assistant, isNotEmpty);
      final hits = <String>[];
      for (final f in assistant) {
        final code = _codeOnly(f.readAsStringSync());
        for (final p in [
          RegExp(r'''["'][^"']*\bvet(erinary|erinarian)?\s+assistant[^"']*["']''',
              caseSensitive: false),
          RegExp(r'''["'][^"']*\bdr\.?\s*paw[^"']*["']''', caseSensitive: false),
          RegExp(r'''["'][^"']*virtual vet[^"']*["']''', caseSensitive: false),
        ]) {
          for (final m in p.allMatches(code)) {
            hits.add('${f.path}: "${m.group(0)}"');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'the assistant is a companion, not a licensed professional; '
              'implying otherwise invites reliance the product cannot carry\n'
              '${hits.join('\n')}');
    });

    test('suggestion chips do not presuppose a condition (V-12)', () {
      // The mockups seed the assistant with chips like "Why is my dog itching?"
      // — which asserts a symptom before the owner has said anything. The
      // shipping chips are lifestyle/care framed.
      final src =
          File('lib/src/assistant/assistant_screen.dart').readAsStringSync();
      final code = _codeOnly(src);
      for (final p in [
        RegExp(r'''["'][^"']*why is my (dog|cat|pet)[^"']*["']''',
            caseSensitive: false),
        RegExp(r'''["'][^"']*(is|are) (my )?(dog|cat|pet) sick[^"']*["']''',
            caseSensitive: false),
        RegExp(r'''["'][^"']*what'?s wrong with[^"']*["']''', caseSensitive: false),
      ]) {
        expect(p.hasMatch(code), isFalse,
            reason: 'a suggestion chip must not assert a symptom the owner has '
                'not reported');
      }
    });
  });

  group('rule: exported records carry provenance (V-22)', () {
    test('the report builder marks AI output and owner input separately', () {
      // A vet reading the exported report must be able to tell, line by line,
      // what a model produced from what the owner typed. Without the markers
      // the sections render identically and an AI observation can be read as a
      // clinical finding.
      final src = File('lib/src/export/health_report.dart').readAsStringSync();
      expect(src.contains('Source: PawDoc AI'), isTrue,
          reason: 'AI-derived sections must be labelled');
      expect(src.contains('Not examined by a veterinarian'), isTrue,
          reason: 'the report must not imply veterinary review');
      expect(src.contains('Source: entered by the owner'), isTrue,
          reason: 'owner-recorded sections must be labelled');
      // "Primary concern" reads as a finding; the contract allows an
      // observation only.
      expect(src.contains('Primary concern'), isFalse,
          reason: 'describe what was observed, never a concern/finding');
    });
  });

  group('rule: the disclaimer is API-injected, never hardcoded on', () {
    test('the result screens gate the disclaimer on the payload flag', () {
      for (final path in [
        'lib/src/analysis/result_screen.dart',
        'lib/src/analysis/emergency_result_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('disclaimerRequired'), isTrue,
            reason: '$path must gate the disclaimer on the server-forced flag');
      }
    });
  });

  // ---------------------------------------------------------------------
  group('rule: no privacy claim broader than the data flow', () {
    // Play's Data safety form is a *binding* declaration, and an in-app
    // sentence that outruns it puts two incompatible statements on record with
    // Google. PawDoc's actual flow: the account, pets and records live on
    // Supabase; photos are uploaded to Cloudflare R2 (EXIF/GPS stripped
    // client-side first) and sent to a model provider; crashes go to Sentry
    // and events to PostHog. Some of that is genuinely private. None of it is
    // "100% private", and nothing "stays on your device".
    //
    // This is the *scope-inflation* class: a true narrow claim widened until
    // it is unverifiable, because the broad version markets better. It has
    // already happened twice in this repository — onboarding shipped "We never
    // sell your data. Ever.", and two location comments described the Smart
    // Walks path as if it were the whole app while community stores a geohash
    // cell. Both are fixed; this is the tripwire.
    // The scan is on the BROAD SUBJECT, not on the absolute word.
    //
    // A blunt ban on "never shared" is wrong twice over, and both wrong
    // answers showed up the first time this test ran. It flags
    // `community_sections.dart`'s "Never share someone else's address, or
    // your own." — which is safety *advice to the user*, not a claim by
    // PawDoc — and it flags `ai_transparency_screen.dart`'s "Your name, your
    // email address, your location and your account never leave with it",
    // which is exemplary scoped writing: it enumerates the data and names
    // what it does not leave with.
    //
    // So what is banned is an absolute whose subject is *everything*: "your
    // data", "your information", "your pet's data". Name the category and the
    // sentence passes, because a named category can be checked.
    test('no absolute is claimed about "your data" as a whole', () {
      _expectAbsent(
        [
          RegExp(
              r'(your|the|all)\s+(pet.s\s+)?(data|information|records?)\s+'
              r'(is|are|stays?|never)[^.\n]{0,60}'
              r'(never\s+(shared|sold|sent|leaves)|100%|completely|'
              r'stays?\s+on\s+your)',
              caseSensitive: false),
          RegExp(r'100%\s*(private|secure|safe|confidential|anonymous)',
              caseSensitive: false),
          RegExp(r'completely\s+(private|anonymous|secure)',
              caseSensitive: false),
          RegExp(r'\bfully\s+(private|anonymous)\b', caseSensitive: false),
          // "We never sell your data. Ever." — the intensifier is the tell.
          RegExp(r'\.\s*Ever\.'),
          RegExp(r'(your|the)\s+data\s+(never\s+leaves|stays)\s+'
              r'(your\s+)?(device|phone)', caseSensitive: false),
          RegExp(r'military[- ]grade', caseSensitive: false),
          RegExp(r'\bbank[- ]level\b', caseSensitive: false),
          RegExp(r'\bzero[- ]knowledge\b', caseSensitive: false),
        ],
        'A privacy claim must name the data it covers. An absolute about '
        '"your data" as a whole cannot be verified, cannot be kept, and '
        'contradicts the Data safety declaration — photos genuinely do leave '
        'the device. Write the scoped version: say which data, and where it '
        'goes. `ai_transparency_screen.dart` is the model to copy.',
      );
    });

    test('no absolute is claimed about the emergency path either', () {
      // The emergency path IS genuinely offline and model-free, which makes it
      // the most tempting place to over-claim. "Works offline" is true and
      // allowed; "works anywhere, always" is not.
      _expectAbsent(
        [
          RegExp(r'always\s+works\b', caseSensitive: false),
          RegExp(r'works\s+(anywhere|everywhere)\b', caseSensitive: false),
          RegExp(r'guaranteed\b', caseSensitive: false),
        ],
        'The emergency path is offline-capable, not infallible. Say what it '
        'does (offline, unmetered, never paywalled), not what it guarantees.',
      );
    });
  });
}

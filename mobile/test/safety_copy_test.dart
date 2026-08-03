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
}

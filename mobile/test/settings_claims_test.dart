// The settings batch's tripwire — the counterpart to `safety_copy_test`.
//
// `settings_screens_test` scans what the five surfaces *render*, which is the
// stronger check but only covers the states it happens to pump. These
// assertions are source-level and cover every branch, in every language, in
// every file: the phrases below must not exist anywhere in the presentation
// layer at all.
//
// Why it is worth having both: the five references between them draw eighteen
// controls over capabilities PawDoc does not have, and three of them —
// Two-Factor Authentication, Biometric Unlock, Login Alerts — are drawn as
// switches **already flipped on**. A user who reads "Two-Factor Authentication:
// On" and believes it is a user who has been told their account is protected by
// something that is not there. That is a security claim with consequences, not
// a copy slip, and it is exactly the kind of thing a later batch reintroduces
// by faithfully implementing a plate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The presentation layer, minus generated localisation output.
List<File> _uiFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('/generated/'))
    .toList();

/// Strip `//` and `///` comments, so the doc comments that quote each rejected
/// claim in order to explain why it was rejected do not trip the scan.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .map((l) {
      final i = l.indexOf('//');
      return i == -1 ? l : l.substring(0, i);
    })
    .join('\n');

void _expectAbsent(Map<RegExp, String> patterns) {
  final hits = <String>[];
  for (final f in _uiFiles()) {
    final code = _codeOnly(f.readAsStringSync());
    patterns.forEach((pattern, source) {
      for (final m in pattern.allMatches(code)) {
        hits.add('${f.path}: "${m.group(0)}"  <- $source');
      }
    });
  }
  expect(hits, isEmpty, reason: hits.join('\n'));
}

/// Only string literals, so an identifier such as `hasBillingIssue` or a
/// package import is never mistaken for user-facing copy.
RegExp _inString(String body) =>
    RegExp('''["'][^"']*$body[^"']*["']''', caseSensitive: false);

void main() {
  group('rule: no security capability is claimed that does not exist', () {
    test('no second factor, biometric lock or login monitoring is asserted',
        () {
      _expectAbsent({
        // The affirmative forms only. The screens deliberately *name* these as
        // absent ("Two-factor authentication · Not available"), which is the
        // honest treatment and must stay possible.
        _inString(r'two-factor is on'): 'privacy_security: the green switch',
        _inString(r'2fa (is )?enabled'): 'privacy_security',
        _inString(r'protected by two-factor'): 'privacy_security',
        _inString(r'face id / fingerprint to unlock'):
            'privacy_security: "Biometric Unlock"',
        _inString(r'get notified when someone logs in'):
            'privacy_security: "Login Alerts"',
      });
    });

    test('no encryption claim beyond what the stack does', () {
      _expectAbsent({
        // PawDoc is not end-to-end encrypted and cannot be: the server
        // decrypts every photo to moderate and analyse it.
        _inString(r'end-to-end encryption'):
            'privacy_security hero chip / ai_transparency badge',
        _inString(r'is end-to-end encrypted'): 'the same claim, adjectival',
        _inString(r'encrypted and never used to train'):
            'ai_transparency: "Privacy First"',
        _inString(r'military-grade'): 'the usual escalation of this claim',
        _inString(r'industry-leading security'):
            'profile + account_management trust band',
        _inString(r'bank-level security'): 'the same claim, other wording',
      });
    });

    test('no compliance or residency assertion is made in the app', () {
      // These belong in the published policy, which is the document that
      // legally binds; a tile in an app binds nobody and ages badly.
      _expectAbsent({
        _inString(r'we comply with gdpr'): 'privacy_security compliance tile',
        _inString(r'gdpr,? kvkk'): 'privacy_security compliance tile',
        _inString(r'global standards'): 'privacy_security compliance tile',
        _inString(r'stored securely in your region'):
            'privacy_security: "Data Residency"',
        _inString(r'retain data only as long as necessary'):
            'privacy_security: "Data Retention"',
      });
    });

    test('the settings surfaces make no data-selling promise', () {
      // Scoped to `lib/src/account/` rather than app-wide, and deliberately so.
      //
      // The scan found a PRE-EXISTING instance of this claim in the shipping
      // app — `onboarding_flow.dart` renders "We never sell your data. Ever."
      // on its privacy strip. It is not false (PawDoc sells nothing), but it is
      // a forward-looking promise, which belongs in the privacy policy that
      // legally binds rather than in app copy. That line predates this batch
      // and was device-walked and approved with the onboarding rebuild, so it
      // is SURFACED for an owner decision, not rewritten here.
      //
      // Widen this scope to `_uiFiles()` if and when that line is changed.
      final hits = <String>[];
      final pattern = _inString(r'never sell your data');
      for (final f in _uiFiles()
          .where((f) => f.path.contains('/account/'))) {
        for (final m in pattern.allMatches(_codeOnly(f.readAsStringSync()))) {
          hits.add('${f.path}: "${m.group(0)}"');
        }
      }
      expect(hits, isEmpty,
          reason: 'the settings screens describe who receives data instead of '
              'promising what will never be done with it\n${hits.join('\n')}');
    });
  });

  group('rule: no veterinary review of AI output is ever implied', () {
    test('the reference\'s four vet-review claims cannot render', () {
      // The single most dangerous invention in the reference set: it attaches a
      // licensed opinion to the output itself. `entitlements.dart` already
      // refuses the plan-level version of this ("chat with verified
      // veterinarians"); this is the output-level version.
      _expectAbsent({
        _inString(r'vet[- ]verified'): 'ai_transparency: "Advanced AI, Vet-Verified"',
        _inString(r'vet[- ]reviewed'): 'ai_transparency: step 3 of 4',
        _inString(r'reviewed by vet'): 'ai_transparency hero sub-claim',
        _inString(r'veterinary (experts|professionals) review'):
            'ai_transparency: "review and validate AI-generated insights"',
        _inString(r'validated by a vet'): 'ai_transparency',
        _inString(r'vet knowledge base'):
            'ai_transparency: an invented curated corpus',
        _inString(r'clinically validated'): 'a regulatory claim PawDoc has not earned',
      });
    });
  });

  group('rule: no billing or session capability is drawn', () {
    test('no payment instrument, invoice or device count', () {
      _expectAbsent({
        _inString(r'visa •+ ?\d'): 'account_management: "Visa •••• 4242"',
        _inString(r'billing history'): 'account_management row',
        _inString(r'view invoices'): 'account_management row',
        _inString(r'\d+ active devices?'): 'account_management: "3 Active"',
        _inString(r'active sessions'): 'privacy_security row',
        _inString(r'pause your premium subscription'):
            'account_management: PawDoc implements no pause',
      });
    });
  });

  group('rule: no notification channel or category that cannot send', () {
    test('no email, SMS or push category is offered as a preference', () {
      _expectAbsent({
        // The affirmative forms. The screen states each of these as *not sent*,
        // which must stay possible.
        _inString(r'receive updates via email'):
            'notifications: "Delivery Preferences"',
        _inString(r'important alerts via text message'):
            'notifications: the SMS channel',
        _inString(r'get alerts on your mobile device'):
            'notifications: the push channel — there is no push vendor',
        _inString(r'promotions and offers'): 'notifications category',
        _inString(r'special offers, premium discounts'):
            'notifications category',
        _inString(r'seasonal advice and helpful educational'):
            'notifications: "Tips & Education"',
        _inString(r'ai health insights, symptom changes'):
            'notifications: "Health Alerts" — nothing watches a pet',
      });
    });
  });

  group('rule: the owner is never described in data PawDoc does not hold', () {
    test('no phone, location or birth date field is presented as stored', () {
      _expectAbsent({
        _inString(r'update your phone number'): 'account_management row',
        _inString(r'\+90 ?5\d\d'): 'profile: the mockup literal',
        _inString(r'i̇stanbul, türkiye'): 'profile: the mockup literal',
        _inString(r'emre\.dogan@'): 'profile: the mockup literal',
        _inString(r'joined on may 12'): 'profile: the mockup literal',
        _inString(r'name, email, phone, location'):
            'account_management: "Personal Information"',
      });
    });
  });

  group('rule: the settings surfaces expose no disabled switch', () {
    test('every Switch on the five screens takes a non-null onChanged', () {
      // A disabled switch reads as "temporarily off" — which is why the
      // unavailable capabilities are rows that explain themselves instead.
      // `AccountToggleRow` makes this structural: `onChanged` is required and
      // non-nullable, so a screen cannot construct a dead one.
      final sections =
          File('lib/src/account/account_sections.dart').readAsStringSync();
      expect(sections.contains('final ValueChanged<bool> onChanged;'), isTrue,
          reason: 'AccountToggleRow.onChanged must stay non-nullable — it is '
              'what makes a decorative switch unrepresentable');

      for (final path in [
        'lib/src/account/profile_screen.dart',
        'lib/src/account/account_management_screen.dart',
        'lib/src/account/privacy_security_screen.dart',
        'lib/src/account/notifications_settings_screen.dart',
        'lib/src/account/ai_transparency_screen.dart',
      ]) {
        final code = _codeOnly(File(path).readAsStringSync());
        expect(code.contains('onChanged: null'), isFalse,
            reason: '$path draws a disabled switch');
        expect(RegExp(r'\bSwitch\(').hasMatch(code), isFalse,
            reason: '$path builds a raw Switch instead of going through '
                'AccountToggleRow, which is the type that enforces the rule');
      }
    });
  });

  group('rule: the five surfaces reach real destinations', () {
    test('each screen exists and is imported by something that opens it', () {
      const screens = [
        'profile_screen.dart',
        'account_management_screen.dart',
        'privacy_security_screen.dart',
        'notifications_settings_screen.dart',
        'ai_transparency_screen.dart',
      ];
      final all = _uiFiles().map((f) => f.readAsStringSync()).join('\n');
      for (final s in screens) {
        expect(File('lib/src/account/$s').existsSync(), isTrue,
            reason: '$s is missing');
        expect(all.contains(s), isTrue,
            reason: '$s is never imported — the screen would be unreachable');
      }
      // Profile is the account home, reached from the Home app bar.
      final home = File('lib/src/home/home_screen.dart').readAsStringSync();
      expect(home.contains('ProfileScreen()'), isTrue,
          reason: 'the account entry point must open the new Profile');
    });
  });
}

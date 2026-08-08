// Mockups `profile`, `account_management`, `privacy_security`,
// `notifications`, `ai_transparency` — the final five references.
//
// These are settings screens, so almost none of the risk is layout. The risk
// is that a control which does nothing looks like one that does, or that a
// security claim the product cannot back reaches a user who then relies on it.
// The reference draws eighteen such controls, three of them as switches
// already flipped on (Two-Factor Authentication, Biometric Unlock, Login
// Alerts) and one as a fabricated device count ("3 Active").
//
// So the `product truth` group is a page scan over every string these screens
// render: a later batch may move the blocks around, and what must not change
// is that none of those sentences can reach a user. The `real state` group
// checks the other half — that what *is* drawn comes from the account rather
// than from a constant.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/account_identity.dart';
import 'package:pawdoc/src/account/account_management_screen.dart';
import 'package:pawdoc/src/account/account_sections.dart';
import 'package:pawdoc/src/account/ai_transparency_screen.dart';
import 'package:pawdoc/src/account/notifications_settings_screen.dart';
import 'package:pawdoc/src/account/privacy_security_screen.dart';
import 'package:pawdoc/src/account/profile_screen.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/community/community_models.dart';
import 'package:pawdoc/src/community/community_repository.dart';
import 'package:pawdoc/src/monetization/subscription_state.dart';
import 'package:pawdoc/src/notifications/notification_prefs.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/reminders/reminder.dart';
import 'package:pawdoc/src/reminders/reminders_repository.dart';

/// A 393dp-wide viewport, tall enough that the whole page is laid out.
///
/// Load-bearing: the default 800x600 test surface leaves everything below the
/// fold unbuilt, so assertions about the bottom half of a settings page pass
/// vacuously. (The assistant batch learned this the expensive way.)
void _surface(WidgetTester tester, {double height = 4600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

AccountIdentity _identity({
  String email = 'owner@example.com',
  String provider = 'email',
  bool anonymous = false,
  String? name,
}) =>
    AccountIdentity(
      userId: 'u-1',
      email: email,
      provider: provider,
      createdAt: DateTime.utc(2026, 3, 14),
      isAnonymous: anonymous,
      displayName: name,
    );

Widget _app(
  Widget home, {
  AccountIdentity? identity,
  bool premium = false,
  bool signedOut = false,
  AccountSummary? summary,
  bool summaryFails = false,
  CommunityProfile? community,
  bool remindersFail = false,
  List<Reminder>? reminders,
  NotificationSettings? notifications,
  bool? permission = true,
  SubscriptionSnapshot? snapshot,
}) =>
    ProviderScope(
      overrides: [
        accountIdentityProvider
            .overrideWithValue(signedOut ? null : (identity ?? _identity())),
        userProfileProvider.overrideWith((ref) async => UserProfile(
              subscriptionStatus: premium ? 'premium' : 'free',
              photoLogsUsedThisMonth: 1,
            )),
        subscriptionSnapshotProvider.overrideWith(
            (ref) async => snapshot ?? SubscriptionSnapshot.unreadable),
        if (summaryFails)
          // `Future.error`, not an async throw: Riverpod 3 retries a provider
          // that threw, which bounces it straight back to `loading` and the
          // error branch never renders.
          accountSummaryProvider.overrideWith(
              (ref) => Future<AccountSummary>.error(Exception('offline')))
        else
          accountSummaryProvider.overrideWith((ref) async =>
              summary ??
              const AccountSummary(
                pets: 2,
                healthRecords: 17,
                vaccinationRecords: 4,
                reminders: 3,
                journalEntries: 9,
              )),
        myCommunityProfileProvider.overrideWith((ref) async => community),
        if (remindersFail)
          allRemindersProvider.overrideWith(
              (ref) => Future<List<Reminder>>.error(Exception('offline')))
        else
          allRemindersProvider
              .overrideWith((ref) async => reminders ?? const <Reminder>[]),
        petsListProvider.overrideWith((ref) async => const <Pet>[]),
        notificationSettingsProvider.overrideWith((ref) async =>
            notifications ??
            const NotificationSettings(
              healthReminders: true,
              walkReminder: false,
              walkHour: 8,
            )),
        notificationPermissionProvider.overrideWith((ref) async => permission),
      ],
      child: MaterialApp(home: home),
    );

/// Every string the screen actually rendered.
List<String> _renderedText(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final data = w.data;
    if (data != null) {
      out.add(data);
      continue;
    }
    final span = w.textSpan;
    if (span != null) out.add(span.toPlainText());
  }
  return out;
}

void main() {
  // -------------------------------------------------------------------------
  group('profile', () {
    testWidgets('renders real identity, plan and counts', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('owner@example.com'), findsWidgets);
      // Real counts, from the summary provider — not literals in the widget.
      expect(find.byKey(const Key('profile_summary_strip')), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      // The plan block, on the free plan.
      expect(find.text('PawDoc Free'), findsWidgets);
      expect(find.byKey(const Key('account_subscription_tile')), findsOneWidget);
    });

    testWidgets('a Google identity shows the provider name and method',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        const ProfileScreen(),
        identity: _identity(provider: 'google', name: 'Sam Rivers'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sam Rivers'), findsOneWidget);
      expect(find.text('Google'), findsWidgets);
    });

    testWidgets('an unreadable summary renders dashes, never zeroes',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const ProfileScreen(), summaryFails: true));
      await tester.pumpAndSettle();

      // "0 Health Records" asserts the account is empty. It may simply not have
      // been readable, and a user with 48 records cannot tell those apart.
      expect(find.text('—'), findsNWidgets(5));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('signed out renders a state, not a crash or a blank',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const ProfileScreen(), signedOut: true));
      await tester.pumpAndSettle();

      expect(find.text('You are signed out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (label, destination) in <(String, Type)>[
      ('Account & plan', AccountManagementScreen),
      ('Notifications', NotificationsSettingsScreen),
      ('Privacy & security', PrivacySecurityScreen),
      ('AI transparency', AiTransparencyScreen),
    ]) {
      testWidgets('the "$label" shortcut opens $destination', (tester) async {
        _surface(tester);
        await tester.pumpWidget(_app(const ProfileScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(destination), findsOneWidget,
            reason: '"$label" must open $destination');
      });
    }
  });

  // -------------------------------------------------------------------------
  group('account management', () {
    testWidgets('an email account is offered a password reset', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const AccountManagementScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account_change_password')), findsOneWidget);
      expect(find.byKey(const Key('account_no_password')), findsNothing);
    });

    testWidgets('a Google account is NOT offered a password reset',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        const AccountManagementScreen(),
        identity: _identity(provider: 'google'),
      ));
      await tester.pumpAndSettle();

      // There is no PawDoc password on a federated identity — offering to
      // reset one would send a link that cannot work.
      expect(find.byKey(const Key('account_change_password')), findsNothing);
      expect(find.byKey(const Key('account_no_password')), findsOneWidget);
    });

    testWidgets('a guest session is told its records are unanchored',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        const AccountManagementScreen(),
        identity: _identity(email: '', provider: 'anonymous', anonymous: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Guest — no email'), findsWidgets);
      expect(find.byKey(const Key('account_change_password')), findsNothing);
    });

    testWidgets('the two irreversible actions are both present and confirm',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const AccountManagementScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account_sign_out')), findsOneWidget);
      expect(find.byKey(const Key('account_delete')), findsOneWidget);

      // Sign out is behind a confirm, not a bare tap.
      await tester.tap(find.byKey(const Key('account_sign_out')));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('sign out everywhere warns that it covers this device too',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const AccountManagementScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('account_sign_out_everywhere')));
      await tester.pumpAndSettle();
      expect(find.text('Sign out on all devices?'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.textContaining('including this one')),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('an unreadable store never prints a renewal date',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        const AccountManagementScreen(),
        premium: true,
        // Exactly the dev/test case: no RevenueCat key, so the SDK is never
        // configured and the snapshot is unreadable.
        snapshot: SubscriptionSnapshot.unreadable,
      ));
      await tester.pumpAndSettle();

      final text = _renderedText(tester).join(' | ');
      expect(text, contains('Premium'));
      expect(RegExp(r'Renews \w{3} \d').hasMatch(text), isFalse,
          reason: 'a renewal date may only come from a readable store answer');
    });

    testWidgets('a readable store renewal date is shown as read',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        const AccountManagementScreen(),
        premium: true,
        snapshot: SubscriptionSnapshot(
          readable: true,
          active: true,
          willRenew: true,
          renewsAt: DateTime.utc(2027, 5, 24),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('May 24, 2027'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  group('privacy & security', () {
    testWidgets('the analytics consent toggle is the real one', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PrivacySecurityScreen()));
      await tester.pumpAndSettle();

      // Same key as the screen this replaces: consent is a legal basis, and
      // the control that carries it must not be quietly renamed.
      final toggle = find.byKey(const Key('analytics_consent_toggle'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<Switch>(toggle).value, isFalse,
          reason: 'analytics are off until an affirmative act');
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
    });

    // Two tests, not one with two pumps: re-pumping the same widget type with
    // different overrides reuses the element, and an autoDispose FutureProvider
    // that has already resolved keeps its value.
    testWidgets('community presence: not joined', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PrivacySecurityScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Not joined'), findsOneWidget);
    });

    testWidgets('community presence: joined and discoverable', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        const PrivacySecurityScreen(),
        community: const CommunityProfile(
            userId: 'u-1', displayName: 'Sam', isDiscoverable: true),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Discoverable'), findsOneWidget);
    });

    testWidgets('unsupported security controls are inert and say so',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PrivacySecurityScreen()));
      await tester.pumpAndSettle();

      for (final key in const [
        Key('privacy_2fa'),
        Key('privacy_biometric'),
        Key('privacy_login_alerts'),
      ]) {
        expect(find.byKey(key), findsOneWidget);
        // The row exists so a user can find out the status — and carries no
        // switch and no tap handler, because there is nothing behind it.
        expect(find.descendant(of: find.byKey(key), matching: find.byType(Switch)),
            findsNothing);
        expect(find.descendant(of: find.byKey(key), matching: find.byType(InkWell)),
            findsNothing);
      }
    });

    testWidgets('export and delete are both reachable', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const PrivacySecurityScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy_export_row')), findsOneWidget);
      expect(find.byKey(const Key('privacy_rights_row')), findsOneWidget);
      expect(find.byKey(const Key('account_delete')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('notifications', () {
    testWidgets('granted: the master control states the permission',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notifications_permission_granted')),
          findsOneWidget);
    });

    testWidgets('denied: the master control becomes an action, not a switch',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(
          _app(const NotificationsSettingsScreen(), permission: false));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('notifications_permission_row')), findsOneWidget);
      expect(find.text('Notifications are turned off'), findsOneWidget);
    });

    testWidgets('the two real categories are switches; nothing else is',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notify_health_reminders')), findsOneWidget);
      expect(find.byKey(const Key('notify_walk_reminder')), findsOneWidget);
      // Exactly two switches on the whole page: every other reference category
      // describes a message nothing in the stack can send.
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('the walk hour row is absent while the nudge is off',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notify_walk_hour')), findsNothing);
    });

    testWidgets('the walk hour row appears, with the chosen hour, when on',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        const NotificationsSettingsScreen(),
        notifications: const NotificationSettings(
            healthReminders: true, walkReminder: true, walkHour: 19),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notify_walk_hour')), findsOneWidget);
      expect(find.text('19:00'), findsWidgets);
    });

    testWidgets('the preview is the user\'s own next reminder', (tester) async {
      _surface(tester);
      final due = DateTime.now().add(const Duration(days: 3));
      await tester.pumpWidget(_app(
        const NotificationsSettingsScreen(),
        reminders: [
          Reminder(
              id: 'r2',
              petId: 'p1',
              reminderType: 'Deworming',
              dueDate: due.add(const Duration(days: 10))),
          Reminder(
              id: 'r1', petId: 'p1', reminderType: 'Rabies', dueDate: due),
        ],
      ));
      await tester.pumpAndSettle();

      // The soonest one, not the first in the list.
      expect(find.byKey(const Key('notifications_next_reminder')),
          findsOneWidget);
      expect(find.text('Rabies'), findsOneWidget);
      expect(find.text('Deworming'), findsNothing);
    });

    testWidgets('no reminders shows an empty state that offers to set one',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notifications_next_empty')), findsOneWidget);
    });

    testWidgets('an unreadable reminder list degrades to an offline state',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(
          _app(const NotificationsSettingsScreen(), remindersFail: true));
      await tester.pumpAndSettle();

      // hasError before isLoading, or Riverpod 3's retry keeps it spinning.
      expect(find.byKey(const Key('notifications_next_error')), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('ai transparency', () {
    testWidgets('the disclaimer and the model facts are present',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const AiTransparencyScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_transparency_disclaimer')), findsOneWidget);
      expect(
          find.text('PawDoc does not replace a veterinarian'), findsOneWidget);
      // Model IDs, never marketing names (CLAUDE.md).
      final text = _renderedText(tester).join(' | ');
      expect(text, contains('gemini-2.0-flash'));
      expect(text, contains('claude-sonnet-4-6'));
    });

    testWidgets('the emergency-first step and the emergency route both exist',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const AiTransparencyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Emergency words are checked first'), findsOneWidget);
      expect(find.byKey(const Key('ai_transparency_emergency')), findsOneWidget);
    });

    testWidgets('the absent claims are stated as absent', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(const AiTransparencyScreen()));
      await tester.pumpAndSettle();

      final text = _renderedText(tester).join(' | ');
      expect(text, contains('No veterinarian reviews these results'));
      expect(text, contains('not a medical device'));
      // The encryption row states what is true (the service can read an image
      // it has to analyse) without quoting the marketing phrase it rejects —
      // the claim scan reads what a user reads, and a rendered string carries
      // no context.
      expect(text, contains('PawDoc can read what you upload'));
    });
  });

  // -------------------------------------------------------------------------
  // The claim scan. One pass over all five screens.
  // -------------------------------------------------------------------------
  group('product truth', () {
    /// Phrases from the five references that must never render.
    ///
    /// Each is quoted from the plate it appears on. Together they are the
    /// eighteen capabilities and six claims this batch refused to fake.
    const forbidden = <String, String>{
      // ai_transparency — the most dangerous claims in the whole set.
      'vet-verified': 'ai_transparency: "Advanced AI, Vet-Verified"',
      'vet-reviewed': 'ai_transparency: step 3 "Vet-Reviewed"',
      'reviewed by veterinary professionals':
          'ai_transparency: the hero sub-claim',
      'veterinary experts review':
          'ai_transparency: "Veterinary experts review and validate"',
      'vet knowledge base': 'ai_transparency: an invented curated corpus',
      'never used to train': 'ai_transparency: not ours to promise',
      // privacy_security + ai_transparency.
      'end-to-end encryption': 'privacy_security hero chip — PawDoc is not E2E',
      'end-to-end encrypted': 'the same claim, adjectival',
      'we never sell your data': 'privacy_security: a slogan, not a mechanism',
      'no data selling': 'ai_transparency badge',
      'industry-leading security': 'profile + account_management band',
      'secure cloud infrastructure': 'privacy_security hero chip',
      'data residency': 'privacy_security: there is no per-user region',
      'stored securely in your region': 'the same claim, spelled out',
      'we comply with gdpr': 'privacy_security: a lawyer\'s statement',
      'kvkk': 'privacy_security compliance tile',
      'we retain data only as long as necessary':
          'privacy_security: no retention job exists',
      'third-party access': 'privacy_security: nothing to revoke here',
      'profile visibility': 'privacy_security: no audience model exists',
      'data sharing': 'privacy_security: no sharing switchboard exists',
      // account_management.
      'billing history': 'account_management: no invoice exists',
      'payment method': 'account_management: "Visa •••• 4242"',
      'manage devices': 'account_management: "3 Active"',
      'active sessions': 'privacy_security: the same invented count',
      'pause your premium subscription': 'account_management: not implemented',
      'security center': 'account_management: no such product',
      // notifications.
      'health alerts': 'notifications: nothing watches a pet in the background',
      'quiet hours are': 'notifications: not implemented',
      'promotions & offers': 'notifications: PawDoc sends no marketing',
      'tips & education': 'notifications: nothing sends these',
      // profile.
      'pet parent': 'profile: an invented "I am a…" role',
      'verified': 'profile: the blue tick beside the owner\'s name',
    };

    for (final entry in <(String, Widget)>[
      ('profile', const ProfileScreen()),
      ('account_management', const AccountManagementScreen()),
      ('privacy_security', const PrivacySecurityScreen()),
      ('notifications', const NotificationsSettingsScreen()),
      ('ai_transparency', const AiTransparencyScreen()),
    ]) {
      testWidgets('${entry.$1} renders no unsupported claim', (tester) async {
        _surface(tester);
        // Both plans: several of these claims would only appear to a
        // subscriber, and a premium-only overclaim is still an overclaim.
        for (final premium in [false, true]) {
          await tester.pumpWidget(_app(entry.$2, premium: premium));
          await tester.pumpAndSettle();

          final rendered = _renderedText(tester).join('   ').toLowerCase();
          forbidden.forEach((needle, source) {
            expect(rendered.contains(needle), isFalse,
                reason: 'premium=$premium — "$needle" reached the user.\n'
                    'Source: $source');
          });
        }
      });
    }

    testWidgets('no screen draws a switch it cannot honour', (tester) async {
      _surface(tester);
      for (final screen in <Widget>[
        const ProfileScreen(),
        const AccountManagementScreen(),
        const PrivacySecurityScreen(),
        const NotificationsSettingsScreen(),
        const AiTransparencyScreen(),
      ]) {
        await tester.pumpWidget(_app(screen));
        await tester.pumpAndSettle();
        for (final s in tester.widgetList<Switch>(find.byType(Switch))) {
          expect(s.onChanged, isNotNull,
              reason: '${screen.runtimeType} draws a disabled switch. A '
                  'control that cannot be changed belongs in an '
                  'AccountUnavailableRow, which explains itself.');
        }
      }
    });

    testWidgets('every unavailable row is inert and badged', (tester) async {
      _surface(tester);
      for (final screen in <Widget>[
        const AccountManagementScreen(),
        const PrivacySecurityScreen(),
        const NotificationsSettingsScreen(),
      ]) {
        await tester.pumpWidget(_app(screen));
        await tester.pumpAndSettle();
        final rows = find.byType(AccountUnavailableRow);
        expect(rows, findsWidgets,
            reason: '${screen.runtimeType} should name what it does not have');
        for (var i = 0; i < tester.widgetList(rows).length; i++) {
          expect(
              find.descendant(of: rows.at(i), matching: find.byType(InkWell)),
              findsNothing);
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  group('accessibility', () {
    for (final entry in <(String, Widget)>[
      ('profile', const ProfileScreen()),
      ('account_management', const AccountManagementScreen()),
      ('privacy_security', const PrivacySecurityScreen()),
      ('notifications', const NotificationsSettingsScreen()),
      ('ai_transparency', const AiTransparencyScreen()),
    ]) {
      testWidgets('${entry.$1} lays out at 1.3x text scale', (tester) async {
        // Everything is drawn at the em-square test font already; 1.3x on top
        // of that is a harder case than any real handset. An overflow here is
        // a real defect, not a test artefact.
        _surface(tester, height: 6400);
        await tester.pumpWidget(
          ProviderScope(
            overrides: (_app(entry.$2) as ProviderScope).overrides.toList(),
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: entry.$2,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

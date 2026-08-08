// Mockup `nearby_pet_owners`.
//
// The reference plots five members on a street map at 0.2–0.6 miles from a
// "You" pin, with named parks around them, and stamps each row "Active now" /
// "Active 10m ago". PawDoc stores no coordinates for a member — only a
// five-character geohash cell about 4.9 km across — and no presence at all.
//
// These tests are the tripwire for that: no decimal distance, no imperial
// pin-precision, no presence, no fabricated tally.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/community/community_models.dart';
import 'package:pawdoc/src/community/community_sections.dart';
import 'package:pawdoc/src/community/nearby_screen.dart';

import 'support/fake_community.dart';

const _me = CommunityProfile(
  userId: 'me',
  displayName: 'Me',
  geohash: 'u33dc',
  speciesTags: ['dog'],
);

const _anna = CommunityProfile(
  userId: 'anna',
  displayName: 'Anna Yilmaz',
  bio: 'Early-morning walker, always up for park meetups.',
  geohash: 'u33dc',
  speciesTags: ['dog'],
);

const _bob = CommunityProfile(
  userId: 'bob',
  displayName: 'Bob',
  geohash: 'u33dd',
  speciesTags: ['cat'],
);

const _cara = CommunityProfile(
  userId: 'cara',
  displayName: 'Cara Diaz',
  geohash: 'u33de',
  speciesTags: ['rabbit'],
  allowRequests: false,
);

void _surface(WidgetTester tester, {double height = 3000}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

String _pageText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .toLowerCase();

void main() {
  group('pure filtering', () {
    test('initials cope with one word, two words, and nothing', () {
      expect(communityInitials('Anna Yilmaz'), 'AY');
      expect(communityInitials('Bob'), 'BO');
      expect(communityInitials('X'), 'X');
      expect(communityInitials('   '), '?');
      expect(communityInitials('Anna Maria Yilmaz'), 'AY');
    });

    test('the species rail buckets by tag, and Other is everything else', () {
      expect(SpeciesFilter.dogs.matches(_anna), isTrue);
      expect(SpeciesFilter.dogs.matches(_bob), isFalse);
      expect(SpeciesFilter.cats.matches(_bob), isTrue);
      expect(SpeciesFilter.other.matches(_cara), isTrue);
      expect(SpeciesFilter.other.matches(_anna), isFalse);
      expect(SpeciesFilter.all.matches(_cara), isTrue);
    });

    test('search covers the fields a profile really has', () {
      const book = [_anna, _bob, _cara];
      expect(searchProfiles(book, 'anna').single.userId, 'anna');
      // The bio, not just the name.
      expect(searchProfiles(book, 'park').single.userId, 'anna');
      // The species word, which is rendered but not stored as text.
      expect(searchProfiles(book, 'rabbit').single.userId, 'cara');
      expect(searchProfiles(book, 'zebra'), isEmpty);
      expect(searchProfiles(book, '  ').length, 3);
    });

    test('distance ordering uses cells, and unknowns sort last', () {
      const stranger = CommunityProfile(userId: 'x', displayName: 'Aaa');
      final out = filterPeople(
        const [_cara, stranger, _bob, _anna],
        myCell: 'u33dc',
      );
      // Anna shares my cell, so she is nearest; the member with no cell at
      // all sorts last even though her name would put her first.
      expect(out.first.userId, 'anna');
      expect(out.last.userId, 'x');
    });

    test('name ordering is case-insensitive', () {
      final out = filterPeople(const [_bob, _anna],
          order: PeopleOrder.name, myCell: 'u33dc');
      expect(out.map((p) => p.userId).toList(), ['anna', 'bob']);
    });

    test('the tally counts the rows, it does not invent them', () {
      final t = speciesTally(const [_anna, _bob, _cara]);
      expect(t.people, 3);
      expect(t.dogs, 1);
      expect(t.cats, 1);
      expect(t.other, 1);
      final none = speciesTally(const []);
      expect(none.people, 0);
      expect(none.dogs, 0);
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block that has data behind it is present',
        (tester) async {
      _surface(tester);
      final repo =
          FakeCommunityRepo(profile: _me, nearby: const [_anna, _bob, _cara]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Pet Owners'), findsOneWidget);
      expect(find.byKey(const Key('nearby_search')), findsOneWidget);
      expect(find.byKey(const Key('nearby_species_rail')), findsOneWidget);
      expect(find.byKey(const Key('nearby_species_all')), findsOneWidget);
      // The map's slot, holding what the app really knows.
      expect(find.byKey(const Key('nearby_area_card')), findsOneWidget);
      expect(find.textContaining('u33dc'), findsOneWidget);
      expect(find.text('People near you'), findsOneWidget);
      for (final p in [_anna, _bob, _cara]) {
        expect(find.byKey(Key('nearby_person_${p.userId}')), findsOneWidget);
      }
      expect(find.byKey(const Key('community_tally')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the species rail narrows the list', (tester) async {
      _surface(tester);
      final repo =
          FakeCommunityRepo(profile: _me, nearby: const [_anna, _bob, _cara]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nearby_species_cats')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nearby_person_bob')), findsOneWidget);
      expect(find.byKey(const Key('nearby_person_anna')), findsNothing);

      // The tally still counts everyone discoverable, not the filtered view —
      // it is a statement about the area, not about the current filter.
      expect(find.byKey(const Key('community_tally')), findsOneWidget);
    });

    testWidgets('search narrows, and a miss says so', (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(profile: _me, nearby: const [_anna, _bob]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('nearby_search')), 'anna');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nearby_person_anna')), findsOneWidget);
      expect(find.byKey(const Key('nearby_person_bob')), findsNothing);

      await tester.enterText(find.byKey(const Key('nearby_search')), 'zebra');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nearby_no_match')), findsOneWidget);
    });

    testWidgets('Connect goes through the repository', (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(profile: _me, nearby: const [_anna]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nearby_connect_anna')));
      await tester.pumpAndSettle();
      expect(repo.requested, contains('anna'));
    });

    testWidgets('a member who is not taking requests says so, disabled',
        (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(profile: _me, nearby: const [_cara]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nearby_closed_cara')), findsOneWidget);
      expect(find.byKey(const Key('nearby_connect_cara')), findsNothing);
      await tester.tap(find.byKey(const Key('nearby_closed_cara')));
      await tester.pumpAndSettle();
      expect(repo.requested, isEmpty);
    });

    testWidgets('an accepted connection offers Message, not Connect',
        (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(
        profile: _me,
        nearby: const [_anna],
        connectionList: const [
          CommunityConnection(
              id: 'c1',
              requesterId: 'me',
              addresseeId: 'anna',
              status: ConnectionStatus.accepted),
        ],
      );
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nearby_message_anna')), findsOneWidget);
      expect(find.byKey(const Key('nearby_connect_anna')), findsNothing);
    });

    testWidgets('a pending request is shown as sent, not offered again',
        (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(
        profile: _me,
        nearby: const [_anna],
        connectionList: const [
          CommunityConnection(
              id: 'c1',
              requesterId: 'me',
              addresseeId: 'anna',
              status: ConnectionStatus.pending),
        ],
      );
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nearby_pending_anna')), findsOneWidget);
      expect(find.text('Request sent'), findsOneWidget);
    });
  });

  group('states with nothing to show', () {
    testWidgets('a non-member is told joining is what creates the profile',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(
          communityApp(const NearbyPetOwnersScreen(), FakeCommunityRepo()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nearby_not_member')), findsOneWidget);
    });

    testWidgets('a member with no area is told why the list is empty',
        (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(
          profile: const CommunityProfile(userId: 'me', displayName: 'Me'));
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nearby_no_area')), findsOneWidget);
    });

    testWidgets('an empty area reads as early, not as broken', (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nearby_empty')), findsOneWidget);
      // The tally is drawn at zero rather than hidden — nought is an answer.
      expect(find.byKey(const Key('community_tally')), findsOneWidget);
    });
  });

  group('privacy', () {
    testWidgets('no coordinate, no decimal distance, no imperial precision',
        (tester) async {
      _surface(tester);
      final repo =
          FakeCommunityRepo(profile: _me, nearby: const [_anna, _bob, _cara]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      // The reference's "0.2 mi away". Distances are cell-to-cell and coarse.
      expect(RegExp(r'\d+\.\d+\s*(mi|km)').hasMatch(text), isFalse,
          reason: 'a decimal distance implies a precision PawDoc does not have');
      expect(text.contains(' mi away'), isFalse);
      // Presence is not stored, so it is never implied.
      expect(text.contains('active now'), isFalse);
      expect(text.contains('active 1'), isFalse);
      expect(text.contains('online'), isFalse);
      expect(text.contains('last seen'), isFalse);
      // The honest label survives.
      expect(text.contains('very close by'), isTrue);
    });

    testWidgets('the screen states what members can see', (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(profile: _me, nearby: const [_anna]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nearby_privacy_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('never your address'), findsOneWidget);
      expect(find.textContaining('area code'), findsWidgets);
    });

    testWidgets('no pet health data leaks onto a social surface',
        (tester) async {
      _surface(tester);
      final repo =
          FakeCommunityRepo(profile: _me, nearby: const [_anna, _bob, _cara]);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      for (final word in [
        'health score',
        'symptom',
        'diagnos',
        'vaccinat',
        'medication',
        'weight',
      ]) {
        expect(text.contains(word), isFalse,
            reason: '"$word" is health data on a community surface');
      }
    });
  });

  group('failure', () {
    testWidgets('a failed lookup is an error, never "nobody is here"',
        (tester) async {
      _surface(tester);
      final repo = FakeCommunityRepo(profile: _me, throwOnDiscover: true);
      await tester.pumpWidget(communityApp(const NearbyPetOwnersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nearby_error')), findsOneWidget);
      // The bug this pins: reading `snapshot.data ?? const []` rendered a
      // failed lookup as an empty community, telling the owner "you are early"
      // when the truth was "we could not ask".
      expect(find.byKey(const Key('nearby_empty')), findsNothing);
      // And the page is still a page, not a spinner.
      expect(find.byKey(const Key('nearby_area_card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

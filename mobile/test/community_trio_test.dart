// Mockups `community_feed`, `community_post_detail` and `create_post`.
//
// The references draw a social network: posts with photo carousels and video,
// "128" reactions, "23 Comments · 7 Shares · 1 Save", follows, hashtags,
// polls, stories, interest groups with "12.4K members", a verified
// veterinarian answering a health question in-feed, and a "Top Contributor"
// badge.
//
// The schema is five tables — profiles, connections, messages, walk proposals,
// reports. No posts, no reactions, no follows, no groups, no media, no
// verification of anybody.
//
// These tests pin the two halves of that: the composition carries the *real*
// graph and counts real rows, and none of the invented social furniture — most
// of all the verified-vet badge — can reach a screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/community/community_chat_screen.dart';
import 'package:pawdoc/src/community/community_home_screen.dart';
import 'package:pawdoc/src/community/community_models.dart';
import 'package:pawdoc/src/community/create_post_screen.dart';

import 'support/fake_community.dart';

const _me = CommunityProfile(
  userId: 'me',
  displayName: 'Emre K',
  bio: 'Morning walks, mostly.',
  geohash: 'u33dc',
  speciesTags: ['dog'],
);

const _anna = CommunityProfile(
  userId: 'anna',
  displayName: 'Anna Yilmaz',
  bio: 'Early-morning walker.',
  geohash: 'u33dc',
  speciesTags: ['dog'],
);

const _bob = CommunityProfile(userId: 'bob', displayName: 'Bob');
const _cara = CommunityProfile(
    userId: 'cara', displayName: 'Cara', geohash: 'u33dc', speciesTags: ['cat']);

const _incoming = CommunityConnection(
    id: 'c-in',
    requesterId: 'anna',
    addresseeId: 'me',
    status: ConnectionStatus.pending);

const _accepted = CommunityConnection(
    id: 'c-ok',
    requesterId: 'me',
    addresseeId: 'bob',
    status: ConnectionStatus.accepted);

String _pageText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .toLowerCase();

FakeCommunityRepo _fullRepo() => FakeCommunityRepo(
      profile: _me,
      connectionList: const [_incoming, _accepted],
      others: const {'anna': _anna, 'bob': _bob},
      nearby: const [_cara],
    );

void main() {
  group('community_feed', () {
    testWidgets('every block that has a table behind it is present',
        (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(
          communityApp(const CommunityHomeScreen(), _fullRepo()));
      await tester.pumpAndSettle();

      expect(find.text('Community'), findsOneWidget);
      expect(find.byKey(const Key('community_segments')), findsOneWidget);
      expect(find.byKey(const Key('community_composer')), findsOneWidget);
      expect(find.byKey(const Key('community_fab')), findsOneWidget);
      expect(find.byKey(const Key('community_bell')), findsOneWidget);
      // The three real card kinds.
      expect(find.byKey(const Key('community_request_c-in')), findsOneWidget);
      expect(find.byKey(const Key('community_connection_c-ok')), findsOneWidget);
      expect(find.byKey(const Key('community_nearby_cara')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the bell badge counts real incoming requests', (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(
          communityApp(const CommunityHomeScreen(), _fullRepo()));
      await tester.pumpAndSettle();

      // One pending request in the fixture → "1", not the reference's "3".
      expect(find.byKey(const Key('community_bell_badge')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('community_bell_badge')),
              matching: find.text('1')),
          findsOneWidget);
    });

    testWidgets('no badge at all when nobody is waiting', (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CommunityHomeScreen(), repo));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community_bell_badge')), findsNothing);
    });

    testWidgets('the segment rail narrows to one relationship', (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(
          communityApp(const CommunityHomeScreen(), _fullRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community_segment_requests')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community_request_c-in')), findsOneWidget);
      expect(find.byKey(const Key('community_connection_c-ok')), findsNothing);
      expect(find.byKey(const Key('community_nearby_cara')), findsNothing);

      await tester.tap(find.byKey(const Key('community_segment_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community_connection_c-ok')), findsOneWidget);
    });

    testWidgets('accepting and declining go through the repository',
        (tester) async {
      communitySurface(tester);
      final repo = _fullRepo();
      await tester.pumpWidget(communityApp(const CommunityHomeScreen(), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community_accept_c-in')));
      await tester.pumpAndSettle();
      expect(repo.responded, contains(('c-in', ConnectionStatus.accepted)));
    });

    testWidgets('a member already connected is not offered again in Nearby',
        (tester) async {
      communitySurface(tester);
      // Anna is already an incoming request, so she must not also appear as a
      // stranger to connect with.
      final repo = FakeCommunityRepo(
        profile: _me,
        connectionList: const [_incoming],
        others: const {'anna': _anna},
        nearby: const [_anna, _cara],
      );
      await tester.pumpWidget(communityApp(const CommunityHomeScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community_nearby_anna')), findsNothing);
      expect(find.byKey(const Key('community_nearby_cara')), findsOneWidget);
    });

    testWidgets('a failed load says so rather than showing an empty community',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me, throwOnDiscover: true);
      await tester.pumpWidget(communityApp(const CommunityHomeScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community_nearby_error')), findsOneWidget);
      expect(find.byKey(const Key('community_nearby_empty')), findsNothing);
    });

    testWidgets('the post control keeps its place and says Soon',
        (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(
          communityApp(const CommunityHomeScreen(), _fullRepo()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community_soon_post')), findsOneWidget);
      await tester.tap(find.byKey(const Key('community_soon_post')));
      await tester.pumpAndSettle();
      expect(find.textContaining('no posts table'), findsOneWidget);
    });
  });

  group('community_post_detail', () {
    const connection = CommunityConnection(
        id: 'c1',
        requesterId: 'me',
        addresseeId: 'anna',
        status: ConnectionStatus.accepted);

    Widget detail(FakeCommunityRepo repo) => communityApp(
          const CommunityChatScreen(
              connection: connection, otherProfile: _anna),
          repo,
        );

    testWidgets('the member card, the walk strip and the thread are present',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(
        messageList: [
          CommunityMessage(
              id: 'm1',
              connectionId: 'c1',
              senderId: 'anna',
              content: 'Morning walk?',
              createdAt: DateTime(2026, 7, 24, 9)),
        ],
        proposalList: [
          WalkProposal(
              id: 'w1',
              connectionId: 'c1',
              proposerId: 'anna',
              placeName: 'Stadtpark',
              proposedAt: DateTime(2026, 7, 25, 10),
              createdAt: DateTime(2026, 7, 24, 9, 5)),
        ],
      );
      await tester.pumpWidget(detail(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community_member_card')), findsOneWidget);
      // The header names who you are talking to; the card names them again as
      // the reference's author block does.
      expect(
          find.descendant(
              of: find.byKey(const Key('community_member_card')),
              matching: find.text('Anna Yilmaz')),
          findsOneWidget);
      // The reference's details strip, carrying the real proposal.
      expect(find.byKey(const Key('community_walk_strip')), findsOneWidget);
      expect(find.textContaining('Stadtpark'), findsWidgets);
      expect(find.text('Morning walk?'), findsOneWidget);
      expect(find.byKey(const Key('community_chat_input')), findsOneWidget);
      expect(find.byKey(const Key('community_chat_send')), findsOneWidget);
    });

    testWidgets('no proposal means no strip, not an empty one', (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(detail(FakeCommunityRepo()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community_walk_strip')), findsNothing);
      expect(find.byKey(const Key('community_chat_empty')), findsOneWidget);
    });

    testWidgets('proposing a walk writes a real proposal', (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo();
      await tester.pumpWidget(detail(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community_propose_walk')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('walk_place_field')), 'Stadtpark main gate');
      await tester.tap(find.byKey(const Key('walk_propose_submit')));
      await tester.pumpAndSettle();

      expect(repo.proposals_.single.placeName, 'Stadtpark main gate');
    });

    testWidgets('a walk proposal is a message, and the sheet says so',
        (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(detail(FakeCommunityRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community_propose_walk')));
      await tester.pumpAndSettle();
      expect(find.textContaining('nothing is tracked'), findsOneWidget);
      expect(find.textContaining('no location leaves'), findsOneWidget);
    });
  });

  group('create_post', () {
    testWidgets('the composer loads the profile it is going to overwrite',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CreatePostScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Emre K'), findsOneWidget);
      expect(find.text('Morning walks, mostly.'), findsOneWidget);
      expect(find.textContaining('u33dc'), findsOneWidget);
      expect(find.byKey(const Key('community_guidelines')), findsOneWidget);
    });

    testWidgets('a too-short name blocks the save and says why',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CreatePostScreen(), repo));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('community_name_field')), 'A');
      await tester.tap(find.byKey(const Key('community_join_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community_join_error')), findsOneWidget);
      expect(repo.saved, isNull);
    });

    testWidgets('saving writes every field through the repository',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CreatePostScreen(), repo));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('community_name_field')), 'Emre and Buddy');
      await tester.enterText(
          find.byKey(const Key('community_bio_field')), 'Park regulars.');
      await tester.tap(find.byKey(const Key('community_species_cat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community_join_button')));
      await tester.pumpAndSettle();

      expect(repo.saved, isNotNull);
      expect(repo.saved!.displayName, 'Emre and Buddy');
      expect(repo.saved!.bio, 'Park regulars.');
      expect(repo.saved!.speciesTags, containsAll(['dog', 'cat']));
      expect(repo.saved!.geohash, 'u33dc',
          reason: 'editing must not silently drop the area');
    });

    testWidgets('removing the area clears it, and the save carries the removal',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CreatePostScreen(), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community_area_clear')));
      await tester.pumpAndSettle();
      expect(find.text('No area set'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community_join_button')));
      await tester.pumpAndSettle();
      expect(repo.saved!.geohash, isNull);
    });

    testWidgets('the species chips sit side by side, not one per line',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CreatePostScreen(), repo));
      await tester.pumpAndSettle();

      // A `Container` given an `alignment` expands to its incoming
      // constraints, and inside a `Wrap` those are loose to the whole row — so
      // every chip rendered full width, stacked. Two chips on one line is the
      // tripwire.
      final dog = tester.getTopLeft(find.byKey(const Key('community_species_dog')));
      final cat = tester.getTopLeft(find.byKey(const Key('community_species_cat')));
      expect(cat.dy, dog.dy, reason: 'the first two chips share a line');
      expect(cat.dx, greaterThan(dog.dx));
      expect(tester.getSize(find.byKey(const Key('community_species_dog'))).width,
          lessThan(200),
          reason: 'a chip that fills the row is the bug this pins');
    });

    testWidgets('every control the schema cannot hold says Soon',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CreatePostScreen(), repo));
      await tester.pumpAndSettle();

      for (final key in [
        'create_post_soon_media',
        'create_post_soon_poll',
        'create_post_soon_ask',
        'create_post_soon_tags',
        'create_post_soon_mood',
        'create_post_soon_groups',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: '$key is missing');
      }
      // And tapping one explains rather than doing nothing.
      await tester.tap(find.byKey(const Key('create_post_soon_groups')));
      await tester.pumpAndSettle();
      expect(find.textContaining('12.4K members'), findsOneWidget);
    });
  });

  group('safety and product truth', () {
    testWidgets('no invented social metric reaches the feed', (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(
          communityApp(const CommunityHomeScreen(), _fullRepo()));
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      for (final word in [
        'likes',
        'shares',
        'comments •',
        'top contributor',
        'trending',
        'verified',
        'veterinarian',
        'followers',
      ]) {
        expect(text.contains(word), isFalse,
            reason: '"$word" is social furniture with no table behind it');
      }
    });

    testWidgets('nobody is badged as a professional, anywhere', (tester) async {
      communitySurface(tester);
      const connection = CommunityConnection(
          id: 'c1',
          requesterId: 'me',
          addresseeId: 'anna',
          status: ConnectionStatus.accepted);
      await tester.pumpWidget(communityApp(
        const CommunityChatScreen(
            connection: connection, otherProfile: _anna),
        FakeCommunityRepo(),
      ));
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      // A verified-vet badge inside a triage app borrows PawDoc's authority
      // for advice PawDoc did not write. It is the reference's most dangerous
      // element and it never ships.
      expect(text.contains('verified'), isFalse);
      expect(text.contains('vet dr'), isFalse);
      expect(text.contains('veterinarian'), isFalse);
      expect(text.contains('top contributor'), isFalse);
      expect(text.contains('expert'), isFalse);
    });

    testWidgets('no health surface bleeds into the community', (tester) async {
      communitySurface(tester);
      await tester.pumpWidget(
          communityApp(const CommunityHomeScreen(), _fullRepo()));
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      for (final word in [
        'health score',
        'symptom',
        'diagnos',
        'triage',
        'medication',
      ]) {
        expect(text.contains(word), isFalse,
            reason: '"$word" is health data on a social surface');
      }
    });

    testWidgets('the composer never invents a place, only an area code',
        (tester) async {
      communitySurface(tester);
      final repo = FakeCommunityRepo(profile: _me);
      await tester.pumpWidget(communityApp(const CreatePostScreen(), repo));
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      expect(text.contains('istanbul'), isFalse);
      expect(text.contains('lake'), isFalse);
      expect(text.contains('area code'), isTrue);
      expect(text.contains('no address, no coordinates, no place name'), isTrue);
    });
  });
}

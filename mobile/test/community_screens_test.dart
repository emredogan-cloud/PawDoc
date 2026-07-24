// Next Evolution Phase 6 — community UI over a fake repository (no network,
// no Supabase, no geolocator).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:pawdoc/src/community/community_card.dart';
import 'package:pawdoc/src/community/community_chat_screen.dart';
import 'package:pawdoc/src/community/community_home_screen.dart';
import 'package:pawdoc/src/community/community_models.dart';
import 'package:pawdoc/src/community/community_onboarding_screen.dart';
import 'package:pawdoc/src/community/community_repository.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/walks/location_service.dart';

class _FakeLocation extends LocationService {
  const _FakeLocation();
  @override
  Future<LocationResult> current() async => const LocationDenied();
}

class _FakeRepo implements CommunityRepository {
  _FakeRepo({
    this.profile,
    this.nearby = const [],
    this.connectionList = const [],
    this.messageList = const [],
    this.proposalList = const [],
    this.others = const {},
  });

  CommunityProfile? profile;
  List<CommunityProfile> nearby;
  List<CommunityConnection> connectionList;
  List<CommunityMessage> messageList;
  List<WalkProposal> proposalList;
  Map<String, CommunityProfile> others;

  CommunityProfile? saved;
  final sentMessages = <String>[];
  final responded = <(String, ConnectionStatus)>[];
  final requested = <String>[];
  final reports = <String>[];
  final proposalResponses = <(String, ProposalStatus)>[];
  bool left = false;

  @override
  Future<CommunityProfile?> myProfile() async => profile;
  @override
  Future<void> saveProfile(CommunityProfile p) async => saved = p;
  @override
  Future<void> leaveCommunity() async => left = true;
  @override
  Future<List<CommunityProfile>> discover(List<String> cells) async => nearby;
  @override
  Future<Map<String, CommunityProfile>> profilesById(List<String> ids) async =>
      {for (final id in ids) if (others[id] != null) id: others[id]!};
  @override
  Future<List<CommunityConnection>> connections() async => connectionList;
  @override
  Future<void> sendRequest(String addresseeId) async =>
      requested.add(addresseeId);
  @override
  Future<void> respond(String connectionId, ConnectionStatus status) async =>
      responded.add((connectionId, status));
  @override
  Future<void> removeConnection(String connectionId) async {}
  @override
  Future<List<CommunityMessage>> messages(String connectionId) async =>
      messageList;
  @override
  Stream<List<CommunityMessage>> messagesStream(String connectionId) =>
      Stream.value(messageList);
  @override
  Future<void> sendMessage(String connectionId, String content) async =>
      sentMessages.add(content);
  @override
  Future<List<WalkProposal>> proposals(String connectionId) async =>
      proposalList;
  @override
  Future<void> propose(WalkProposal proposal) async {}
  @override
  Future<void> respondProposal(String proposalId, ProposalStatus status) async =>
      proposalResponses.add((proposalId, status));
  @override
  Future<void> report({
    required String reportedUserId,
    required String reason,
    String? details,
    String? connectionId,
  }) async =>
      reports.add(reason);
}

Widget _app(Widget home, _FakeRepo repo) {
  return ProviderScope(
    overrides: [
      communityRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('me'),
      locationServiceProvider.overrideWithValue(const _FakeLocation()),
      petsListProvider.overrideWith((ref) async =>
          const [Pet(id: 'p1', userId: 'me', name: 'Rex', species: 'dog')]),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('onboarding states the consent terms and validates the name',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(const CommunityOnboardingScreen(), repo));
    await tester.pumpAndSettle();

    // The consent card is explicit about the coarse-area contract.
    expect(find.textContaining('~2 km'), findsWidgets);
    expect(find.textContaining('never your'), findsOneWidget);
    expect(find.textContaining('no pet health data'), findsOneWidget);

    // Short name blocks joining.
    await tester.enterText(
        find.byKey(const Key('community_name_field')), 'A');
    await tester.scrollUntilVisible(
        find.byKey(const Key('community_join_button')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('community_join_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_join_error')), findsOneWidget);
    expect(repo.saved, isNull);
  });

  testWidgets('joining saves the profile (location denied → no geohash)',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(const CommunityOnboardingScreen(), repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('community_name_field')), "Rex's human");
    await tester.scrollUntilVisible(
        find.byKey(const Key('community_join_button')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('community_join_button')));
    await tester.pumpAndSettle();

    expect(repo.saved, isNotNull);
    expect(repo.saved!.displayName, "Rex's human");
    expect(repo.saved!.geohash, isNull,
        reason: 'denied location joins without an area — never blocks joining');
    expect(repo.saved!.speciesTags, contains('dog'),
        reason: 'species suggested from the user\'s pets');
  });

  testWidgets('home card invites non-members and shortcuts members',
      (tester) async {
    await tester.pumpWidget(
        _app(const Scaffold(body: CommunityCard()), _FakeRepo()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_card_invite')), findsOneWidget);
    expect(find.textContaining('Opt-in only'), findsOneWidget);

    await tester.pumpWidget(_app(
        const Scaffold(body: CommunityCard()),
        _FakeRepo(
            profile: const CommunityProfile(
                userId: 'me', displayName: 'Me'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_card_member')), findsOneWidget);
  });

  testWidgets('community home partitions requests / connections / nearby',
      (tester) async {
    final repo = _FakeRepo(
      profile: const CommunityProfile(
          userId: 'me', displayName: 'Me', geohash: 'u33dc'),
      connectionList: const [
        CommunityConnection(
            id: 'c-in',
            requesterId: 'anna',
            addresseeId: 'me',
            status: ConnectionStatus.pending),
        CommunityConnection(
            id: 'c-ok',
            requesterId: 'me',
            addresseeId: 'bob',
            status: ConnectionStatus.accepted),
      ],
      others: const {
        'anna': CommunityProfile(userId: 'anna', displayName: 'Anna'),
        'bob': CommunityProfile(userId: 'bob', displayName: 'Bob'),
      },
      nearby: const [
        CommunityProfile(
            userId: 'cara',
            displayName: 'Cara',
            geohash: 'u33dc',
            speciesTags: ['cat']),
      ],
    );
    await tester.pumpWidget(_app(const CommunityHomeScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Requests for you'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Cara'), findsOneWidget);

    // Accepting the incoming request goes through the repository.
    await tester.tap(find.byKey(const Key('community_accept_c-in')));
    await tester.pumpAndSettle();
    expect(repo.responded, contains(('c-in', ConnectionStatus.accepted)));

    // Requesting a nearby member.
    await tester.tap(find.byKey(const Key('community_request_btn_cara')));
    await tester.pumpAndSettle();
    expect(repo.requested, contains('cara'));
  });

  testWidgets('chat renders the merged timeline and sends via the repo',
      (tester) async {
    final repo = _FakeRepo(
      messageList: [
        CommunityMessage(
            id: 'm1',
            connectionId: 'c1',
            senderId: 'them',
            content: 'Morning walk?',
            createdAt: DateTime(2026, 7, 24, 9)),
      ],
      proposalList: [
        WalkProposal(
            id: 'w1',
            connectionId: 'c1',
            proposerId: 'them',
            placeName: 'Stadtpark',
            proposedAt: DateTime(2026, 7, 25, 10),
            createdAt: DateTime(2026, 7, 24, 9, 5)),
      ],
    );
    const connection = CommunityConnection(
        id: 'c1',
        requesterId: 'me',
        addresseeId: 'them',
        status: ConnectionStatus.accepted);
    await tester.pumpWidget(_app(
        const CommunityChatScreen(
            connection: connection,
            otherProfile:
                CommunityProfile(userId: 'them', displayName: 'Anna')),
        repo));
    await tester.pumpAndSettle();

    expect(find.text('Morning walk?'), findsOneWidget);
    expect(find.textContaining('Walk at Stadtpark'), findsOneWidget);
    // Their proposal → I can answer it.
    expect(find.byKey(const Key('proposal_accept_w1')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('community_chat_input')), 'Yes! 9:30?');
    await tester.tap(find.byKey(const Key('community_chat_send')));
    await tester.pumpAndSettle();
    expect(repo.sentMessages, ['Yes! 9:30?']);

    // Accepting their proposal goes through the repository.
    await tester.tap(find.byKey(const Key('proposal_accept_w1')));
    await tester.pumpAndSettle();
    expect(repo.proposalResponses, contains(('w1', ProposalStatus.accepted)));
  });

  testWidgets('report & block surface exists in chat (Play UGC)',
      (tester) async {
    final repo = _FakeRepo();
    const connection = CommunityConnection(
        id: 'c1',
        requesterId: 'me',
        addresseeId: 'them',
        status: ConnectionStatus.accepted);
    await tester.pumpWidget(
        _app(const CommunityChatScreen(connection: connection), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('community_chat_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_report_action')), findsOneWidget);
    expect(find.byKey(const Key('community_block_action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('community_report_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_reason_harassment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_submit')));
    await tester.pumpAndSettle();
    expect(repo.reports, ['harassment']);
  });
}

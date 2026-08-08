// Next Evolution Phase 6 — community UI over a fake repository (no network,
// no Supabase, no geolocator).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/community/community_card.dart';
import 'package:pawdoc/src/community/community_chat_screen.dart';
import 'package:pawdoc/src/community/community_home_screen.dart';
import 'package:pawdoc/src/community/community_models.dart';
import 'package:pawdoc/src/community/community_onboarding_screen.dart';

import 'support/fake_community.dart';

void main() {
  testWidgets('onboarding states the consent terms and validates the name',
      (tester) async {
    final repo = FakeCommunityRepo();
    await tester.pumpWidget(communityApp(const CommunityOnboardingScreen(), repo));
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
    final repo = FakeCommunityRepo();
    await tester.pumpWidget(communityApp(const CommunityOnboardingScreen(), repo));
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
        communityApp(const Scaffold(body: CommunityCard()), FakeCommunityRepo()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_card_invite')), findsOneWidget);
    expect(find.textContaining('Opt-in only'), findsOneWidget);

    await tester.pumpWidget(communityApp(
        const Scaffold(body: CommunityCard()),
        FakeCommunityRepo(
            profile: const CommunityProfile(
                userId: 'me', displayName: 'Me'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_card_member')), findsOneWidget);
  });

  testWidgets('community home partitions requests / connections / nearby',
      (tester) async {
    final repo = FakeCommunityRepo(
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
    await tester.pumpWidget(communityApp(const CommunityHomeScreen(), repo));
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
    final repo = FakeCommunityRepo(
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
    await tester.pumpWidget(communityApp(
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
    final repo = FakeCommunityRepo();
    const connection = CommunityConnection(
        id: 'c1',
        requesterId: 'me',
        addresseeId: 'them',
        status: ConnectionStatus.accepted);
    await tester.pumpWidget(
        communityApp(const CommunityChatScreen(connection: connection), repo));
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

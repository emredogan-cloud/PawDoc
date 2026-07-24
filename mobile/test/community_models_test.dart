// Next Evolution Phase 6 — community pure logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/community/community_models.dart';
import 'package:pawdoc/src/core/geohash.dart';

void main() {
  test('profile json roundtrip keeps consent-relevant fields', () {
    final p = CommunityProfile.fromJson({
      'user_id': 'u1',
      'display_name': "Rex's human",
      'bio': 'Morning walker',
      'species_tags': ['dog', 'cat'],
      'geohash': 'u33dc',
      'is_discoverable': false,
      'allow_requests': true,
    });
    expect(p.isDiscoverable, isFalse);
    final cols = p.toColumns();
    expect(cols['geohash'], 'u33dc');
    expect(cols.containsKey('user_id'), isFalse,
        reason: 'user_id is injected by the repository');
  });

  group('connection helpers', () {
    final c = CommunityConnection.fromJson({
      'id': 'c1',
      'requester_id': 'them',
      'addressee_id': 'me',
      'status': 'pending',
    });

    test('direction helpers know incoming vs outgoing', () {
      expect(c.isIncomingFor('me'), isTrue);
      expect(c.isIncomingFor('them'), isFalse);
      expect(c.isOutgoingFor('them'), isTrue);
      expect(c.otherParty('me'), 'them');
      expect(c.involves('me'), isTrue);
      expect(c.involves('nobody'), isFalse);
    });

    test('unknown status parses as pending (never crashes the list)', () {
      expect(connectionStatusFrom('weird'), ConnectionStatus.pending);
      expect(connectionStatusFrom('blocked'), ConnectionStatus.blocked);
    });
  });

  group('approxDistanceLabel', () {
    test('same cell reads as very close, absent data reads as nothing', () {
      expect(approxDistanceLabel('u33dc', 'u33dc'), 'Very close by');
      expect(approxDistanceLabel(null, 'u33dc'), '');
      expect(approxDistanceLabel('u33dc', null), '');
    });

    test('neighboring cells give an honest ~km, never coordinates', () {
      final neighbors = [...geohashNeighbors('u33dc')]..remove('u33dc');
      final label = approxDistanceLabel('u33dc', neighbors.first);
      expect(label, anyOf(contains('km'), equals('Very close by')));
      expect(label, isNot(contains('.')));
    });
  });

  test('mergeTimeline interleaves messages and proposals by time', () {
    final t0 = DateTime(2026, 7, 24, 10);
    final items = mergeTimeline(
      [
        CommunityMessage(
            connectionId: 'c1', senderId: 'me', content: 'first',
            createdAt: t0),
        CommunityMessage(
            connectionId: 'c1', senderId: 'them', content: 'third',
            createdAt: t0.add(const Duration(minutes: 10))),
      ],
      [
        WalkProposal(
          connectionId: 'c1',
          proposerId: 'me',
          placeName: 'Stadtpark',
          proposedAt: t0.add(const Duration(days: 1)),
          createdAt: t0.add(const Duration(minutes: 5)),
        ),
      ],
    );
    expect(items, hasLength(3));
    expect((items[0] as MessageItem).message.content, 'first');
    expect(items[1], isA<ProposalItem>());
    expect((items[2] as MessageItem).message.content, 'third');
  });

  test('report reasons match the database CHECK constraint', () {
    expect(kReportReasons,
        containsAll(['spam', 'harassment', 'inappropriate', 'other']));
    expect(kReportReasons, hasLength(4));
  });
}

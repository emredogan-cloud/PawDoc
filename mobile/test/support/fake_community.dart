// Shared community test harness: a `CommunityRepository` with no network, no
// Supabase and no geolocator, plus the ProviderScope every community screen
// needs.
//
// Not named `*_test.dart`, so `flutter test` does not try to run it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:pawdoc/src/community/community_models.dart';
import 'package:pawdoc/src/community/community_repository.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/walks/location_service.dart';

class FakeLocation extends LocationService {
  const FakeLocation();
  @override
  Future<LocationResult> current() async => const LocationDenied();
}

class FakeCommunityRepo implements CommunityRepository {
  FakeCommunityRepo({
    this.profile,
    this.nearby = const [],
    this.connectionList = const [],
    this.messageList = const [],
    this.proposalList = const [],
    this.others = const {},
    this.throwOnDiscover = false,
  });

  CommunityProfile? profile;
  List<CommunityProfile> nearby;
  List<CommunityConnection> connectionList;
  List<CommunityMessage> messageList;
  List<WalkProposal> proposalList;
  Map<String, CommunityProfile> others;

  /// Drives the offline/error branch every list screen has to have.
  bool throwOnDiscover;

  CommunityProfile? saved;
  final sentMessages = <String>[];
  final responded = <(String, ConnectionStatus)>[];
  final requested = <String>[];
  final reports = <String>[];
  final proposals_ = <WalkProposal>[];
  final proposalResponses = <(String, ProposalStatus)>[];
  bool left = false;

  @override
  Future<CommunityProfile?> myProfile() async => profile;
  @override
  Future<void> saveProfile(CommunityProfile p) async => saved = p;
  @override
  Future<void> leaveCommunity() async => left = true;
  @override
  Future<List<CommunityProfile>> discover(List<String> cells) async {
    if (throwOnDiscover) throw StateError('offline');
    return nearby;
  }

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
  Future<void> propose(WalkProposal proposal) async => proposals_.add(proposal);
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

/// A handset surface, 393dp wide like the mockups and tall enough that a
/// screen's whole body is laid out.
///
/// Without this the window is 800×600: `HealthRecordScaffold` builds a Column
/// in a scroll view, so everything is *built* and `find` succeeds, but a
/// `tap` below the fold lands outside the view and silently does nothing.
void communitySurface(WidgetTester tester, {double height = 3000}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

/// Wraps [home] in the scope every community screen expects.
Widget communityApp(Widget home, FakeCommunityRepo repo, {String uid = 'me'}) {
  return ProviderScope(
    overrides: [
      communityRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue(uid),
      locationServiceProvider.overrideWithValue(const FakeLocation()),
      petsListProvider.overrideWith((ref) async =>
          const [Pet(id: 'p1', userId: 'me', name: 'Rex', species: 'dog')]),
    ],
    child: MaterialApp(home: home),
  );
}

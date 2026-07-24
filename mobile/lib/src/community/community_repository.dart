import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'community_models.dart';

/// Paw Community data access. Everything is RLS-scoped; the policies (not
/// this class) are the enforcement layer — see the community migration and
/// rls_isolation.sql. Realtime message updates come from a Supabase stream
/// with pull-to-refresh as the graceful fallback.
class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  // --- membership ----------------------------------------------------------

  /// The caller's own profile — null means "not opted in".
  Future<CommunityProfile?> myProfile() async {
    final rows = await _client
        .from('community_profiles')
        .select()
        .eq('user_id', _uid)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return CommunityProfile.fromJson(list.first as Map<String, dynamic>);
  }

  Future<void> saveProfile(CommunityProfile profile) async {
    await _client.from('community_profiles').upsert({
      'user_id': _uid,
      ...profile.toColumns(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Leaving deletes the profile row; connections/messages/proposals cascade
  /// at the database — the member's graph dissolves in one statement.
  Future<void> leaveCommunity() async {
    await _client.from('community_profiles').delete().eq('user_id', _uid);
  }

  // --- discovery -----------------------------------------------------------

  /// Discoverable members in the given geohash cells (the caller computes its
  /// 3×3 neighbor block on-device), excluding self.
  Future<List<CommunityProfile>> discover(List<String> cells) async {
    if (cells.isEmpty) return const [];
    final rows = await _client
        .from('community_profiles')
        .select()
        .inFilter('geohash', cells)
        .eq('is_discoverable', true)
        .neq('user_id', _uid)
        .limit(50);
    return (rows as List)
        .map((r) => CommunityProfile.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Profiles by id (to render connection/request cards).
  Future<Map<String, CommunityProfile>> profilesById(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('community_profiles')
        .select()
        .inFilter('user_id', ids);
    return {
      for (final r in rows as List)
        (r as Map<String, dynamic>)['user_id'] as String:
            CommunityProfile.fromJson(r),
    };
  }

  // --- connections ---------------------------------------------------------

  Future<List<CommunityConnection>> connections() async {
    final rows = await _client
        .from('community_connections')
        .select()
        .or('requester_id.eq.$_uid,addressee_id.eq.$_uid')
        .order('updated_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((r) => CommunityConnection.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> sendRequest(String addresseeId) async {
    await _client.from('community_connections').insert({
      'requester_id': _uid,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
  }

  /// Accept / decline / block (RLS enforces who may set what).
  Future<void> respond(String connectionId, ConnectionStatus status) async {
    await _client.from('community_connections').update({
      'status': status.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', connectionId);
  }

  /// Cancel a pending request / remove a connection entirely.
  Future<void> removeConnection(String connectionId) async {
    await _client
        .from('community_connections')
        .delete()
        .eq('id', connectionId);
  }

  // --- chat ----------------------------------------------------------------

  Future<List<CommunityMessage>> messages(String connectionId) async {
    final rows = await _client
        .from('community_messages')
        .select()
        .eq('connection_id', connectionId)
        .order('created_at', ascending: true)
        .limit(300);
    return (rows as List)
        .map((r) => CommunityMessage.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Live message stream (initial fetch + realtime inserts, RLS-scoped).
  Stream<List<CommunityMessage>> messagesStream(String connectionId) {
    return _client
        .from('community_messages')
        .stream(primaryKey: ['id'])
        .eq('connection_id', connectionId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .map((r) => CommunityMessage.fromJson(r))
            .toList(growable: false));
  }

  Future<void> sendMessage(String connectionId, String content) async {
    await _client.from('community_messages').insert({
      'connection_id': connectionId,
      'sender_id': _uid,
      'content': content,
    });
  }

  // --- walk proposals ------------------------------------------------------

  Future<List<WalkProposal>> proposals(String connectionId) async {
    final rows = await _client
        .from('walk_proposals')
        .select()
        .eq('connection_id', connectionId)
        .order('created_at', ascending: true)
        .limit(50);
    return (rows as List)
        .map((r) => WalkProposal.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> propose(WalkProposal proposal) async {
    await _client.from('walk_proposals').insert({
      'connection_id': proposal.connectionId,
      'proposer_id': _uid,
      'place_name': proposal.placeName,
      'note': proposal.note,
      'proposed_at': proposal.proposedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> respondProposal(String proposalId, ProposalStatus status) async {
    await _client
        .from('walk_proposals')
        .update({'status': status.name}).eq('id', proposalId);
  }

  // --- safety --------------------------------------------------------------

  Future<void> report({
    required String reportedUserId,
    required String reason,
    String? details,
    String? connectionId,
  }) async {
    await _client.from('community_reports').insert({
      'reporter_id': _uid,
      'reported_user_id': reportedUserId,
      'reason': reason,
      'details': details,
      'connection_id': connectionId,
    });
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.watch(supabaseClientProvider));
});

/// Own membership (null = not opted in) — gates every community surface.
final myCommunityProfileProvider =
    FutureProvider.autoDispose<CommunityProfile?>((ref) {
  return ref.watch(communityRepositoryProvider).myProfile();
});

final communityConnectionsProvider =
    FutureProvider.autoDispose<List<CommunityConnection>>((ref) {
  return ref.watch(communityRepositoryProvider).connections();
});

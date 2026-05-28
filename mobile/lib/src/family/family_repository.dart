import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// One member row exposed on the FamilySettingsScreen.
class FamilyMember {
  const FamilyMember({required this.userId, required this.email, required this.role});
  final String userId;
  final String? email;
  final String role; // 'owner' | 'member'

  factory FamilyMember.fromJoinRow(Map<String, dynamic> row) {
    final user = (row['user'] as Map<String, dynamic>?) ?? const {};
    return FamilyMember(
      userId: row['user_id'] as String,
      email: user['email'] as String?,
      role: (row['role'] as String?) ?? 'member',
    );
  }
}

/// Lightweight summary used by [familySummaryProvider] / the Settings tile.
class FamilySummary {
  const FamilySummary({
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.ownerUserId,
  });
  final String groupId;
  final String groupName;
  final List<FamilyMember> members;
  final String ownerUserId;
}

class FamilyRepository {
  FamilyRepository(this._client);
  final SupabaseClient _client;

  /// Returns the caller's OWNED family group + its members. Family Sharing
  /// only invites from a group the caller owns; the trigger from Phase 6.3
  /// guarantees every user owns at least their solo group.
  Future<FamilySummary?> mySummary() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final group = await _client
        .from('family_groups')
        .select('id, name, owner_user_id')
        .eq('owner_user_id', uid)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    if (group == null) return null;
    final rows = await _client
        .from('family_members')
        .select('user_id, role, user:users!inner(email)')
        .eq('group_id', group['id'] as String);
    final members = (rows as List)
        .map((r) => FamilyMember.fromJoinRow(Map<String, dynamic>.from(r as Map)))
        .toList();
    return FamilySummary(
      groupId: group['id'] as String,
      groupName: (group['name'] as String?) ?? 'My household',
      members: members,
      ownerUserId: group['owner_user_id'] as String,
    );
  }

  Future<Map<String, dynamic>> sendInvite(String email) async {
    final resp = await _client.functions.invoke(
      'invite-family-member',
      body: {'email': email},
    );
    if (resp.status >= 400) {
      final body = resp.data is Map ? resp.data as Map : const {};
      throw FamilyInviteException(
        code: (body['error'] as String?) ?? 'unknown',
        message: (body['message'] as String?) ??
            'Could not send the invite (HTTP ${resp.status}).',
        status: resp.status,
      );
    }
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> acceptInvite(String token) async {
    final resp = await _client.functions.invoke(
      'accept-family-invite',
      body: {'token': token},
    );
    if (resp.status >= 400) {
      final body = resp.data is Map ? resp.data as Map : const {};
      throw FamilyInviteException(
        code: (body['error'] as String?) ?? 'unknown',
        message: (body['message'] as String?) ??
            'Could not accept the invite (HTTP ${resp.status}).',
        status: resp.status,
      );
    }
    return Map<String, dynamic>.from(resp.data as Map);
  }
}

class FamilyInviteException implements Exception {
  const FamilyInviteException({
    required this.code,
    required this.message,
    required this.status,
  });
  final String code;
  final String message;
  final int status;
  @override
  String toString() => 'FamilyInviteException($code, $status): $message';
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(ref.watch(supabaseClientProvider));
});

final familySummaryProvider = FutureProvider.autoDispose<FamilySummary?>((ref) {
  return ref.watch(familyRepositoryProvider).mySummary();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// **Who the signed-in user actually is, according to the database.**
///
/// The `profile` and `account_management` references open with a header that
/// prints a full name, an email, a phone number, a city and a join date, and
/// then list six editable rows under "Account Information": Full Name, Email,
/// Phone Number, Location, Date of Birth, Language.
///
/// PawDoc stores **two** of those. There is no third.
///
/// * `auth.users` carries the email, the identity provider and the creation
///   timestamp. A Google sign-in additionally puts `full_name` / `avatar_url`
///   into `user_metadata`, because Google supplies them — PawDoc never asks.
/// * `public.users` carries `subscription_status`, the photo-check counters and
///   `preferred_locale`, and the client **cannot write any of it**:
///   `20260527030000_referrals.sql` runs
///   `revoke update on public.users from anon, authenticated`, leaving exactly
///   one granted column (`one_signal_player_id`, dead since push was removed).
///
/// So there is no phone number, no location, no date of birth and no owner
/// profile row to edit. Rather than draw six rows over an empty table, the
/// screens render what exists and say plainly what is not collected — which is
/// a better privacy story than the reference's, and true.
class AccountIdentity {
  const AccountIdentity({
    required this.userId,
    required this.email,
    required this.provider,
    required this.createdAt,
    required this.isAnonymous,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;

  /// Empty for a guest (anonymous) session — Supabase issues no address.
  final String email;

  /// `email`, `google`, `apple`, or `anonymous`. Read from `app_metadata`,
  /// which only the auth server writes.
  final String provider;

  /// `auth.users.created_at`. Real, and the only date the header can print.
  final DateTime? createdAt;

  final bool isAnonymous;

  /// Supplied by the identity provider (Google), never collected by PawDoc and
  /// never editable here. Null for every email and guest session.
  final String? displayName;
  final String? avatarUrl;

  /// What the header shows in its largest type.
  ///
  /// Deliberately not a fabricated "Pet Parent": a guest session has no name
  /// and saying so is the honest header.
  String get headline {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (isAnonymous) return 'Guest session';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Your account';
  }

  /// One or two letters for the avatar disc when no picture exists.
  String get initials {
    final source = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (email.isNotEmpty ? email : '');
    if (source.isEmpty) return '?';
    final words = source
        .split(RegExp(r'[\s._@-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  /// How the account was created, in the user's words.
  String get providerLabel => switch (provider) {
        'google' => 'Google',
        'apple' => 'Apple',
        'anonymous' => 'Guest — no email',
        _ => 'Email & password',
      };

  /// True when a password exists to change. Google/Apple/guest sessions have
  /// none, so the security row must not offer to reset one.
  bool get hasPassword => provider == 'email' && email.isNotEmpty;
}

/// The current identity, or null when signed out.
///
/// Derived from [currentUserIdProvider] rather than the client directly — see
/// that provider's note: `supabaseClientProvider` is a singleton, so a
/// provider that watches only the client is computed once per process and
/// serves the previous account's values after an identity change.
final accountIdentityProvider = Provider<AccountIdentity?>((ref) {
  ref.watch(currentUserIdProvider);
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return null;
  final meta = user.userMetadata ?? const <String, dynamic>{};
  final name = (meta['full_name'] ?? meta['name']) as String?;
  final avatar = (meta['avatar_url'] ?? meta['picture']) as String?;
  final isAnonymous = user.isAnonymous;
  return AccountIdentity(
    userId: user.id,
    email: user.email ?? '',
    provider: isAnonymous
        ? 'anonymous'
        : (user.appMetadata['provider'] as String?) ?? 'email',
    createdAt: DateTime.tryParse(user.createdAt),
    isAnonymous: isAnonymous,
    displayName: name,
    avatarUrl: avatar,
  );
});

/// The counts the `profile` reference prints across its statistics strip.
///
/// Every one is a `count` over a table the caller owns, read through the user's
/// JWT and RLS. The reference's fifth cell is "Vet Visits", which PawDoc does
/// not model as its own entity — visits are `health_events` like any other
/// record — so the strip carries journal entries instead of inventing a
/// category, and the "Vaccinations" cell counts the records the owner actually
/// typed in rather than asserting an immunity status (the same rule
/// `vaccination_manager` ships under).
class AccountSummary {
  const AccountSummary({
    required this.pets,
    required this.healthRecords,
    required this.vaccinationRecords,
    required this.reminders,
    required this.journalEntries,
  });

  /// Every count failed to read — the strip renders em dashes, never zeroes.
  /// A zero is a claim ("you have no records"); a dash is the truth ("we could
  /// not read them just now").
  static const AccountSummary unknown = AccountSummary(
    pets: null,
    healthRecords: null,
    vaccinationRecords: null,
    reminders: null,
    journalEntries: null,
  );

  final int? pets;
  final int? healthRecords;
  final int? vaccinationRecords;
  final int? reminders;
  final int? journalEntries;
}

/// Five RLS-scoped counts, read together.
///
/// `count` queries rather than fetching rows: the strip needs the number, and
/// pulling every health event to call `.length` on it is the kind of thing that
/// makes a settings screen slower than the timeline it summarises.
final accountSummaryProvider =
    FutureProvider.autoDispose<AccountSummary>((ref) async {
  ref.watch(currentUserIdProvider);
  final client = ref.watch(supabaseClientProvider);

  Future<int?> count(PostgrestFilterBuilder<dynamic> query) async {
    try {
      final res = await query.count(CountOption.exact);
      return res.count;
    } catch (_) {
      // One unreadable table must not blank the whole strip.
      return null;
    }
  }

  final results = await Future.wait([
    count(client.from('pets').select('id')),
    count(client.from('health_events').select('id')),
    count(client.from('health_events').select('id').eq('event_type', 'vaccination')),
    count(client.from('reminders').select('id')),
    count(client.from('pet_memories').select('id')),
  ]);

  return AccountSummary(
    pets: results[0],
    healthRecords: results[1],
    vaccinationRecords: results[2],
    reminders: results[3],
    journalEntries: results[4],
  );
});

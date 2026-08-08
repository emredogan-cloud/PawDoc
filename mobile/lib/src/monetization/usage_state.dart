import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';
import '../core/data_timeout.dart';
import '../memories/memories_repository.dart';
import '../pets/pets_repository.dart';

/// The counts `usage_limits` draws, read from the same rows the server meters
/// against.
///
/// Every field here is a real number or an admission that it could not be
/// read. There is no estimate and no default-to-zero: a failed count renders
/// as *"could not be read"*, because a zero the user did not earn reads as
/// "you have used nothing" and a full bar they did not fill reads as a bill.
/// (The same defect the community batch found — `snapshot.data ?? []` turning
/// a network error into "nobody is here".)
class AccountUsage {
  const AccountUsage({
    required this.journalEntries,
    required this.petCount,
    required this.assistantMessagesToday,
  });

  /// Journal entries across every pet. Counted server-side under RLS.
  final int journalEntries;

  /// Pets on this account. No plan limits this — the row exists to say so.
  final int petCount;

  /// User-role assistant messages since the start of the current **UTC** day —
  /// the identical window `assistant-chat` counts before it blocks
  /// (`dayStart.setUTCHours(0,0,0,0)`). A local-midnight window would disagree
  /// with the server for most of the planet.
  ///
  /// `null` when the read failed.
  final int? assistantMessagesToday;
}

/// Counts the caller's own assistant messages for the current UTC day.
///
/// RLS (`assistant_messages_select_own`) scopes this to the signed-in user, so
/// no service role is involved — a user-data read goes through the user's JWT,
/// always.
final assistantMessagesTodayProvider =
    FutureProvider.autoDispose<int?>((ref) async {
  ref.watch(currentUserIdProvider);
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;
  final now = DateTime.now().toUtc();
  final dayStart = DateTime.utc(now.year, now.month, now.day);
  try {
    return await client
        .from('assistant_messages')
        .select('id')
        .eq('user_id', uid)
        .eq('role', 'user')
        .gte('created_at', dayStart.toIso8601String())
        .count()
        .timeout(kDataReadTimeout)
        .then((res) => res.count);
  } catch (_) {
    // A failed count is not a zero. The meter says so.
    return null;
  }
});

/// Everything `usage_limits` needs beyond the profile itself.
final accountUsageProvider = FutureProvider.autoDispose<AccountUsage>((ref) async {
  final journal = await ref.watch(memoriesCountProvider.future);
  final pets = await ref.watch(petsListProvider.future);
  final assistant = await ref.watch(assistantMessagesTodayProvider.future);
  return AccountUsage(
    journalEntries: journal,
    petCount: pets.length,
    assistantMessagesToday: assistant,
  );
});

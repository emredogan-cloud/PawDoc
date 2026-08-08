/// **The "personal recommendation", built out of things that actually happened.**
///
/// The brief for this surface asked for a recommendation in a coach's voice,
/// personalised to how the account has used PawDoc. Two ways to build that, and
/// only one of them is allowed here.
///
/// The tempting one is a live model call: ask an LLM to look at the account and
/// write something warm. It is also the one that goes wrong in every direction
/// at once — it can invent usage that never happened, promise a capability that
/// does not exist, take on the voice of a veterinarian, cost money on a screen
/// that has not earned any, and fail entirely when the device is offline. A
/// paywall is the last place in this product where a generative model should be
/// deciding what is true about somebody's pet.
///
/// So this is arithmetic over counters the app already reads, phrased in
/// PawDoc's own voice:
///
/// * `users.free_analyses_used_this_month` — the column the server meters on,
/// * a `count(*)` over the caller's own journal entries,
/// * a `count(*)` over today's assistant messages (the same UTC window
///   `assistant-chat` counts),
///
/// each of which is already fetched for `usage_limits`. Nothing is sampled,
/// estimated, or inferred from behaviour PawDoc does not record.
///
/// Three rules hold every line below:
///
/// 1. **No fabricated usage.** A counter that could not be read is null, and a
///    null counter produces [OfferRecommendation.personalised] `== false` and a
///    line that says the account could not be read. It never becomes a zero,
///    and a zero never becomes a story.
/// 2. **No borrowed authority.** PawDoc speaks as PawDoc. Not a veterinarian,
///    not a clinician, not a person, not "your coach who has been watching" —
///    it has watched four integers.
/// 3. **No invented capability.** Every recommendation names a row of
///    [kEntitlements] and quotes that row's real allowance.
library;

import 'entitlements.dart';


/// A recommendation, with its own evidence attached.
class OfferRecommendation {
  const OfferRecommendation({
    required this.headline,
    required this.body,
    required this.basis,
    required this.personalised,
    this.entitlementId,
  });

  /// One short line, PawDoc's voice, no claim beyond the counters.
  final String headline;

  /// What upgrading would change about it — always a real entitlement value.
  final String body;

  /// The provenance line rendered under the recommendation, verbatim. Present
  /// on every branch, including the honest "we could not read it" one.
  final String basis;

  /// False when no counter was readable, so the surface can drop the
  /// "based on your usage" framing rather than dress a generic line as a
  /// personal one.
  final bool personalised;

  /// Which row of [kEntitlements] this points at, for the surface to render
  /// alongside. Null only when nothing could be read.
  final String? entitlementId;
}

const String _personalBasis =
    'Based only on this account’s own counts — photo checks, journal entries '
    'and assistant messages. PawDoc has no other information about how you use '
    'it.';

const String _genericBasis =
    'Your usage counts could not be read on this device just now, so this is '
    'the general summary rather than anything about your account.';

/// Builds the recommendation from real counters.
///
/// Every argument is nullable because every one of them comes from a read that
/// can fail, and a failed read is information — it is not a zero.
///
/// Pet count is deliberately **not** an input. Pets are unlimited on both
/// plans, so "you have three pets" is not a reason to upgrade, and using it as
/// one would be the first invented benefit in a file written to prevent them.
OfferRecommendation recommendUpgrade({
  int? photoChecksUsedThisMonth,
  int? journalEntries,
  int? assistantMessagesToday,
}) {
  final readable = photoChecksUsedThisMonth != null ||
      journalEntries != null ||
      assistantMessagesToday != null;

  if (!readable) {
    return const OfferRecommendation(
      headline: 'Premium lifts the three counted limits.',
      body: 'Photo health checks, journal entries and assistant messages stop '
          'being counted. Emergency help and symptom checks by text are '
          'already free for everyone, on every plan.',
      basis: _genericBasis,
      personalised: false,
    );
  }

  // Ordered by how much the account actually pressed on each ceiling. A limit
  // that was reached outranks one that was approached, which outranks one that
  // was merely touched.
  final photos = photoChecksUsedThisMonth ?? 0;
  final journal = journalEntries ?? 0;
  final assistant = assistantMessagesToday ?? 0;

  if (photos >= kFreePhotoChecksPerMonth) {
    return OfferRecommendation(
      headline: 'You used all $kFreePhotoChecksPerMonth photo checks this '
          'month.',
      body: 'On Premium a photo check is not counted, so a photo is never the '
          'reason a check waits until next month.',
      basis: _personalBasis,
      personalised: true,
      entitlementId: 'photo_checks',
    );
  }
  if (journal >= kFreeJournalEntries) {
    return OfferRecommendation(
      headline: 'Your journal is at its $kFreeJournalEntries-entry limit.',
      body: 'Premium removes the ceiling. Everything already saved stays '
          'exactly where it is on either plan.',
      basis: _personalBasis,
      personalised: true,
      entitlementId: 'journal',
    );
  }
  if (assistant >= kFreeAssistantMessagesPerDay) {
    return OfferRecommendation(
      headline: 'You reached today’s $kFreeAssistantMessagesPerDay assistant '
          'messages.',
      body: 'Premium stops counting them. The daily allowance resets either '
          'way — Premium just removes the wait.',
      basis: _personalBasis,
      personalised: true,
      entitlementId: 'assistant',
    );
  }
  if (photos > 0) {
    final left = kFreePhotoChecksPerMonth - photos;
    return OfferRecommendation(
      headline: photos == 1
          ? 'You have run 1 photo check this month.'
          : 'You have run $photos photo checks this month.',
      body: left == 1
          ? '1 is left on the free plan before the allowance resets. Premium '
              'stops counting them.'
          : '$left are left on the free plan before the allowance resets. '
              'Premium stops counting them.',
      basis: _personalBasis,
      personalised: true,
      entitlementId: 'photo_checks',
    );
  }

  // Nothing has pressed a ceiling. Saying so is the honest answer, and it is
  // also the true one: on this account, the only thing an upgrade adds today is
  // the PDF report.
  return const OfferRecommendation(
    headline: 'Nothing on this account has hit a free limit yet.',
    body: 'So the one thing Premium would add for you today is the PDF health '
        'report — the record as a printable file for a vet visit. The counted '
        'allowances are there if you ever reach them.',
    basis: _personalBasis,
    personalised: true,
    entitlementId: 'pdf_report',
  );
}

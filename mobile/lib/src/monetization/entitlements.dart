/// **What PawDoc actually sells.** One catalogue, traced line by line to the
/// code that enforces it, shared by every premium surface.
///
/// The four monetization references in `new-interface/` are the most
/// claim-dense plates in the whole set, and almost none of what they promise
/// exists. `premium_home` sells *"Vet Chat Priority — get faster responses
/// from verified veterinarians"*; `subscription_plans` prints three tiers at
/// three invented prices, a 7-day money-back guarantee and *"4.9/5 from
/// 10,000+ reviews"*; `upgrade_benefits` grades Free at *"Limit: 1 GB"* and
/// Premium at *"Unlimited"* storage; `usage_limits` draws seven meters, four
/// of which count things nothing counts.
///
/// So the catalogue below exists to make the honest answer the *easy* one:
/// a screen asks this file what a capability is worth, and cannot invent one.
///
/// ## Where each row comes from
///
/// | Row | Enforced by |
/// |---|---|
/// | Emergency help | `CLAUDE.md` rule 4 + `quota_gate.mjs` — never metered, never paywalled |
/// | Text symptom checks | `quota_gate.mjs` `isMetered()` — photos only |
/// | Photo health checks | `free_tier.mjs` `FREE_PHOTO_MONTHLY_LIMIT = 5`, server-metered pre-AI |
/// | Assistant messages | `assistant_chat.mjs` `ASSISTANT_FREE_DAILY_LIMIT = 20`, server-counted |
/// | Journal entries | `memory.dart` `kFreeMemoryLimit = 20`, client-gated |
/// | PDF health report | `generate-pdf-report/index.ts` → HTTP 402 for non-premium |
/// | Everything else | no gate exists in any layer — so it is free, and says so |
///
/// ## What the references claim and this product does not have
///
/// Deliberately absent, and absent by name so a later screen cannot quietly
/// reintroduce them (`premium_screens_test.dart`'s `product truth` group scans
/// every rendered string on all four surfaces for each):
///
/// * **Verified veterinarians / vet chat.** No veterinarian is employed,
///   contracted, verified or reachable. This is the single most dangerous
///   invention in the reference set — it would sell a licensed opinion.
/// * **"Premium tools made by vets."** No veterinarian authored the product.
/// * **A money-back guarantee.** Refunds are Google Play's, on Google's terms.
/// * **A free trial**, unless the *store* reports an introductory offer on the
///   product — which the paywall reads at runtime rather than asserting.
/// * **Ratings, review counts, customer counts, "loved by pet parents".**
///   Pre-launch, there are none.
/// * **Storage quotas.** No layer counts bytes; neither "1 GB" nor "Unlimited"
///   is a statement PawDoc can make.
/// * **Advanced analytics, priority support, early access, dedicated support,
///   multi-user access.** None exist in any tier.
/// * **Pet limits.** `upgrade_benefits` sells "1 Pet" against "Up to 15 Pets".
///   PawDoc has never limited pets, on any plan.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../memories/memory.dart' show kFreeMemoryLimit;

/// Free photo health checks per calendar month.
///
/// Mirrors `FREE_PHOTO_MONTHLY_LIMIT` in
/// `supabase/functions/_shared/free_tier.mjs`, which is the *enforcing* copy —
/// the meter runs pre-AI on the server, so this constant is presentation only
/// and must never be treated as the gate. `entitlements_test.dart`
/// reads the `.mjs` and fails if the two drift.
const int kFreePhotoChecksPerMonth = 5;

/// Free assistant messages per UTC day.
///
/// Mirrors `ASSISTANT_FREE_DAILY_LIMIT` in
/// `supabase/functions/_shared/assistant_chat.mjs`. Same rule: the server
/// counts, this describes.
const int kFreeAssistantMessagesPerDay = 20;

/// Free journal entries, in total. Re-exported so a premium screen needs one
/// import rather than reaching into the memories module.
const int kFreeJournalEntries = kFreeMemoryLimit;

/// How a capability is offered.
enum EntitlementKind {
  /// Shipping, identical on both plans. Upgrading changes nothing about it —
  /// which is worth *stating*, because the references sell several of these
  /// as premium unlocks.
  everyone,

  /// Shipping, with a free allowance and no premium ceiling.
  metered,

  /// Shipping, premium only.
  premiumOnly,

  /// Drawn by the reference, not built. Keeps its row, marked, per the *Soon*
  /// convention: never delete the affordance, never fake the value.
  soon,
}

/// One row of the plan comparison, one card on the premium home, one meter on
/// the usage screen — the same fact, told three ways.
class Entitlement {
  const Entitlement({
    required this.id,
    required this.icon,
    required this.title,
    required this.short,
    required this.blurb,
    required this.freeValue,
    required this.premiumValue,
    required this.kind,
  });

  final String id;
  final IconData icon;
  final String title;

  /// The title for a column 90dp wide or less — the icon strip and the
  /// value rows, where the full title ellipsised on the device
  /// ("Symptom chec…", "Photo & file sto…"). Never longer than 13 characters.
  final String short;

  /// One line, in the product's own voice. Never a benefit claim that outruns
  /// the implementation.
  final String blurb;

  /// What the free plan gets. `'—'` means "not on this plan".
  final String freeValue;
  final String premiumValue;

  final EntitlementKind kind;

  /// True when upgrading actually changes this row. The comparison table
  /// leads with these; the rest are the reassurance rows.
  bool get upgradeChangesIt =>
      kind == EntitlementKind.metered || kind == EntitlementKind.premiumOnly;
}

/// The audited catalogue. Order is the order every surface renders it in:
/// safety first, then what the meter touches, then what is already free.
const List<Entitlement> kEntitlements = [
  Entitlement(
    id: 'emergency',
    icon: LucideIcons.circleAlert,
    title: 'Emergency help',
    short: 'Emergency',
    blurb: 'The red button, first aid and the vet hand-off. Never counted, '
        'never behind a plan, works offline.',
    freeValue: 'Always',
    premiumValue: 'Always',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'text_checks',
    icon: LucideIcons.messageSquareText,
    title: 'Symptom checks by text',
    short: 'Text checks',
    blurb: 'Describe what you are seeing and get a next step. Text checks are '
        'not metered on any plan.',
    freeValue: 'Unlimited',
    premiumValue: 'Unlimited',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'photo_checks',
    icon: LucideIcons.camera,
    title: 'Photo health checks',
    short: 'Photo checks',
    blurb: 'Add a photo or a video to a check. The free allowance resets at '
        'the start of each month.',
    freeValue: '$kFreePhotoChecksPerMonth / month',
    premiumValue: 'Unlimited',
    kind: EntitlementKind.metered,
  ),
  Entitlement(
    id: 'assistant',
    icon: LucideIcons.sparkles,
    title: 'Assistant messages',
    short: 'Assistant',
    blurb: 'Everyday pet-life questions. The free allowance resets each day.',
    freeValue: '$kFreeAssistantMessagesPerDay / day',
    premiumValue: 'Unlimited',
    kind: EntitlementKind.metered,
  ),
  Entitlement(
    id: 'journal',
    icon: LucideIcons.images,
    title: 'Journal entries',
    short: 'Journal',
    blurb: 'Photos and notes kept against a pet, with the date they were '
        'taken.',
    freeValue: '$kFreeJournalEntries entries',
    premiumValue: 'Unlimited',
    kind: EntitlementKind.metered,
  ),
  Entitlement(
    id: 'pdf_report',
    icon: LucideIcons.fileText,
    title: 'PDF health report',
    short: 'PDF report',
    blurb: 'The record as a printable PDF, built on the server and handed '
        'straight to your share sheet.',
    freeValue: '—',
    premiumValue: 'Included',
    kind: EntitlementKind.premiumOnly,
  ),
  Entitlement(
    id: 'pets',
    icon: LucideIcons.pawPrint,
    title: 'Pets',
    short: 'Pets',
    blurb: 'Add every animal you keep. PawDoc has never limited this on any '
        'plan.',
    freeValue: 'Unlimited',
    premiumValue: 'Unlimited',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'records',
    icon: LucideIcons.clipboardList,
    title: 'Health records & timeline',
    short: 'Records',
    blurb: 'Visits, medications, vaccinations, weights and notes, kept for as '
        'long as the account exists.',
    freeValue: 'Unlimited',
    premiumValue: 'Unlimited',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'reminders',
    icon: LucideIcons.bellRing,
    title: 'Reminders',
    short: 'Reminders',
    blurb: 'Vaccines, medication and re-checks, with a push when they come '
        'due.',
    freeValue: 'Unlimited',
    premiumValue: 'Unlimited',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'vet_prep',
    icon: LucideIcons.stethoscope,
    title: 'Vet visit prep',
    short: 'Vet prep',
    blurb: 'Your reasons, your questions and the record, assembled into one '
        'thing to take with you.',
    freeValue: 'Included',
    premiumValue: 'Included',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'text_export',
    icon: LucideIcons.share2,
    title: 'Share the record as text',
    short: 'Text export',
    blurb: 'The same summary as plain text, through your device share sheet.',
    freeValue: 'Included',
    premiumValue: 'Included',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'community',
    icon: LucideIcons.users,
    title: 'Community & nearby owners',
    short: 'Community',
    blurb: 'Opt-in, and the same for everyone. No plan buys reach or ranking.',
    freeValue: 'Opt-in',
    premiumValue: 'Opt-in',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'storage',
    icon: LucideIcons.cloudUpload,
    title: 'Photo & file storage',
    short: 'Storage',
    blurb: 'PawDoc applies no storage quota today, so there is no figure here '
        'to sell you.',
    freeValue: 'Not metered',
    premiumValue: 'Not metered',
    kind: EntitlementKind.everyone,
  ),
  Entitlement(
    id: 'family',
    icon: LucideIcons.userPlus,
    title: 'Family sharing',
    short: 'Family',
    blurb: 'Letting a second person into one pet’s record. Not built yet — no '
        'plan includes it.',
    freeValue: '—',
    premiumValue: '—',
    kind: EntitlementKind.soon,
  ),
];

/// The rows an upgrade actually changes — what the premium home leads with.
List<Entitlement> get premiumUnlocks =>
    kEntitlements.where((e) => e.upgradeChangesIt).toList(growable: false);

/// The rows that are the same on both plans, in the order above.
List<Entitlement> get includedForEveryone => kEntitlements
    .where((e) => e.kind == EntitlementKind.everyone)
    .toList(growable: false);

Entitlement entitlementById(String id) =>
    kEntitlements.firstWhere((e) => e.id == id);

// ---------------------------------------------------------------------------
// Usage
// ---------------------------------------------------------------------------

/// One row of `usage_limits`, and the only shape that surface can draw.
///
/// The reference prints a filled bar for every capability it lists, including
/// four nothing counts. A meter here is either **counted** — a real integer
/// read out of the same store the server meters against — or it declares that
/// it is not, and draws no bar at all. There is no third state where a number
/// is estimated, sampled or assumed.
class UsageMeter {
  const UsageMeter({
    required this.id,
    required this.icon,
    required this.title,
    required this.blurb,
    required this.used,
    required this.limit,
    required this.window,
    this.resetsAt,
    this.locked = false,
    this.note,
  });

  final String id;
  final IconData icon;
  final String title;
  final String blurb;

  /// How many have been used. `null` means **nothing counts this** — the row
  /// still renders, without a bar and without a number.
  final int? used;

  /// The allowance. `null` with a non-null [used] means counted but unlimited.
  final int? limit;

  /// "per month", "per day", "in total", or `null` when neither applies.
  final String? window;

  /// When the allowance rolls over, if it does.
  final DateTime? resetsAt;

  /// Premium-only, and this account is not premium.
  final bool locked;

  /// The line under the bar, when it is not simply the reset date.
  final String? note;

  bool get tracked => used != null;
  bool get unlimited => limit == null;

  /// Remaining allowance, or `null` when there is no ceiling to run out of.
  int? get remaining =>
      (used == null || limit == null) ? null : (limit! - used!).clamp(0, limit!);

  /// Bar fill in 0..1. Zero when there is nothing to fill.
  double get fraction {
    if (used == null || limit == null || limit! <= 0) return 0;
    return (used! / limit!).clamp(0.0, 1.0);
  }

  bool get exhausted => remaining == 0;
}

/// Build the usage rows from real counters only.
///
/// Every argument is a value some layer genuinely stores:
/// * [photoChecksUsed] / [photoChecksResetAt] — `users.free_analyses_used_this_month`
///   and `users.free_analyses_reset_at`, the columns the server meters on.
/// * [journalEntries] — a `SELECT count(*)` over the caller's own memories.
/// * [assistantMessagesToday] — a count over `assistant_messages` for the
///   current UTC day, the same window `assistant-chat` counts. `null` when the
///   read failed, which renders as "could not be read", never as zero.
/// * [petCount] — the caller's pets. There is no limit; the row says so.
///
/// A premium account has no ceilings, so every metered row loses its limit
/// rather than gaining a bigger one.
List<UsageMeter> buildUsageMeters({
  required bool isPremium,
  required int photoChecksUsed,
  DateTime? photoChecksResetAt,
  required int journalEntries,
  int? assistantMessagesToday,
  required int petCount,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final dayEnd = DateTime(today.year, today.month, today.day)
      .add(const Duration(days: 1));
  return [
    UsageMeter(
      id: 'photo_checks',
      icon: LucideIcons.camera,
      title: 'Photo health checks',
      blurb: 'Checks that carried a photo or a video',
      used: photoChecksUsed,
      limit: isPremium ? null : kFreePhotoChecksPerMonth,
      window: 'per month',
      resetsAt: isPremium ? null : photoChecksResetAt,
    ),
    const UsageMeter(
      id: 'text_checks',
      icon: LucideIcons.messageSquareText,
      title: 'Symptom checks by text',
      blurb: 'Describe what you are seeing, any time',
      used: null,
      limit: null,
      window: null,
      note: 'Never metered — on any plan. PawDoc does not count safety.',
    ),
    UsageMeter(
      id: 'assistant',
      icon: LucideIcons.sparkles,
      title: 'Assistant messages',
      blurb: 'Everyday questions about pet life',
      used: assistantMessagesToday,
      limit: isPremium ? null : kFreeAssistantMessagesPerDay,
      window: 'per day',
      resetsAt: isPremium ? null : dayEnd,
      note: assistantMessagesToday == null
          ? 'Today’s count could not be read just now.'
          : null,
    ),
    UsageMeter(
      id: 'journal',
      icon: LucideIcons.images,
      title: 'Journal entries',
      blurb: 'Photos and notes kept against your pets',
      used: journalEntries,
      limit: isPremium ? null : kFreeJournalEntries,
      window: 'in total',
      note: isPremium ? null : 'This allowance does not reset — it is a total.',
    ),
    UsageMeter(
      id: 'pdf_report',
      icon: LucideIcons.fileText,
      title: 'PDF health report',
      blurb: 'The record as a printable PDF',
      used: null,
      limit: null,
      window: null,
      locked: !isPremium,
      note: isPremium
          ? 'Included, and not counted — generate as many as you need.'
          : 'Part of Premium. Nothing is counted on either plan.',
    ),
    UsageMeter(
      id: 'pets',
      icon: LucideIcons.pawPrint,
      title: 'Pets',
      blurb: 'Profiles on this account',
      used: petCount,
      limit: null,
      window: null,
      note: 'No limit applies, on either plan.',
    ),
    const UsageMeter(
      id: 'storage',
      icon: LucideIcons.cloudUpload,
      title: 'Photo & file storage',
      blurb: 'Everything you have uploaded',
      used: null,
      limit: null,
      window: null,
      note: 'Not metered. PawDoc applies no storage quota today.',
    ),
  ];
}

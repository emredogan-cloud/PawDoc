import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offer_prefs.dart';
import 'offer_screen.dart';
import 'offer_state.dart';

/// **The one place an offer is allowed to appear on its own.**
///
/// The brief for this surface said *"do NOT blindly show the popup on every
/// screen transition"*, and the architecture makes that easy to honour: PawDoc
/// has exactly one authenticated shell (`RootShell`), every sign-in path lands
/// on it, and it is already where the pending-pet draft is flushed. So this is
/// called once, from that shell's first frame, and from nowhere else.
///
/// Explicitly *not* triggers:
///
/// * **Route changes.** A router hook fires on every push and would put a sales
///   screen in front of somebody halfway through adding a medication.
/// * **App resume.** Backgrounding to take a photo of a symptom and returning
///   to an offer is the same interruption, with worse timing.
/// * **The analysis result.** `maybeShowPaywall` already owns that moment and
///   already refuses to fire on an emergency; stacking a second surface behind
///   it would put two purchase screens in one flow.
///
/// The gate itself lives in `offerCandidateProvider` — phase, configuration,
/// cooldown and lifetime cap — so this function only decides *where*, never
/// *whether*.
Future<void> maybeShowOffer(BuildContext context, WidgetRef ref) async {
  // `.future` rather than a watch: this runs once from a post-frame callback,
  // and a rebuild-driven read here would re-enter the navigator.
  final candidate = await ref.read(offerCandidateProvider.future);
  if (candidate == null || !context.mounted) return;

  // The cap is spent here — at the moment it actually reaches a screen — and
  // never during eligibility. An offer that was computed but never displayed
  // (because the widget was disposed, or the app was closing) must not count
  // against a budget of three.
  await OfferPrefs.markShown(candidate.surface, DateTime.now());
  if (!context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<bool>(builder: (_) => OfferScreen(candidate: candidate)),
  );
}

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
  // `listenManual`, not a bare `ref.read(...future)`.
  //
  // `offerCandidateProvider` is `autoDispose`, and it awaits two bounded store
  // calls. A `read` opens no subscription, so nothing keeps the provider alive
  // across those awaits and it can be torn down mid-flight — leaving a future
  // that never completes and an offer that silently never appears. That is a
  // hard defect to notice, because "no offer" is also the correct answer
  // almost all of the time.
  //
  // The subscription pins it for the duration and is closed in the `finally`.
  // It does not have to be closed in `dispose` — Riverpod drops it with the
  // widget — but closing it here means the provider is not held for the life
  // of the shell either.
  final sub = ref.listenManual(offerCandidateProvider, (_, _) {});
  final OfferCandidate? candidate;
  try {
    candidate = await ref.read(offerCandidateProvider.future);
  } catch (_) {
    return;
  } finally {
    sub.close();
  }
  if (candidate == null || !context.mounted) return;
  // A local declared `final` without an initialiser is not promoted, and the
  // builder closure below needs the non-nullable type.
  final offer = candidate;

  // The cap is spent here — at the moment it actually reaches a screen — and
  // never during eligibility. An offer that was computed but never displayed
  // (because the widget was disposed, or the app was closing) must not count
  // against a budget of three.
  await OfferPrefs.markShown(offer.surface, DateTime.now());
  if (!context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<bool>(builder: (_) => OfferScreen(candidate: offer)),
  );
}

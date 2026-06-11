import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion_asset.dart';
import 'motion.dart';

/// M3 milestone celebrations (roadmap matrix #14/#15): a calm, ≤2.5s one-shot
/// moment that replaces a bare snackbar on REAL events only (claim success,
/// entitlement-active purchase).
///
/// Contract (roadmap §3 M3 acceptance):
/// * auto-dismisses at [duration] (≤2.5s) — never blocks navigation;
/// * skippable: any tap dismisses immediately;
/// * reduce-motion: NO overlay at all — a plain text snackbar instead;
/// * never used on EMERGENCY-adjacent flows (call sites are referral claim
///   and the paywall purchase result; the guard test keeps motion off the
///   emergency tree).
Future<void> showCelebration(
  BuildContext context, {
  required String motionAsset,
  required String fallbackAsset,
  required String message,
  Duration duration = const Duration(milliseconds: 2200),
}) async {
  assert(duration <= const Duration(milliseconds: 2500),
      'celebrations must stay ≤2.5s (roadmap M3 acceptance)');

  if (reduceMotion(context)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  // Auto-dismiss within budget; canceled if the user tap-skips first.
  final autoDismiss = Timer(duration, () {
    if (navigator.mounted) navigator.maybePop();
  });
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: message,
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(dialogContext).maybePop(), // tap = skip
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMotionAsset(
              motionAsset,
              fallbackAsset: fallbackAsset,
              oneShot: true,
              height: 220,
              fallback: const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  autoDismiss.cancel();
}

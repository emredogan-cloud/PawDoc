import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/user_profile.dart';
import '../analytics/analytics.dart';
import '../monetization/paywall_screen.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pet_limits.dart';
import 'pets_repository.dart';

/// Single entry point for "Add pet", used by both the home switcher and the
/// "My pets" screen. Enforces the tier limit (Free/Premium = 2, Family =
/// unlimited) BEFORE opening the form, and fires `multi_pet_added` once the user
/// has more than one pet. The limit is read from the user's profile; an unknown/
/// loading status is treated as free (most restrictive), so we never over-grant.
Future<void> startAddPetFlow(BuildContext context, WidgetRef ref) async {
  final pets = ref.read(petsListProvider).maybeWhen(
        data: (list) => list,
        orElse: () => const <Pet>[],
      );
  final status = ref.read(userProfileProvider).maybeWhen(
        data: (p) => p.subscriptionStatus,
        orElse: () => 'free',
      );

  if (!canAddPet(status, pets.length)) {
    final upgrade = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pet limit reached'),
        content: const Text(
          'Your plan includes up to 2 pets. Upgrade to Family for unlimited pets.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(
            key: const Key('pet_limit_upgrade'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
    if (upgrade == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
    }
    return;
  }

  final added = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const PetFormScreen()),
  );
  if (added == true) {
    ref.invalidate(petsListProvider);
    final newCount = pets.length + 1;
    if (newCount > 1) await Analytics.multiPetAdded(newCount);
  }
}

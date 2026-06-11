import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/user_profile.dart';
import '../core/app_motion_asset.dart';
import '../core/motion.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import 'family_repository.dart';
import 'invite_family_member_screen.dart';

/// Phase 6.3.1 — manage the caller's family group.
///
/// Lists the current members of the user's owned family group; the "Invite
/// member" CTA is gated on the family / b2b_lite tiers (server also enforces).
class FamilySettingsScreen extends ConsumerWidget {
  const FamilySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final summary = ref.watch(familySummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Family sharing')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          ref.invalidate(familySummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load family: $e'),
              data: (s) => _FamilyHeader(summary: s),
            ),
            const SizedBox(height: 16),
            summary.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (s) => _MembersList(summary: s),
            ),
            const SizedBox(height: 16),
            profile.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (p) {
                final canInvite = const {'family', 'b2b_lite'}
                    .contains(p.subscriptionStatus);
                if (!canInvite) {
                  // Tier gate (client-side affordance). Server also enforces.
                  return Card(
                    key: const Key('family_invite_paywall_card'),
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Family sharing is a Premium feature'),
                      // De-jargonized (was "B2B-Lite (sitter)") for consumers.
                      subtitle: const Text(
                          'Invite up to 5 people on Premium Family. '
                          'Sitters get access too.'),
                      trailing: FilledButton(
                        key: const Key('family_invite_upgrade_button'),
                        onPressed: () => context.push('/onboarding'), // existing upgrade path
                        child: const Text('Upgrade'),
                      ),
                    ),
                  );
                }
                return FilledButton.icon(
                  key: const Key('family_invite_button'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InviteFamilyMemberScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Invite a household member'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({required this.summary});
  final FamilySummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (summary == null) {
      return Text('No family group yet.', style: t.bodyLarge);
    }
    final s = summary!;
    final size = s.members.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your care circle', style: t.titleLarge),
        const SizedBox(height: AppSpace.s4),
        Text(size == 1
            ? 'It’s just you for now — invite family or a sitter so everyone can help care for your pets.'
            : '$size members'),
        if (size == 1) ...[
          const SizedBox(height: AppSpace.s16),
          Center(
            // M1 (A5): the circle breathes as one + sparkle drift; static PNG
            // under reduce-motion / load failure.
            child: AppMotionAsset(
              AppMotionAssets.familyCircleLoop,
              fallbackAsset: AppAssets.familyCircle,
              height: 120,
              fallback: Icon(Icons.groups_rounded, size: 72, color: scheme.primary),
            ),
          ),
        ],
      ],
    );
  }
}

class _MembersList extends StatefulWidget {
  const _MembersList({required this.summary});
  final FamilySummary? summary;

  @override
  State<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<_MembersList> {
  /// Member ids already shown — tiles for ids that appear LATER (an invite
  /// accepted while the screen is up / after a refresh) slide in (M3 #19).
  /// Initialized on first build so opening the screen never animates.
  Set<String>? _seen;

  // Friendly display name from an email's local part (avoids leading with PII).
  static String _memberName(String? email) {
    if (email == null || email.isEmpty) return 'Member';
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    if (summary == null || summary.members.isEmpty) {
      return const SizedBox.shrink();
    }
    final ids = {for (final m in summary.members) m.userId};
    final previous = _seen;
    _seen = ids;
    final animateNew = previous != null && !reduceMotion(context);

    return Card(
      child: Column(
        children: [
          for (final m in summary.members)
            if (animateNew && !previous.contains(m.userId))
              // M3 (#19): the new member's tile slides in — one 800ms beat.
              _tile(m)
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 400))
                  .slideX(
                      begin: 0.15,
                      end: 0,
                      duration: const Duration(milliseconds: 400),
                      curve: AppMotion.emphasized)
                  .then()
                  .shimmer(duration: const Duration(milliseconds: 400))
            else
              _tile(m),
        ],
      ),
    );
  }

  Widget _tile(FamilyMember m) => ListTile(
        key: Key('family_member_${m.userId}'),
        leading: CircleAvatar(
          child: Icon(m.role == 'owner'
              ? Icons.workspace_premium_outlined
              : Icons.person_outline),
        ),
        // Display name over the raw email (PII restraint, §3.9.1).
        title: Text(_memberName(m.email)),
        subtitle: Text(m.role == 'owner' ? 'Owner' : 'Member'),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/user_profile.dart';
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
                      title: const Text('Family Sharing is on the Family plan'),
                      subtitle: const Text(
                          'Upgrade to invite up to 5 household members. '
                          'B2B-Lite (sitter) also unlocks Family Sharing.'),
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
    if (summary == null) {
      return Text('No family group yet.', style: t.bodyLarge);
    }
    final s = summary!;
    final size = s.members.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.groupName, style: t.titleLarge),
        const SizedBox(height: 4),
        Text(size == 1
            ? 'Just you — invite someone to start sharing.'
            : '$size members'),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.summary});
  final FamilySummary? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null || summary!.members.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Column(
        children: [
          for (final m in summary!.members)
            ListTile(
              key: Key('family_member_${m.userId}'),
              leading: CircleAvatar(
                child: Icon(m.role == 'owner'
                    ? Icons.workspace_premium_outlined
                    : Icons.person_outline),
              ),
              title: Text(m.email ?? '(no email)'),
              subtitle: Text(m.role == 'owner' ? 'Owner' : 'Member'),
            ),
        ],
      ),
    );
  }
}

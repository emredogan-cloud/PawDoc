import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // E9 manual-invite context.push (E12 dropped it as unused)

import '../account/user_profile.dart';
import '../core/app_image.dart';
import '../core/motion.dart';
import '../monetization/paywall_screen.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'family_repository.dart';
import 'invite_family_member_screen.dart';
import 'invite_token.dart';

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
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Family sharing',
            style: TextStyle(
              color: AppColors.ink50,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.ink50),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userProfileProvider);
            ref.invalidate(familySummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s8,
            ),
            children: [
              // ── Hero headline + illustration ──
              _HeroSection(),
              const SizedBox(height: AppSpace.s16),

              // ── Family header / owner card ──
              summary.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: PawPalette.mint,
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  'Could not load family: $e',
                  style: const TextStyle(color: AppColors.ink300),
                ),
                data: (s) => _FamilyHeader(summary: s),
              ),
              const SizedBox(height: AppSpace.s12),

              // ── Premium paywall / invite CTA ──
              profile.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (p) {
                  final canInvite = const {'family', 'b2b_lite'}
                      .contains(p.subscriptionStatus);
                  if (!canInvite) {
                    return _PaywallCard();
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: AppSpace.s20),

              // ── "Your care circle" section ──
              Text(
                'Your care circle',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink50,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpace.s12),

              // Members list (existing logic, restyled)
              summary.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (s) => _MembersList(summary: s),
              ),

              // Invite CTA (premium-gated)
              profile.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (p) {
                  final canInvite = const {'family', 'b2b_lite'}
                      .contains(p.subscriptionStatus);
                  if (canInvite) {
                    return Column(
                      children: [
                        PawFeatureRow(
                          key: const Key('family_invite_button'),
                          icon: Icons.person_add_alt_1,
                          title: 'Invite family or sitters',
                          subtitle: "They'll be able to view your pets and help with care.",
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.ink300,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const InviteFamilyMemberScreen(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  // Non-premium: show locked invite row
                  return PawFeatureRow(
                    icon: Icons.person_add_alt_1,
                    title: 'Invite family or sitters',
                    subtitle: "They'll be able to view your pets and help with care.",
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.ink300,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen())),
                  );
                },
              ),
              const SizedBox(height: AppSpace.s12),

              // GAP-E9: manual fallback when the invite deep link didn't open
              // the app (link copied from a message / a different browser).
              const SizedBox(height: AppSpace.s8),
              TextButton.icon(
                key: const Key('manual_invite_entry'),
                onPressed: () => _enterInviteManually(context),
                icon: const Icon(Icons.link),
                label: const Text('Have an invite link? Enter it'),
              ),
              // Bottom hint
              _BottomHint(),
              const SizedBox(height: AppSpace.s32),
            ],
          ),
        ),
      ),
    );
  }

  /// GAP-E9: paste-an-invite fallback. Parses a pasted link or bare token and
  /// routes to the existing accept screen (`/invite/:token`), which confirms
  /// and calls accept-family-invite (idempotent).
  Future<void> _enterInviteManually(BuildContext context) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Enter invite link'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paste the invite link or code you were sent.'),
                const SizedBox(height: AppSpace.s12),
                TextField(
                  key: const Key('manual_invite_field'),
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Invite link or code',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                key: const Key('manual_invite_join'),
                onPressed: () {
                  final parsed = parseInviteToken(controller.text);
                  if (parsed == null) {
                    setLocal(() =>
                        error = 'That doesn’t look like a valid invite link.');
                    return;
                  }
                  Navigator.pop(ctx, parsed);
                },
                child: const Text('Join'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (token != null && context.mounted) {
      context.push('/invite/$token');
    }
  }
}

// ── Hero section: headline + tagline + illustration ──────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.s8),
        Text(
          'Care is better\ntogether',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.ink50,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'Invite your family or sitter\nto help care for your pets.\nEveryone stays in the loop.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink300,
              ),
        ),
        const SizedBox(height: AppSpace.s16),
        Center(
          child: AppImage(
            AppAssets.familyCircle,
            height: 150,
            fallback: const Icon(
              Icons.group_rounded,
              size: 72,
              color: PawPalette.mint,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Family header (owner card + member count) ─────────────────────────────────

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({required this.summary});
  final FamilySummary? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return Text(
        'No family group yet.',
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: AppColors.ink300),
      );
    }
    final s = summary!;
    // Find owner member if present
    final owner = s.members.isNotEmpty
        ? s.members.firstWhere(
            (m) => m.role == 'owner',
            orElse: () => s.members.first,
          )
        : null;
    if (owner == null) return const SizedBox.shrink();

    final displayName = _memberName(owner.email);

    return PawCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PawPalette.teal.withValues(alpha: 0.22),
              border: Border.all(
                color: PawPalette.mint.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: PawPalette.mint,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink50,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: PawPalette.teal.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: PawPalette.mint.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Owner',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: PawPalette.mint,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'You have full access and control',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink300,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _memberName(String? email) {
    if (email == null || email.isEmpty) return 'Member';
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }
}

// ── Premium paywall card ───────────────────────────────────────────────────────

class _PaywallCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PawCard(
      key: const Key('family_invite_paywall_card'),
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PawPalette.teal.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: PawPalette.mint,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family sharing is a Premium feature',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink50,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // De-jargonized (was "B2B-Lite (sitter)") for consumers.
                      'Invite up to 5 people on Premium Family. '
                      'Sitters get access too.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink300,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          // Benefits grid — 4 mini feature icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _BenefitChip(
                icon: Icons.people_outline_rounded,
                label: 'Up to 5\npeople',
              ),
              _BenefitChip(
                icon: Icons.visibility_outlined,
                label: 'View & help\nEveryone stays\nin the loop.',
              ),
              _BenefitChip(
                icon: Icons.notifications_outlined,
                label: 'Reminders\nShared care\nreminders',
              ),
              _BenefitChip(
                icon: Icons.shield_outlined,
                label: 'Secure access\nYou stay in\nfull control',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          // Upgrade CTA
          SizedBox(
            width: double.infinity,
            child: PawPrimaryButton(
              key: const Key('family_invite_upgrade_button'),
              onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen())), // existing upgrade path
              icon: Icons.workspace_premium_outlined,
              child: const Text('Upgrade'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Only the first line of label is the short description shown in mockup
    final short = label.split('\n').first;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PawPalette.teal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 20, color: PawPalette.mint),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          short,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.ink300,
                fontSize: 10,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Members list ──────────────────────────────────────────────────────────────

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

    return Column(
      children: [
        for (final m in summary.members)
          if (animateNew && !previous.contains(m.userId))
            // M3 (#19): the new member's tile slides in — one 800ms beat.
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: _tile(m),
            )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 400))
                .slideX(
                  begin: 0.15,
                  end: 0,
                  duration: const Duration(milliseconds: 400),
                  curve: AppMotion.emphasized,
                )
                .then()
                .shimmer(duration: const Duration(milliseconds: 400))
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: _tile(m),
            ),
      ],
    );
  }

  Widget _tile(FamilyMember m) {
    final isOwner = m.role == 'owner';
    return PawCard(
      key: Key('family_member_${m.userId}'),
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PawPalette.teal.withValues(alpha: 0.18),
            ),
            child: Icon(
              isOwner
                  ? Icons.workspace_premium_outlined
                  : Icons.person_outline_rounded,
              size: 20,
              color: PawPalette.mint,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display name over the raw email (PII restraint, §3.9.1).
                Text(
                  _memberName(m.email),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink50,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  isOwner ? 'Owner' : 'Member',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink300,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom hint ───────────────────────────────────────────────────────────────

class _BottomHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: AppColors.ink300,
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'You can add or remove members anytime. ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink300,
                      ),
                ),
                TextSpan(
                  text: 'Learn more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PawPalette.mint,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

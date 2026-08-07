import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import '../theme/paw_components.dart';
import 'community_home_screen.dart';
import 'community_onboarding_screen.dart';
import 'community_repository.dart';

/// Home entry for Paw Community: an opt-in invitation until the user joins,
/// then a shortcut into the hub. Membership == profile row (RLS-scoped read).
class CommunityCard extends ConsumerWidget {
  const CommunityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final membership = ref.watch(myCommunityProfileProvider);
    return membership.when(
      // Quiet while loading/unreachable — the Home feed never blocks on it.
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) {
          return PawCard(
            key: const Key('community_card_invite'),
            onTap: () async {
              final joined = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => const CommunityOnboardingScreen()),
              );
              if (joined == true && context.mounted) {
                ref.invalidate(myCommunityProfileProvider);
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const CommunityHomeScreen()));
              }
            },
            // Home now lays this out in a ~170dp column (mockup 010): beside a
            // 32dp glyph and a chevron the copy has nowhere to go, so below a
            // comfortable width the glyph moves above the text.
            child: LayoutBuilder(builder: (context, c) {
              final glyph = Icon(Icons.groups_2_outlined,
                  color: PawTone.of(context).accent, size: 32);
              final title = Text('Paw Community',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: AppColors.ink50));
              final body = Text(
                'Meet pet owners nearby, chat, and plan walks. '
                'Opt-in only — you choose what to share.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.ink300),
              );
              const chevron = Icon(Icons.chevron_right_rounded,
                  color: AppColors.ink300);
              if (c.maxWidth < 260) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [glyph, const Spacer(), chevron]),
                    const SizedBox(height: AppSpace.s8),
                    title,
                    const SizedBox(height: 2),
                    body,
                  ],
                );
              }
              return Row(
                children: [
                  glyph,
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 2), body],
                    ),
                  ),
                  chevron,
                ],
              );
            }),
          );
        }
        return PawCard(
          key: const Key('community_card_member'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const CommunityHomeScreen())),
          child: Row(
            children: [
              Icon(Icons.groups_2_rounded,
                  color: PawTone.of(context).accent, size: 32),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paw Community',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: AppColors.ink50)),
                    const SizedBox(height: 2),
                    Text('Requests, connections, and walks near you.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.ink300)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
            ],
          ),
        );
      },
    );
  }
}

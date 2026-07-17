import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_urls.dart';

import '../auth/auth_controller.dart';
import '../auth/supabase_providers.dart';
import '../monetization/paywall_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'delete_account_screen.dart';
import 'user_profile.dart';

/// Consolidated account home (roadmap §3.10.2): profile, subscription, family,
/// notifications, language, legal, **Logout (moved here, with a
/// confirm)**, and a danger-zone Delete. Replaces the scattered AppBar/overflow
/// actions. No auth/subscription logic changes — navigation + consolidation only.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _openLegal(String path) async {
    try {
      await launchUrl(Uri.parse('${LegalUrls.base}/$path'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (yes == true) {
      // Auth-state change triggers the router redirect to /sign-in.
      await ref.read(authControllerProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final email = ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';
    final profile = ref.watch(userProfileProvider);

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        children: [
          // Profile header.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s8),
            child: PawCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: PawPalette.teal.withValues(alpha: 0.18),
                    child:
                        const Icon(Icons.person_rounded, color: PawPalette.mint),
                  ),
                  const SizedBox(width: AppSpace.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email.isEmpty ? 'Signed in' : email,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.ink50)),
                        profile.maybeWhen(
                          data: (p) => Text(
                            p.isPremium
                                ? 'Premium'
                                : 'Free plan · ${p.freeRemaining} of 3 free checks left',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.ink300),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subscription.
          profile.maybeWhen(
            data: (p) => _Tile(
              icon: Icons.workspace_premium_outlined,
              title: p.isPremium ? 'Premium — manage' : 'Upgrade to Premium',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              ),
            ),
            orElse: () => const _Tile(
                icon: Icons.workspace_premium_outlined, title: 'Subscription'),
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage in system settings',
            onTap: openAppSettings,
          ),
          const _Tile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'English / Deutsch — follows your device',
          ),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _openLegal('privacy'),
          ),
          _Tile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _openLegal('terms'),
          ),
          _Tile(
            icon: Icons.smart_toy_outlined,
            title: 'AI Transparency',
            onTap: () => _openLegal('ai-transparency'),
          ),
          _Tile(
            icon: Icons.mail_outline_rounded,
            title: 'Contact & Legal',
            onTap: () => _openLegal('contact'),
          ),
          _Tile(
            key: const Key('account_sign_out'),
            icon: Icons.logout,
            title: 'Sign out',
            onTap: () => _confirmSignOut(context, ref),
          ),

          // Danger zone.
          const SizedBox(height: AppSpace.s24),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s20, 0, AppSpace.s20, AppSpace.s8),
            child: Text('Danger zone',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.error)),
          ),
          _Tile(
            key: const Key('account_delete'),
            icon: Icons.delete_outline,
            iconColor: scheme.error,
            title: 'Delete account',
            titleColor: scheme.error,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
            ),
          ),
          const SizedBox(height: AppSpace.s24),
        ],
      ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final tColor = titleColor ?? AppColors.ink50;
    final iColor = iconColor ?? PawPalette.mint;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16, vertical: AppSpace.s4),
      child: PawCard(
        onTap: onTap,
        radius: AppRadius.md,
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: iColor),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: tColor)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.ink300)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
          ],
        ),
      ),
    );
  }
}

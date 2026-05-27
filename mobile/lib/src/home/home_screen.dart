import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/supabase_providers.dart';

/// Minimal signed-in landing screen. The real home (pet card, "Check [Pet]"
/// CTA, query counter) is built in Phase 1.4; this proves the auth-gated route.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final email = session?.user.email ?? 'your account';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PawDoc'),
        actions: [
          IconButton(
            key: const Key('sign_out_button'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, size: 64),
              const SizedBox(height: 16),
              Text(
                'Signed in as $email',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pet setup and your first health check arrive in the next build.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

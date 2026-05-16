/// Minimal settings — Phase 1C ships sign-out. App version, locale, and
/// account management land in Phase 2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text('PawDoc · v0.1.0', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

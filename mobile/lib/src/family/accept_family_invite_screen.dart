import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics.dart';
import '../auth/supabase_providers.dart';
import '../pets/pets_repository.dart';
import '../theme/design_tokens.dart';
import 'family_repository.dart';

/// Phase 6.3.1 — landing screen for the family invite deep link
/// (`/invite/:token`). Asks the user to confirm joining and calls the
/// /accept-family-invite Edge Function. Idempotent on retries.
class AcceptFamilyInviteScreen extends ConsumerStatefulWidget {
  const AcceptFamilyInviteScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<AcceptFamilyInviteScreen> createState() => _AcceptFamilyInviteScreenState();
}

class _AcceptFamilyInviteScreenState extends ConsumerState<AcceptFamilyInviteScreen> {
  bool _busy = false;
  String? _error;
  String? _groupName;
  bool _accepted = false;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resp = await ref.read(familyRepositoryProvider).acceptInvite(widget.token);
      await Analytics.familyInviteAccepted();
      if (!mounted) return;
      // Refresh the active pet list — joining the family unlocks the
      // inviter's pets via the new RLS policies (Phase 6.3).
      ref.invalidate(petsListProvider);
      setState(() {
        _accepted = true;
        _groupName = resp['group_name'] as String?;
        _busy = false;
      });
    } on FamilyInviteException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not accept the invite. Please try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the user isn't signed in yet, go_router's auth redirect will have
    // routed them to /sign-in. After sign-in, they're returned here.
    final session = ref.watch(supabaseClientProvider).auth.currentSession;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to accept the invite.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Join a family')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.family_restroom, size: 64),
              const SizedBox(height: 16),
              if (_accepted) ...[
                Text(
                  'You’re in${_groupName == null ? '' : ' — ${_groupName!}'} 🎉',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can now see + log on the shared pets in this household.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('family_invite_done'),
                  onPressed: () => context.go('/'),
                  child: const Text('Done'),
                ),
              ] else ...[
                Text(
                  'You’ve been invited to a PawDoc household.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Joining lets the household see your pets and yours theirs. '
                  'Only the original owner of each pet can edit / delete its '
                  'profile — you can log events, run analyses, and view '
                  'history. You can leave any time.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  key: const Key('family_invite_accept'),
                  onPressed: _busy ? null : _accept,
                  child: Text(_busy ? 'Joining…' : 'Join the household'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('family_invite_skip'),
                  onPressed: _busy ? null : () => context.go('/'),
                  child: const Text('Not now'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

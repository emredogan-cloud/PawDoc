import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_service.dart';

/// In-app account deletion (CR #9 / Apple 5.1.1(v)). Clear, requires an explicit
/// typed confirmation, and permanently removes all data via the cascade.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed => _controller.text.trim().toUpperCase() == 'DELETE';

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountServiceProvider).deleteAccount();
      // Sign-out triggers the router redirect to /sign-in; nothing more to do.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the account. Please try again.')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Semantics(
            header: true,
            child: Text('This permanently deletes your account',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your pets, analyses, history, reminders, and subscription record will be '
            'permanently removed. This cannot be undone.',
          ),
          const SizedBox(height: 24),
          Semantics(
            textField: true,
            label: 'Type the word DELETE to confirm account deletion',
            child: TextField(
              key: const Key('delete_confirm_field'),
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type DELETE to confirm',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: 'Permanently delete my account',
            child: FilledButton(
              key: const Key('delete_account_button'),
              style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
              onPressed: (_confirmed && !_busy) ? _delete : null,
              child: Text(_busy ? 'Deleting…' : 'Delete my account'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

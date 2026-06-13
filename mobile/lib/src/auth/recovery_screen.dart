import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/design_tokens.dart';
import 'auth_controller.dart';

/// GAP-E1: set a new password after following a reset link. Reached when the
/// PASSWORD_RECOVERY auth event fires — the deep link opened the app into a
/// short-lived recovery session, and the router sends the user here.
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).updatePassword(_password.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated — you’re signed in.')),
        );
        context.go('/');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = "Couldn't update your password. Try the reset link again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpace.maxContentWidth),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Choose a new password for your account.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpace.s16),
                  TextFormField(
                    key: const Key('recovery_password_field'),
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                        labelText: 'New password', filled: true),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'At least 8 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: AppSpace.s16),
                  FilledButton(
                    key: const Key('recovery_submit_button'),
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Saving…' : 'Update password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

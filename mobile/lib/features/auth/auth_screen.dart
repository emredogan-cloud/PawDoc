/// Email-entry screen. The single field accepts an email, the controller
/// dispatches the OTP request, and on success we navigate to /auth/verify.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/services/analytics_events.dart';
import '../../shared/services/apple_signin_service.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen<AuthScreenState>(authControllerProvider, (_, next) {
      if (next is CodeSent) {
        context.go('/auth/verify', extra: next.email);
      }
    });

    final theme = Theme.of(context);
    final isLoading = state is AuthSending;
    final error = state is AuthFailed ? state.message : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.pets_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                  semanticLabel: 'PawDoc',
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to PawDoc',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We'll email you a 6-digit code to sign in.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  enabled: !isLoading,
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send code'),
                ),
                if (ref.watch(appleSignInServiceProvider).isSupported) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: theme.colorScheme.outlineVariant),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: theme.colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final svc = ref.read(appleSignInServiceProvider);
                            final outcome = await svc.signIn();
                            if (outcome.success) {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .notifyAuthCompleted(AuthMethod.apple);
                            } else if (outcome.error != null) {
                              // userCancelled has an empty message — skip.
                              if (outcome.error!.userMessage.isNotEmpty) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(outcome.error!.userMessage),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'By continuing you accept our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final email = _emailCtrl.text;
    ref.read(authControllerProvider.notifier).sendOtp(email);
  }
}

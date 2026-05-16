/// OTP entry screen. The previous screen navigates here with the email
/// address in `extra`. We dispatch verify on submit.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isVerifying = state is AuthVerifying;
    final error = state is AuthFailed ? state.message : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(authControllerProvider.notifier).reset();
            context.go('/auth');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Enter the 6-digit code',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sent to ${widget.email}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                autofocus: true,
                autofillHints: const [AutofillHints.oneTimeCode],
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 6,
                ),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '••••••',
                  border: OutlineInputBorder(),
                ),
                enabled: !isVerifying,
                onSubmitted: (_) => _verify(),
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
                onPressed: isVerifying ? null : _verify,
                child: isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isVerifying
                    ? null
                    : () => ref
                          .read(authControllerProvider.notifier)
                          .sendOtp(widget.email),
                child: const Text('Resend code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verify() {
    ref
        .read(authControllerProvider.notifier)
        .verifyOtp(email: widget.email, code: _codeCtrl.text);
  }
}

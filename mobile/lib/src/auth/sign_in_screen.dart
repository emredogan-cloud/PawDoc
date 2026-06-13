import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_motion_asset.dart';
import '../core/motion.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import 'auth_controller.dart';

/// Email + Apple sign-in. Auth providers are read lazily in callbacks (not in
/// build) so the screen can render in tests without an initialized backend.
///
/// Phase E restyle (§3.1): brand lockup fills the dead top third, fields become
/// Material 3 filled with floating labels, auth errors surface as a calm inline
/// banner (not a bottom snackbar), and an honest trust footer (encryption +
/// Privacy/Terms) anchors credibility — no fabricated claims. Apple + Supabase
/// auth logic, the validators, and all widget keys are unchanged.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AuthController) action) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null; // clear on retry
    });
    try {
      await action(ref.read(authControllerProvider));
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // GAP-E3: native Sign in with Apple only works on iOS/macOS. Elsewhere the
  // button is a dead, misleading control, so it's hidden.
  bool get _appleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _appleSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).signInWithApple();
    } catch (_) {
      _showError('Apple sign-in was cancelled or failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Calm inline banner (replaces the bottom snackbar from runtime R07).
  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  Future<void> _openLegal(String path) async {
    try {
      await launchUrl(Uri.parse('https://pawdoc.app/$path'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpace.maxContentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpace.s32),
                    _brandLockup(),
                    const SizedBox(height: AppSpace.s32),
                    Text(
                      'Know when to call the vet.',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Calm, vet-informed triage for your pet — in seconds.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.s24),
                    TextFormField(
                      key: const Key('email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        filled: true,
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: AppSpace.s12),
                    TextFormField(
                      key: const Key('password_field'),
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        filled: true,
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'At least 8 characters' : null,
                    ),
                    const SizedBox(height: AppSpace.s16),
                    if (_error != null) _errorBanner(_error!),
                    AppButton(
                      key: const Key('sign_in_button'),
                      onPressed: _busy
                          ? null
                          : () => _run((c) => c.signInWithEmail(
                              _emailController.text.trim(), _passwordController.text)),
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    OutlinedButton(
                      key: const Key('sign_up_button'),
                      onPressed: _busy
                          ? null
                          : () => _run((c) => c.signUpWithEmail(
                              _emailController.text.trim(), _passwordController.text)),
                      child: const Text('Create account'),
                    ),
                    // GAP-E3: native Sign in with Apple is iOS/macOS only —
                    // hide the divider + button on platforms where it can't work.
                    if (_appleAvailable) ...[
                      const SizedBox(height: AppSpace.s24),
                      const Row(children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpace.s8),
                          child: Text('or'),
                        ),
                        Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: AppSpace.s16),
                      OutlinedButton.icon(
                        key: const Key('apple_sign_in_button'),
                        onPressed: _busy ? null : _appleSignIn,
                        icon: const Icon(Icons.apple),
                        label: const Text('Continue with Apple'),
                      ),
                    ],
                    const SizedBox(height: AppSpace.s32),
                    _trustFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandLockup() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // M1 (A3): one-shot heartbeat — the ECG line draws across the shield
        // once on build, then holds. NEVER loops (trust surface).
        AppMotionAsset(
          AppMotionAssets.signinHeartbeat,
          fallbackAsset: AppAssets.logoMark,
          oneShot: true,
          height: 72,
          semanticLabel: 'PawDoc',
          fallback: CircleAvatar(
            radius: 36,
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.pets_rounded, size: 36, color: scheme.primary),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Text('PawDoc', style: Theme.of(context).textTheme.displaySmall),
      ],
    );
  }

  Widget _errorBanner(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: scheme.onErrorContainer),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _trustFooter() {
    final scheme = Theme.of(context).colorScheme;
    final secondary = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpace.s4),
            Text('Your data is encrypted.', style: secondary),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _openLegal('privacy'),
              child: const Text('Privacy'),
            ),
            Text('·', style: secondary),
            TextButton(
              onPressed: () => _openLegal('terms'),
              child: const Text('Terms'),
            ),
          ],
        ),
      ],
    );
  }
}

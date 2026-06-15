import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_urls.dart';

import '../core/app_image.dart';
import '../core/app_motion_asset.dart';
import '../theme/app_assets.dart';
import '../theme/app_theme.dart';
import '../theme/paw_ui.dart';
import 'auth_controller.dart';

/// Email + Apple sign-in. Auth providers are read lazily in callbacks (not in
/// build) so the screen can render in tests without an initialized backend.
///
/// NEW-UI translation (001): the login is the one cream/light screen in the new
/// design — a warm hero (brand mark + headline + cuddle-duo) over a white form
/// sheet, an honest "your data is encrypted" trust card, and Privacy/Terms.
/// Apple + Supabase auth logic, the validators, and ALL widget keys
/// (`email_field`, `password_field`, `sign_in_button`, `sign_up_button`,
/// `apple_sign_in_button`) are unchanged.
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
  bool _obscure = true;
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

  /// GAP-E1: send a password-reset link. Initiation only — the email delivery
  /// needs SMTP (founder); the recovery deep link drives the set-new-password
  /// screen. Feedback is neutral ("if an account exists…") to avoid disclosing
  /// whether an email is registered.
  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          key: const Key('reset_email_field'),
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            key: const Key('reset_send_button'),
            onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await ref.read(authControllerProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('If an account exists, a reset link is on its way.'),
        ));
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError("Couldn't send a reset link. Please try again.");
    }
  }

  Future<void> _openLegal(String path) async {
    try {
      await launchUrl(Uri.parse('${LegalUrls.base}/$path'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Login is the single cream/light surface; wrap content in the light theme
    // so fields/text render correctly on cream (the dark app theme is untouched
    // everywhere else).
    return Theme(
      data: AppTheme.light(),
      child: PawScaffold(
        variant: PawSurface.cream,
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpace.maxContentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpace.s16),
                    _hero(),
                    const SizedBox(height: AppSpace.s12),
                    _formSheet(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
      child: Column(
        children: [
          // M1 (A3): one-shot heartbeat — the ECG draws across the shield once
          // then holds as a static mark (matches the static 001 reference).
          AppMotionAsset(
            AppMotionAssets.signinHeartbeat,
            fallbackAsset: AppAssets.logoMark,
            oneShot: true,
            height: 56,
            semanticLabel: 'PawDoc',
            fallback: const Icon(Icons.pets_rounded,
                size: 48, color: PawPalette.forestInk),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'PawDoc',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: PawPalette.forestInk,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpace.s8),
          Text.rich(
            TextSpan(children: const [
              TextSpan(text: 'Know when to '),
              TextSpan(
                text: 'call the vet.',
                style: TextStyle(color: PawPalette.teal),
              ),
            ]),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: PawPalette.forestInk,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Calm, vet-informed triage for your pet — in seconds.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: PawPalette.forestBody),
          ),
          const SizedBox(height: AppSpace.s16),
          AppImage(
            AppAssets.onbDuoContent,
            height: 104,
            fallback: const Icon(Icons.pets_rounded,
                size: 88, color: PawPalette.teal),
          ),
        ],
      ),
    );
  }

  Widget _formSheet() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s20, AppSpace.s24, AppSpace.s20, AppSpace.s24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('email_field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: _fieldDecoration(
              label: 'Email',
              icon: Icons.mail_outline_rounded,
            ),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: AppSpace.s12),
          TextFormField(
            key: const Key('password_field'),
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: _fieldDecoration(
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: PawPalette.forestBody,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 8) ? 'At least 8 characters' : null,
          ),
          const SizedBox(height: AppSpace.s16),
          if (_error != null) _errorBanner(_error!),
          PawPrimaryButton(
            key: const Key('sign_in_button'),
            variant: PawSurface.cream,
            icon: Icons.pets_rounded,
            onPressed: _busy
                ? null
                : () => _run((c) => c.signInWithEmail(
                    _emailController.text.trim(), _passwordController.text)),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Sign in'),
          ),
          // GAP-E1: forgot-password entry (initiation only; SMTP is founder).
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('forgot_password_button'),
              onPressed: _busy ? null : _forgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          const _OrDivider(),
          const SizedBox(height: AppSpace.s12),
          PawSecondaryButton(
            key: const Key('sign_up_button'),
            variant: PawSurface.cream,
            icon: Icons.pets_outlined,
            onPressed: _busy
                ? null
                : () => _run((c) => c.signUpWithEmail(
                    _emailController.text.trim(), _passwordController.text)),
            child: const Text('Create account'),
          ),
          // GAP-E3: native Apple sign-in is iOS/macOS only — hide it elsewhere.
          if (_appleAvailable) ...[
            const SizedBox(height: AppSpace.s8),
            PawSecondaryButton(
              key: const Key('apple_sign_in_button'),
              variant: PawSurface.cream,
              icon: Icons.apple,
              onPressed: _busy ? null : _appleSignIn,
              child: const Text('Continue with Apple'),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          _encryptionCard(),
          const SizedBox(height: AppSpace.s8),
          _legalLinks(),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF4F1EA),
      prefixIcon: Icon(icon, color: PawPalette.forestBody),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
            color: PawPalette.forestInk.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: PawPalette.teal, width: 1.5),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: AppColors.emergencyLight.withValues(alpha: 0.10),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 20, color: AppColors.emergencyLight),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(message,
                  style: const TextStyle(color: AppColors.emergencyLight)),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.emergencyLight),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _encryptionCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: PawPalette.mint.withValues(alpha: 0.16),
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 22, color: PawPalette.teal),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your data is encrypted.',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: PawPalette.forestInk)),
                Text("We keep your pet's info safe.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PawPalette.forestBody)),
              ],
            ),
          ),
          AppImage(
            AppAssets.trustSleepingDuo,
            height: 44,
            fallback: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _legalLinks() {
    final secondary = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: PawPalette.forestBody);
    return Row(
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
    );
  }
}

/// "or" divider with hairlines on the cream form sheet.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: PawPalette.forestInk.withValues(alpha: 0.12)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
          child: Text('or',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: PawPalette.forestBody)),
        ),
        line,
      ],
    );
  }
}

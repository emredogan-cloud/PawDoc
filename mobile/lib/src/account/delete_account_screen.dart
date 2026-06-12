import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_image.dart';
import '../core/motion.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'account_service.dart';

/// In-app account deletion (CR #9 / Apple 5.1.1(v)). Clear, requires an explicit
/// typed confirmation, and permanently removes all data via the cascade.
///
/// NEW-UI translation (014): dark teal-green world, a "what will be deleted"
/// icon card, and a calm reassurance footer. The destructive button stays a red
/// [FilledButton] with the disarmed→armed scale cue, Cancel is never disabled,
/// and every key + the cascade/pop logic are unchanged (safety-critical).
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
      // Device finding D-6 (live F-1 validation): the router's signed-out
      // redirect happens BENEATH this plain pushed route, so without an
      // explicit pop the screen sits on "Deleting…" forever even though the
      // deletion + local sign-out completed in budget. Pop the pushed stack;
      // the redirected router (sign-in) is what remains.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Delete account'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              header: true,
              child: Text.rich(
                const TextSpan(children: [
                  TextSpan(text: 'This action is '),
                  TextSpan(
                      text: 'permanent',
                      style: TextStyle(color: AppColors.emergencyDark)),
                ]),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.ink50, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your pets, analyses, history, reminders, and subscription record will be '
              'permanently removed. This cannot be undone.',
              style: const TextStyle(color: AppColors.ink300),
            ),
            const SizedBox(height: 20),
            _whatWillBeDeleted(context),
            const SizedBox(height: 24),
            Semantics(
              textField: true,
              label: 'Type the word DELETE to confirm account deletion',
              child: TextField(
                key: const Key('delete_confirm_field'),
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: AppColors.ink50),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  labelText: 'Type DELETE to confirm',
                  labelStyle: const TextStyle(color: AppColors.ink300),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brMd,
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.brMd,
                    borderSide: BorderSide(color: PawPalette.mint, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Permanently delete my account',
              // Disarmed→armed: a restrained scale cue (no playful motion); the
              // disabled state carries a visible outline + readable text (≥3:1)
              // so it never reads as low-contrast grey-on-grey.
              child: AnimatedScale(
                scale: _confirmed ? 1.0 : 0.98,
                duration: reduceMotion(context) ? Duration.zero : AppMotion.standard,
                curve: AppMotion.standardCurve,
                child: FilledButton(
                  key: const Key('delete_account_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    disabledBackgroundColor: scheme.surfaceContainerHighest,
                    disabledForegroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(color: scheme.outline),
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: (_confirmed && !_busy) ? _delete : null,
                  child: Text(_busy ? 'Deleting…' : 'Delete my account'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // F-1: the escape route is NEVER disabled — even mid-deletion the
            // user can leave (the cascade finishes server-side either way and
            // the auth listener signs the device out when it does).
            TextButton(
              key: const Key('delete_cancel_button'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 24),
            _reassurance(context),
          ],
        ),
      ),
    );
  }

  Widget _whatWillBeDeleted(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.pets_rounded, 'All your pets and their profiles'),
      (Icons.analytics_outlined, 'Analyses, history & reports'),
      (Icons.notifications_outlined, 'Reminders and scheduled alerts'),
      (Icons.settings_outlined, 'Account settings and preferences'),
      (Icons.receipt_long_outlined, 'Subscription and payment records'),
    ];
    return PawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Here's what will be deleted",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.ink50)),
          const SizedBox(height: AppSpace.s12),
          for (final (icon, label) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.emergencyDark),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.ink300)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _reassurance(BuildContext context) {
    return PawCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("We're here if you change your mind",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.ink50)),
                const SizedBox(height: 2),
                Text('Your pets (and we) will miss you. You can come back anytime.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.ink300)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          AppImage(
            AppAssets.trustSleepingDuo,
            height: 48,
            fallback: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

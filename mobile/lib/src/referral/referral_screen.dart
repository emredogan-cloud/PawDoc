import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../account/user_profile.dart';
import '../analytics/analytics.dart';
import '../auth/supabase_providers.dart';
import 'referral_prefs.dart';
import 'referral_service.dart';

/// Referral code + deep-link generation. Reward payout + fraud controls go live
/// in Phase 3.3; here we generate the code and a shareable link.
String referralCodeFromUid(String uid) {
  final compact = uid.replaceAll('-', '').toUpperCase();
  return compact.isEmpty ? 'PAWDOC' : compact.substring(0, compact.length.clamp(0, 8));
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
    final code = referralCodeFromUid(uid);
    final link = 'https://pawdoc.app/r/$code';

    return Scaffold(
      appBar: AppBar(title: const Text('Refer a friend')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Give friends a free start, and earn rewards when they subscribe.'),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                title: const Text('Your referral code'),
                subtitle: Text(code, style: Theme.of(context).textTheme.headlineSmall),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('referral_share'),
              onPressed: () => SharePlus.instance.share(ShareParams(
                text: 'Try PawDoc — AI pet health triage in seconds. $link',
              )),
              icon: const Icon(Icons.share),
              label: const Text('Share invite link'),
            ),
            const SizedBox(height: 8),
            Text(link, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const _ClaimCodeCard(),
          ],
        ),
      ),
    );
  }
}

/// "Got a code from a friend?" — enter it to claim the reward. The claim runs
/// entirely server-side (Edge Function + transactional RPC); this only collects
/// the code, shows progress, and reports the outcome.
class _ClaimCodeCard extends ConsumerStatefulWidget {
  const _ClaimCodeCard();

  @override
  ConsumerState<_ClaimCodeCard> createState() => _ClaimCodeCardState();
}

class _ClaimCodeCardState extends ConsumerState<_ClaimCodeCard> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Prefill a code captured from a referral deep link, if any.
    ReferralPrefs.pending().then((code) {
      if (code != null && code.isNotEmpty && mounted && _controller.text.isEmpty) {
        _controller.text = code;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a referral code first.')));
      return;
    }
    setState(() => _busy = true);
    await Analytics.referralCodeSubmitted();
    final result = await ref.read(referralServiceProvider).claim(code);
    if (!mounted) return;
    if (result.ok) {
      await Analytics.referralSuccess();
      ref.invalidate(userProfileProvider); // reflect the new bonus balance
    } else if (result.isFraud) {
      await Analytics.referralFraudPrevented(result.status);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Got a code from a friend?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('referral_code_input'),
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Referral code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('referral_claim_button'),
          onPressed: _busy ? null : _claim,
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.redeem),
          label: Text(_busy ? 'Claiming…' : 'Claim reward'),
        ),
      ],
    );
  }
}

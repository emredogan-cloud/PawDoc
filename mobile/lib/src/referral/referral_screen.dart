import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/supabase_providers.dart';

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
          ],
        ),
      ),
    );
  }
}

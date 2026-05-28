import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/analytics.dart';
import 'family_repository.dart';

class InviteFamilyMemberScreen extends ConsumerStatefulWidget {
  const InviteFamilyMemberScreen({super.key});

  @override
  ConsumerState<InviteFamilyMemberScreen> createState() => _InviteFamilyMemberScreenState();
}

class _InviteFamilyMemberScreenState extends ConsumerState<InviteFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _inviteLink;
  bool _emailSent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final resp = await ref
          .read(familyRepositoryProvider)
          .sendInvite(_email.text.trim());
      await Analytics.familyInviteSent();
      setState(() {
        _inviteLink = resp['invite_link'] as String?;
        _emailSent = (resp['email_sent'] as bool?) ?? false;
        _busy = false;
      });
    } on FamilyInviteException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _busy = false);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not send the invite. Please try again.'),
      ));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite a household member')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the email of the person you want to share pets with. '
                'They’ll get a link that opens PawDoc — once they accept, '
                'they’ll see and log on your pets too.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('family_invite_email_field'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty || !s.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('family_invite_submit'),
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Sending…' : 'Send invite'),
              ),
              if (_inviteLink != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _emailSent
                              ? 'Invite sent ✉️'
                              : 'Invite created — share the link',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(_inviteLink!),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              key: const Key('family_invite_copy'),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(ClipboardData(text: _inviteLink!));
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Copied to clipboard.')),
                                );
                              },
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copy'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              key: const Key('family_invite_share'),
                              onPressed: () async {
                                await SharePlus.instance.share(
                                  ShareParams(text: _inviteLink!),
                                );
                              },
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Share'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Link expires in 48 hours.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

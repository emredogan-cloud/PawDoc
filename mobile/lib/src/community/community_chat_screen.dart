import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'community_models.dart';
import 'community_repository.dart';

/// 1:1 community chat: live messages (Supabase realtime stream with a manual
/// refresh fallback) + walk proposals merged into one timeline. Report and
/// block live one tap away (Play UGC policy).
class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    super.key,
    required this.connection,
    this.otherProfile,
  });

  final CommunityConnection connection;
  final CommunityProfile? otherProfile;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final _input = TextEditingController();
  StreamSubscription<List<CommunityMessage>>? _sub;
  List<CommunityMessage> _messages = const [];
  List<WalkProposal> _proposals = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final repo = ref.read(communityRepositoryProvider);
    try {
      _proposals = await repo.proposals(widget.connection.id);
    } catch (_) {}
    try {
      _sub = repo.messagesStream(widget.connection.id).listen(
        (messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
              _loading = false;
            });
          }
        },
        onError: (_) => _fallbackLoad(),
      );
    } catch (_) {
      await _fallbackLoad();
    }
  }

  Future<void> _fallbackLoad() async {
    try {
      final messages =
          await ref.read(communityRepositoryProvider).messages(widget.connection.id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .sendMessage(widget.connection.id, text);
      _input.clear();
      await _fallbackLoad(); // stream will also deliver; fallback keeps UX snappy
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send. The connection may be unavailable.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _proposeWalk() async {
    final placeController = TextEditingController();
    final noteController = TextEditingController();
    DateTime proposedAt = DateTime.now().add(const Duration(hours: 3));
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.ink900,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Propose a walk',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.ink50)),
                  const SizedBox(height: AppSpace.s16),
                  TextField(
                    key: const Key('walk_place_field'),
                    controller: placeController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Where?',
                      hintText: 'Stadtpark main gate',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  OutlinedButton.icon(
                    key: const Key('walk_when_button'),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: sheetContext,
                        initialDate: proposedAt,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date == null || !sheetContext.mounted) return;
                      final time = await showTimePicker(
                        context: sheetContext,
                        initialTime: TimeOfDay.fromDateTime(proposedAt),
                      );
                      if (time == null) return;
                      setSheetState(() {
                        proposedAt = DateTime(date.year, date.month, date.day,
                            time.hour, time.minute);
                      });
                    },
                    icon: const Icon(Icons.event_rounded),
                    label: Text(_when(proposedAt)),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  TextField(
                    key: const Key('walk_note_field'),
                    controller: noteController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  PawPrimaryButton(
                    key: const Key('walk_propose_submit'),
                    icon: Icons.directions_walk_rounded,
                    onPressed: () {
                      if (placeController.text.trim().isEmpty) return;
                      Navigator.pop(sheetContext, true);
                    },
                    child: const Text('Send proposal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (submitted == true) {
      try {
        await ref.read(communityRepositoryProvider).propose(WalkProposal(
              connectionId: widget.connection.id,
              proposerId: '', // repository injects auth.uid()
              placeName: placeController.text.trim(),
              note: noteController.text.trim().isEmpty
                  ? null
                  : noteController.text.trim(),
              proposedAt: proposedAt,
            ));
        _proposals =
            await ref.read(communityRepositoryProvider).proposals(widget.connection.id);
        if (mounted) setState(() {});
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not send the proposal.')));
        }
      }
    }
    placeController.dispose();
    noteController.dispose();
  }

  Future<void> _reportOrBlock() async {
    final uid = ref.read(currentUserIdProvider) ?? '';
    final otherId = widget.connection.otherParty(uid);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.ink900,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('community_report_action'),
              leading: const Icon(Icons.flag_outlined, color: AppColors.ink300),
              title: const Text('Report this member'),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
            ListTile(
              key: const Key('community_block_action'),
              leading: Icon(Icons.block_rounded,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: const Text('Block'),
              subtitle: const Text('They can no longer message you.'),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'block') {
      await ref
          .read(communityRepositoryProvider)
          .respond(widget.connection.id, ConnectionStatus.blocked);
      ref.invalidate(communityConnectionsProvider);
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'report') {
      String reason = kReportReasons.first;
      final detailsController = TextEditingController();
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<String>(
                  groupValue: reason,
                  onChanged: (v) => setDialogState(() => reason = v!),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final r in kReportReasons)
                        RadioListTile<String>(
                          key: Key('report_reason_$r'),
                          title: Text(r[0].toUpperCase() + r.substring(1)),
                          value: r,
                        ),
                    ],
                  ),
                ),
                TextField(
                  key: const Key('report_details_field'),
                  controller: detailsController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                      labelText: 'Details (optional)', counterText: ''),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              TextButton(
                key: const Key('report_submit'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Send report'),
              ),
            ],
          ),
        ),
      );
      if (submitted == true) {
        await ref.read(communityRepositoryProvider).report(
              reportedUserId: otherId,
              reason: reason,
              details: detailsController.text.trim().isEmpty
                  ? null
                  : detailsController.text.trim(),
              connectionId: widget.connection.id,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Thank you — your report will be reviewed.')));
        }
      }
      detailsController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUserIdProvider) ?? '';
    final timeline = mergeTimeline(_messages, _proposals);

    return PawScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.otherProfile?.displayName ?? 'Chat'),
        actions: [
          IconButton(
            key: const Key('community_chat_menu'),
            tooltip: 'Report or block',
            icon: const Icon(Icons.shield_outlined),
            onPressed: _reportOrBlock,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : timeline.isEmpty
                    ? Center(
                        child: Text(
                          'Say hi 👋',
                          key: const Key('community_chat_empty'),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.ink300),
                        ),
                      )
                    : ListView.builder(
                        key: const Key('community_chat_list'),
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpace.s16),
                        itemCount: timeline.length,
                        itemBuilder: (context, i) {
                          final item = timeline[timeline.length - 1 - i];
                          return switch (item) {
                            MessageItem(:final message) => _MessageBubble(
                                message: message, mine: message.senderId == uid),
                            ProposalItem(:final proposal) => _ProposalCard(
                                proposal: proposal,
                                mine: proposal.proposerId == uid,
                                onRespond: (status) async {
                                  await ref
                                      .read(communityRepositoryProvider)
                                      .respondProposal(proposal.id!, status);
                                  _proposals = await ref
                                      .read(communityRepositoryProvider)
                                      .proposals(widget.connection.id);
                                  if (mounted) setState(() {});
                                },
                              ),
                          };
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.s12, AppSpace.s4, AppSpace.s12, AppSpace.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    key: const Key('community_propose_walk'),
                    tooltip: 'Propose a walk',
                    onPressed: _proposeWalk,
                    icon: const Icon(Icons.directions_walk_rounded,
                        color: PawPalette.mint),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('community_chat_input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  IconButton.filled(
                    key: const Key('community_chat_send'),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _when(DateTime t) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${months[t.month - 1]} ${t.day} · $hh:$mm';
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final CommunityMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            left: mine ? 48 : 0,
            right: mine ? 0 : 48,
            top: AppSpace.s4,
            bottom: AppSpace.s4),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16, vertical: AppSpace.s12),
        decoration: BoxDecoration(
          gradient: mine
              ? const LinearGradient(
                  colors: [PawPalette.mint, PawPalette.teal])
              : null,
          color: mine ? null : Colors.white.withValues(alpha: 0.05),
          border: mine
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.07)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: mine ? PawPalette.bgBottom : AppColors.ink50),
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.mine,
    required this.onRespond,
  });

  final WalkProposal proposal;
  final bool mine;
  final ValueChanged<ProposalStatus> onRespond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = switch (proposal.status) {
      ProposalStatus.accepted => 'Accepted ✓',
      ProposalStatus.declined => 'Declined',
      ProposalStatus.pending => mine ? 'Waiting for a reply' : null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: PawCard(
        key: Key('proposal_${proposal.id}'),
        padding: const EdgeInsets.all(AppSpace.s12),
        radius: AppRadius.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk_rounded,
                    color: PawPalette.mint, size: 20),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text('Walk at ${proposal.placeName}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.ink50)),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Text(_when(proposal.proposedAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: PawPalette.mint)),
            if ((proposal.note ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpace.s4),
              Text(proposal.note!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.ink300)),
            ],
            const SizedBox(height: AppSpace.s8),
            if (proposal.status == ProposalStatus.pending && !mine)
              Row(
                children: [
                  OutlinedButton(
                    key: Key('proposal_decline_${proposal.id}'),
                    onPressed: () => onRespond(ProposalStatus.declined),
                    child: const Text('Can\'t make it'),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  FilledButton(
                    key: Key('proposal_accept_${proposal.id}'),
                    onPressed: () => onRespond(ProposalStatus.accepted),
                    child: const Text('I\'m in'),
                  ),
                ],
              )
            else if (statusLabel != null)
              Text(statusLabel,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.ink300)),
          ],
        ),
      ),
    );
  }
}

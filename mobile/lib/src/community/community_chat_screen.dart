import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/supabase_providers.dart';
import '../health/health_sections.dart';
import '../pets/pet.dart' show speciesLabel;
import '../theme/design_tokens.dart';
import 'community_models.dart';
import 'community_repository.dart';
import 'community_sections.dart';

/// Mockup `community_post_detail`, over the 1:1 conversation.
///
/// The reference opens a post: an author card, the body and its hashtags, a
/// media carousel, a reaction row, a details strip, and then a threaded
/// comment section with a composer pinned at the bottom.
///
/// PawDoc has no posts — but it has the two things that give the reference its
/// shape. The **comment thread with the pinned composer** is a conversation,
/// and PawDoc's is real: live over Supabase realtime with a pull fallback,
/// RLS-scoped to the two people in it. The **details strip** ("Walk Details ·
/// Location · Mood") is a walk, and PawDoc has `walk_proposals` — a place and
/// a time one member offers and the other accepts. So the strip carries the
/// real proposal, the thread carries the real messages, and the author card
/// carries the real member.
///
/// **What is absent, and why.** Follow and bookmark (no follows table, no
/// saves table); hearts and reaction counts on messages (no reactions table);
/// "See translation" (no translation service, and machine-translating a
/// stranger's health anecdote is a way to get one wrong); the media carousel
/// and the composer's image and GIF buttons (`community_messages` has a text
/// column and nothing else, and attachments here would need their own storage
/// scope and moderation pass); "Most Relevant" comment sorting (a conversation
/// is chronological); and the **"Top Contributor" and verified-veterinarian
/// badges** — PawDoc verifies nobody, and a badge that implies it vouches for a
/// stranger's advice is the most consequential invention in the reference set.
///
/// The walk strip also drops the reference's **3.4 km · 45 min · 18 °C**.
/// Walk tracking is *Soon* across the app, there is no weather in a proposal,
/// and a distance printed beside a meeting place reads as a route.
///
/// Report and block stay one tap away in the header (Play's UGC policy, and
/// the reason `community_reports` exists).
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
  // Hoisted out of `_proposeWalk`.
  //
  // They used to be created and disposed around the `showModalBottomSheet`
  // await, which disposes them while the sheet is still animating out and its
  // fields are still rebuilding — "A TextEditingController was used after
  // being disposed". Owning them for the screen's lifetime removes the race.
  final _walkPlace = TextEditingController();
  final _walkNote = TextEditingController();
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
      final messages = await ref
          .read(communityRepositoryProvider)
          .messages(widget.connection.id);
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
    _walkPlace.dispose();
    _walkNote.dispose();
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
      await _fallbackLoad(); // stream also delivers; this keeps it snappy
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not send. The connection may be unavailable.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _proposeWalk() async {
    _walkPlace.clear();
    _walkNote.clear();
    DateTime proposedAt = DateTime.now().add(const Duration(hours: 3));
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => HealthSheet(
            title: 'Propose a walk',
            scrollable: true,
            children: [
              const Text('Where',
                  style: TextStyle(color: HealthTone.muted, fontSize: 11.5)),
              const SizedBox(height: 6),
              HealthCountedField(
                fieldKey: const Key('walk_place_field'),
                controller: _walkPlace,
                maxLength: 80,
                hint: 'e.g. Stadtpark main gate',
              ),
              const SizedBox(height: 12),
              const Text('When',
                  style: TextStyle(color: HealthTone.muted, fontSize: 11.5)),
              const SizedBox(height: 6),
              CommunityActionButton(
                key: const Key('walk_when_button'),
                label: _when(proposedAt),
                icon: LucideIcons.calendar,
                onTap: () async {
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
              ),
              const SizedBox(height: 12),
              const Text('Note (optional)',
                  style: TextStyle(color: HealthTone.muted, fontSize: 11.5)),
              const SizedBox(height: 6),
              HealthCountedField(
                fieldKey: const Key('walk_note_field'),
                controller: _walkNote,
                maxLength: 200,
                minLines: 2,
                maxLines: 3,
                hint: 'e.g. Milo is shy with big dogs',
              ),
              const SizedBox(height: 8),
              const Text(
                'A proposal is a message, not a booking: nothing is tracked, '
                'nothing is shared with anyone else, and no location leaves '
                'your device.',
                style: TextStyle(
                    color: HealthTone.faint, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 14),
              HealthPrimaryCta(
                key: const Key('walk_propose_submit'),
                label: 'Send proposal',
                icon: LucideIcons.footprints,
                onTap: () {
                  if (_walkPlace.text.trim().isEmpty) return;
                  Navigator.pop(sheetContext, true);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (submitted == true) {
      try {
        await ref.read(communityRepositoryProvider).propose(WalkProposal(
              connectionId: widget.connection.id,
              proposerId: '', // repository injects auth.uid()
              placeName: _walkPlace.text.trim(),
              note: _walkNote.text.trim().isEmpty
                  ? null
                  : _walkNote.text.trim(),
              proposedAt: proposedAt,
            ));
        _proposals = await ref
            .read(communityRepositoryProvider)
            .proposals(widget.connection.id);
        if (mounted) setState(() {});
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not send the proposal.')));
        }
      }
    }
  }

  Future<void> _reportOrBlock() async {
    final uid = ref.read(currentUserIdProvider) ?? '';
    final otherId = widget.connection.otherParty(uid);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Safety',
        children: [
          HealthSettingRow(
            key: const Key('community_report_action'),
            icon: LucideIcons.flag,
            label: 'Report this member',
            value: 'Reviewed by us',
            onTap: () => Navigator.pop(sheetContext, 'report'),
          ),
          HealthSettingRow(
            key: const Key('community_block_action'),
            icon: LucideIcons.ban,
            label: 'Block',
            value: 'They can no longer message you',
            valueColor: AppColors.emergencyDark,
            onTap: () => Navigator.pop(sheetContext, 'block'),
          ),
        ],
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
            content: SingleChildScrollView(
              child: Column(
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
    final uid = ref.watch(currentUserIdProvider) ?? '';
    final timeline = mergeTimeline(_messages, _proposals);
    final other = widget.otherProfile;
    // The strip shows the proposal that is still ahead, or the most recent one
    // — a walk already answered is still the thing this conversation is about.
    final latestProposal = _proposals.isEmpty ? null : _proposals.last;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PetModuleAppBar(
        title: other?.displayName ?? 'Conversation',
        icon: LucideIcons.messageCircle,
        subtitle: 'Share. Learn. Support.',
        actions: [
          HealthCircleButton(
            key: const Key('community_chat_menu'),
            icon: LucideIcons.shield,
            tooltip: 'Report or block',
            onTap: _reportOrBlock,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(
                  kRecordGutter, 6, kRecordGutter, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (other != null) ...[
                    _MemberHeaderCard(
                      profile: other,
                      onProposeWalk: _proposeWalk,
                    ),
                    gap(12),
                  ],
                  if (latestProposal != null) ...[
                    _WalkStrip(proposal: latestProposal),
                    gap(12),
                  ],
                  HealthSectionHead(
                    title: 'Messages',
                    actionLabel: '${_messages.length}',
                    chevron: false,
                  ),
                  gap(6),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (timeline.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: Text(
                        'Say hi 👋',
                        key: const Key('community_chat_empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: HealthTone.muted, fontSize: 13.5),
                      ),
                    )
                  else
                    Column(
                      key: const Key('community_chat_list'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in timeline)
                          switch (item) {
                            MessageItem(:final message) => _MessageBubble(
                                message: message,
                                mine: message.senderId == uid),
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
                          },
                      ],
                    ),
                ],
              ),
            ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            onSend: _send,
            onProposeWalk: _proposeWalk,
          ),
        ],
      ),
    );
  }
}

String _when(DateTime t) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${months[t.month - 1]} ${t.day} · $hh:$mm';
}

/// The reference's author card, carrying the member this conversation is with.
class _MemberHeaderCard extends StatelessWidget {
  const _MemberHeaderCard({required this.profile, required this.onProposeWalk});

  final CommunityProfile profile;
  final VoidCallback onProposeWalk;

  @override
  Widget build(BuildContext context) {
    final species = profile.speciesTags.map(speciesLabel).join(' · ');
    return Container(
      key: const Key('community_member_card'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityAvatar(profile: profile, size: 44),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const HealthPill(
                            label: 'Connected', tint: AppColors.lime500),
                        if (species.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(species,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: HealthTone.muted, fontSize: 11.5)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((profile.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(profile.bio!,
                style: const TextStyle(
                    color: HealthTone.muted, fontSize: 12.5, height: 1.4)),
          ],
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CommunityActionButton(
                key: const Key('community_propose_walk_card'),
                label: 'Propose a walk',
                icon: LucideIcons.footprints,
                filled: true,
                onTap: onProposeWalk,
              ),
              const CommunitySoonChip(
                key: Key('community_soon_follow'),
                label: 'Follow',
                icon: LucideIcons.userRoundPlus,
                reason: 'Following needs a follows table, and PawDoc\'s '
                    'community is mutual connections rather than followers.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The reference's "Walk Details · Location · Mood" strip, carrying the real
/// proposal. Distance, duration, temperature and a mood rating are not in it:
/// walk tracking is *Soon*, a proposal has no weather, and a mood star rating
/// is a judgement about an animal nobody recorded.
class _WalkStrip extends StatelessWidget {
  const _WalkStrip({required this.proposal});

  final WalkProposal proposal;

  @override
  Widget build(BuildContext context) {
    final status = switch (proposal.status) {
      ProposalStatus.accepted => 'Both in',
      ProposalStatus.declined => 'Declined',
      ProposalStatus.pending => 'Waiting',
    };
    return Container(
      key: const Key('community_walk_strip'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lime500.withValues(alpha: 0.22)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StripCell(
              icon: LucideIcons.mapPin,
              label: 'Where',
              value: proposal.placeName,
            ),
            VerticalDivider(
                width: 17,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.08)),
            _StripCell(
              icon: LucideIcons.calendar,
              label: 'When',
              value: _when(proposal.proposedAt),
            ),
            VerticalDivider(
                width: 17,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.08)),
            _StripCell(
              icon: LucideIcons.footprints,
              label: 'Status',
              value: status,
            ),
          ],
        ),
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.lime500),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.lime500,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11.5, height: 1.3)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final CommunityMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            left: mine ? 44 : 0, right: mine ? 0 : 44, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.lime500.withValues(alpha: 0.16)
              : HealthTone.card,
          border: Border.all(
              color: mine
                  ? AppColors.lime500.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 5),
            bottomRight: Radius.circular(mine ? 5 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: const TextStyle(
              color: Colors.white, fontSize: 13.5, height: 1.4),
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
    final statusLabel = switch (proposal.status) {
      ProposalStatus.accepted => 'Accepted ✓',
      ProposalStatus.declined => 'Declined',
      ProposalStatus.pending => mine ? 'Waiting for a reply' : null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        key: Key('proposal_${proposal.id}'),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: HealthTone.card,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.lime500.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.footprints,
                    size: 16, color: AppColors.lime500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Walk at ${proposal.placeName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_when(proposal.proposedAt),
                style: const TextStyle(
                    color: AppColors.lime500, fontSize: 12)),
            if ((proposal.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(proposal.note!,
                  style: const TextStyle(
                      color: HealthTone.muted, fontSize: 12, height: 1.35)),
            ],
            const SizedBox(height: 10),
            if (proposal.status == ProposalStatus.pending && !mine)
              // Wrap, not Row: under a large text scale "Can't make it" and
              // "I'm in" together are wider than the card, and the pair used
              // to overflow by 35px at 393dp in the em-square test font.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CommunityActionButton(
                    key: Key('proposal_accept_${proposal.id}'),
                    label: "I'm in",
                    icon: LucideIcons.check,
                    filled: true,
                    onTap: () => onRespond(ProposalStatus.accepted),
                  ),
                  CommunityActionButton(
                    key: Key('proposal_decline_${proposal.id}'),
                    label: "Can't make it",
                    icon: LucideIcons.x,
                    onTap: () => onRespond(ProposalStatus.declined),
                  ),
                ],
              )
            else if (statusLabel != null)
              Text(statusLabel,
                  style: const TextStyle(
                      color: HealthTone.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// The reference's pinned comment composer. Its image and GIF buttons are not
/// here: `community_messages` holds text and nothing else.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onProposeWalk,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onProposeWalk;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kRecordGutter, 4, kRecordGutter, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            HealthCircleButton(
              key: const Key('community_propose_walk'),
              icon: LucideIcons.footprints,
              tooltip: 'Propose a walk',
              onTap: onProposeWalk,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: HealthTone.card,
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Center(
                  child: TextField(
                    key: const Key('community_chat_input'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13.5),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'Write a kind message…',
                      hintStyle:
                          TextStyle(color: HealthTone.faint, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: sending ? HealthTone.raised : AppColors.lime500,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('community_chat_send'),
                onTap: sending ? null : onSend,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(LucideIcons.send,
                      size: 18,
                      color: sending ? HealthTone.faint : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

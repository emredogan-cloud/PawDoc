import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../core/motion.dart';
import '../emergency/emergency_help_screen.dart';
import '../monetization/paywall_screen.dart';
import '../pets/active_pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'assistant_media.dart';
import 'assistant_models.dart';
import 'assistant_repository.dart';
import 'chat_controller.dart';

/// The PawDoc Assistant tab (Next Evolution Phase 4): a premium conversational
/// surface — streaming markdown replies, conversation history, photo
/// attachments — that is additive to (never a bypass of) the safety triage
/// system. Emergency-sounding input routes to the red help screen before any
/// network call; symptom triage stays in the Check flow.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Uint8List? _pendingImage;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final chat = ref.read(chatControllerProvider.notifier);
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;

    final active = ref.read(activePetProvider);
    final locale = Localizations.maybeLocaleOf(context)?.languageCode;

    String? imageKey;
    if (_pendingImage != null) {
      setState(() => _uploadingImage = true);
      try {
        imageKey = await ref
            .read(assistantMediaServiceProvider)
            .compressAndUpload(_pendingImage!);
      } catch (_) {
        if (mounted) {
          setState(() => _uploadingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Could not upload the photo. Sending text only.')));
        }
      }
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _pendingImage = null;
        });
      }
    }

    _input.clear();
    await chat.send(
      text,
      petId: active?.id,
      species: active?.species,
      locale: locale,
      imageStorageKey: imageKey,
    );
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.ink900,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('assistant_attach_camera'),
              leading: const Icon(Icons.photo_camera_rounded,
                  color: PawPalette.mint),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('assistant_attach_gallery'),
              leading: const Icon(Icons.photo_library_rounded,
                  color: PawPalette.mint),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final bytes = await ref.read(assistantMediaServiceProvider).pick(source);
      if (bytes != null && mounted) setState(() => _pendingImage = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open the picker. Please try again.')));
      }
    }
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ink900,
      isScrollControlled: true,
      builder: (_) => const _ConversationsSheet(),
    );
  }

  void _showLimitSheet(int? limit) {
    ref.read(chatControllerProvider.notifier).acknowledgeStatus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ink900,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("That's today's free conversation",
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.ink50)),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Free includes ${limit ?? 20} assistant messages a day. '
                'Premium talks as long as you like — and safety checks stay '
                'free for everyone, always.',
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.ink300),
              ),
              const SizedBox(height: AppSpace.s16),
              PawPrimaryButton(
                key: const Key('assistant_upgrade_button'),
                icon: Icons.workspace_premium_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PaywallScreen()),
                  );
                },
                child: const Text('See Premium'),
              ),
              const SizedBox(height: AppSpace.s8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Tomorrow then'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final active = ref.watch(activePetProvider);

    // Transient statuses → route/surface once, then reset.
    ref.listen(chatControllerProvider, (prev, next) {
      if (prev?.status == next.status) return;
      switch (next.status) {
        case ChatStatus.emergency:
          ref.read(chatControllerProvider.notifier).acknowledgeStatus();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EmergencyHelpScreen(
                matchedKeyword: next.emergencyKeyword ?? ''),
          ));
        case ChatStatus.limited:
          _showLimitSheet(next.limit);
        case _:
          break;
      }
    });

    return PawScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assistant'),
            Text(
              active == null ? 'Your pet-life companion' : 'With ${active.name} in mind',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: PawPalette.mint),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('assistant_history_button'),
            tooltip: 'Conversations',
            icon: const Icon(Icons.forum_outlined),
            onPressed: _openHistory,
          ),
          IconButton(
            key: const Key('assistant_new_button'),
            tooltip: 'New conversation',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () =>
                ref.read(chatControllerProvider.notifier).startNew(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Translucent pet-themed layer over the dark world.
          const Positioned.fill(
            child: ExcludeSemantics(child: _PawMarkBackdrop()),
          ),
          Column(
            children: [
              Expanded(
                child: chat.isEmpty
                    ? _Greeting(petName: active?.name, onSuggest: _send)
                    : _MessagesList(chat: chat, scroll: _scroll),
              ),
              if (chat.status == ChatStatus.error)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s16, vertical: AppSpace.s4),
                  child: Text(
                    chat.errorMessage ?? 'Something went wrong. Try again.',
                    key: const Key('assistant_error'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              _InputBar(
                controller: _input,
                streaming: chat.isStreaming,
                uploading: _uploadingImage,
                pendingImage: _pendingImage,
                onRemoveImage: () => setState(() => _pendingImage = null),
                onAttach: _attach,
                onSend: _send,
                onStop: () =>
                    ref.read(chatControllerProvider.notifier).stopStreaming(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sparse, low-opacity paw marks — the "translucent pet-themed background".
class _PawMarkBackdrop extends StatelessWidget {
  const _PawMarkBackdrop();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PawMarkPainter(), size: Size.infinite);
}

class _PawMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7); // deterministic — no shimmer on repaint
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.028);
    for (var i = 0; i < 14; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final s = 14 + rng.nextDouble() * 22;
      final rot = (rng.nextDouble() - 0.5) * 1.2;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      // Pad + four toes.
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, s * 0.35), width: s * 1.15, height: s * 0.9),
          paint);
      for (final (dx, dy) in [(-0.62, -0.25), (-0.22, -0.52), (0.22, -0.52), (0.62, -0.25)]) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(s * dx, s * dy),
                width: s * 0.38,
                height: s * 0.5),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.petName, required this.onSuggest});

  final String? petName;
  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = <String>[
      'Indoor games for a rainy day',
      'Help me build a feeding routine',
      'How do I make grooming stress-free?',
      'What should I ask at our next vet visit?',
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          key: const Key('assistant_greeting'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [PawPalette.mint, PawPalette.teal]),
                boxShadow: [
                  BoxShadow(
                    color: PawPalette.glow.withValues(alpha: 0.35),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: const Icon(Icons.pets_rounded,
                  size: 40, color: PawPalette.bgBottom),
            ),
            const SizedBox(height: AppSpace.s16),
            Text(
              petName == null
                  ? 'Hi — I\'m your PawDoc Assistant'
                  : 'Hi — let\'s talk about $petName',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.headlineSmall?.copyWith(color: AppColors.ink50),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              'Everyday pet life: routines, behavior, training, breeds. '
              'For health worries, I\'ll always point you to a proper Check.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink300),
            ),
            const SizedBox(height: AppSpace.s24),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    key: Key('assistant_suggestion_${suggestions.indexOf(s)}'),
                    label: Text(s),
                    labelStyle: theme.textTheme.labelMedium
                        ?.copyWith(color: PawPalette.mint),
                    backgroundColor: PawPalette.teal.withValues(alpha: 0.14),
                    side: BorderSide(
                        color: PawPalette.mint.withValues(alpha: 0.25)),
                    onPressed: () => onSuggest(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({required this.chat, required this.scroll});

  final ChatState chat;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...chat.messages,
      if (chat.isStreaming)
        ChatUiMessage(role: 'assistant', content: chat.streamingText),
    ];
    // reverse:true keeps the newest visible while streaming grows.
    return ListView.builder(
      key: const Key('assistant_messages'),
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final message = items[items.length - 1 - i];
        final isLive = chat.isStreaming && i == 0;
        return _Bubble(
          message: message,
          typing: isLive && message.content.isEmpty,
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.typing = false});

  final ChatUiMessage message;
  final bool typing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(
              left: 48, top: AppSpace.s4, bottom: AppSpace.s4),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16, vertical: AppSpace.s12),
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [PawPalette.mint, PawPalette.teal]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.md),
              topRight: Radius.circular(AppRadius.md),
              bottomLeft: Radius.circular(AppRadius.md),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.imageStorageKey != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_rounded,
                          size: 16, color: PawPalette.bgBottom),
                      const SizedBox(width: AppSpace.s4),
                      Text('Photo attached',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: PawPalette.bgBottom)),
                    ],
                  ),
                ),
              Text(
                message.content,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: PawPalette.bgBottom),
              ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
            right: 32, top: AppSpace.s4, bottom: AppSpace.s4),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16, vertical: AppSpace.s12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.md),
            topRight: Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(AppRadius.md),
          ),
        ),
        child: typing
            ? const _TypingDots()
            : GptMarkdown(
                message.content,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.ink50, height: 1.45),
              ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reduceMotion(context)) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Text('…',
          key: const Key('assistant_typing'),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: PawPalette.mint));
    }
    return SizedBox(
      key: const Key('assistant_typing'),
      width: 40,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(
                  0,
                  -3 *
                      math.sin((_controller.value * 2 * math.pi) - i * 0.9)
                          .clamp(0.0, 1.0),
                ),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PawPalette.mint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.streaming,
    required this.uploading,
    required this.pendingImage,
    required this.onRemoveImage,
    required this.onAttach,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool streaming;
  final bool uploading;
  final Uint8List? pendingImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.s12, AppSpace.s4, AppSpace.s12, AppSpace.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingImage != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.brSm,
                        child: Image.memory(pendingImage!,
                            width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          key: const Key('assistant_remove_image'),
                          onTap: onRemoveImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('assistant_attach_button'),
                  tooltip: 'Attach a photo',
                  onPressed: streaming || uploading ? null : onAttach,
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      color: PawPalette.mint),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('assistant_input'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Ask about pet life…',
                      counterText: '',
                    ),
                    onSubmitted: (_) => streaming ? null : onSend(),
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                uploading
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpace.s12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : InkWell(
                        key: Key(streaming
                            ? 'assistant_stop_button'
                            : 'assistant_send_button'),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        onTap: streaming ? onStop : onSend,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [PawPalette.mint, PawPalette.teal]),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    PawPalette.glow.withValues(alpha: 0.3),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Icon(
                            streaming
                                ? Icons.stop_rounded
                                : Icons.arrow_upward_rounded,
                            color: PawPalette.bgBottom,
                          ),
                        ),
                      ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s4),
              child: Text(
                'General guidance — not a diagnosis. For symptoms, run a Check.',
                key: const Key('assistant_disclaimer'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.ink300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationsSheet extends ConsumerWidget {
  const _ConversationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(assistantConversationsProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Text('Conversations',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.ink50)),
            ),
            Expanded(
              child: conversations.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Could not load conversations.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'No conversations yet.',
                        key: const Key('assistant_history_empty'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.ink300),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) =>
                        _ConversationTile(conversation: list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final AssistantConversation conversation;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          key: const Key('conversation_rename_field'),
          controller: controller,
          maxLength: 80,
          autofocus: true,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await ref.read(assistantRepositoryProvider).rename(conversation.id, title);
      ref.invalidate(assistantConversationsProvider);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text('Its messages will be removed. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep it')),
          TextButton(
            key: const Key('conversation_delete_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(assistantRepositoryProvider).delete(conversation.id);
      final chat = ref.read(chatControllerProvider);
      if (chat.conversationId == conversation.id) {
        ref.read(chatControllerProvider.notifier).startNew();
      }
      ref.invalidate(assistantConversationsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: Key('conversation_${conversation.id}'),
      leading: const Icon(Icons.chat_bubble_outline_rounded,
          color: PawPalette.mint),
      title: Text(conversation.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_relativeTime(conversation.updatedAt)),
      onTap: () async {
        await ref
            .read(chatControllerProvider.notifier)
            .openConversation(conversation);
        if (context.mounted) Navigator.pop(context);
      },
      trailing: PopupMenuButton<String>(
        key: Key('conversation_menu_${conversation.id}'),
        onSelected: (value) {
          if (value == 'rename') _rename(context, ref);
          if (value == 'delete') _delete(context, ref);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}

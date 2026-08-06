import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../account/user_profile.dart';
import '../analysis/analysis_service.dart';
import '../config/legal_urls.dart';
import '../core/living_pet_avatar.dart';
import '../core/pet_display.dart';
import '../emergency/emergency_help_screen.dart';
import '../health/health_event_form_screen.dart';
import '../health/history_timeline_screen.dart';
import '../home/home_sections.dart';
import '../monetization/paywall_screen.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../reminders/reminder_form_screen.dart';
import '../reminders/reminders_repository.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'assistant_avatar.dart';
import 'assistant_media.dart';
import 'assistant_models.dart';
import 'assistant_repository.dart';
import 'assistant_sections.dart';
import 'chat_controller.dart';

/// The PawDoc Assistant, rebuilt against mockups `ai_assistant_home`,
/// `ai_assistant_chat` and `ai_message_actions`.
///
/// One route, two surfaces. With nothing said yet it is the **hub** the first
/// mockup draws — hero, openers, resumable threads, topics, the at-a-glance
/// card, the premium strip. The moment a message exists it becomes the
/// **conversation** the second draws, and every reply carries the action row
/// the third expands into a sheet.
///
/// It stays additive to the safety system and is never a bypass of it:
/// emergency-sounding input routes to the red help screen before any network
/// call, and symptom triage stays in the Check flow.
///
/// **Copy departures from the mockups, and why** (layout is reproduced in all
/// three cases):
///
/// | Mockup | Shipped | Reason |
/// |---|---|---|
/// | "Your personal AI Vet Assistant" | "Your everyday pet-care companion" | V-23 — the assistant is not a veterinarian |
/// | "AI Vet Assistant" (chat) | "Everyday pet care · not a diagnosis" | V-23 |
/// | chip "Why is Buddy itching?" | "Daily care routine?" | V-12 — a symptom the owner has not reported |
/// | topic "Health & Symptoms" | "Health & Records" | the assistant is not a second triage entry point |
/// | "Health Score · 92 · Excellent" | "Care Score", record completeness | D-2 |
/// | Energy / Appetite / Mood / Activity readings | the same rows, marked *Soon* | nothing records them; an invented "Mood · Happy" is a claim about an animal nobody observed |
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
  bool _premiumDismissed = false;

  /// Per-reply feedback, by position in the thread. Local to the session: there
  /// is no assistant-message feedback table, and pretending a rating was filed
  /// somewhere would be a claim the app cannot keep.
  final Map<int, bool> _ratings = {};

  /// Advances the "You might also ask" window each time the sheet is shuffled.
  int _followUpOffset = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Sending
  // -------------------------------------------------------------------------

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
          _toast('Could not upload the photo. Sending text only.');
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

  Future<void> _regenerate() async {
    final active = ref.read(activePetProvider);
    await ref.read(chatControllerProvider.notifier).regenerate(
          petId: active?.id,
          species: active?.species,
          locale: Localizations.maybeLocaleOf(context)?.languageCode,
        );
  }

  void _toast(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), action: action));
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
              leading:
                  const Icon(LucideIcons.camera, color: PawPalette.mint),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('assistant_attach_gallery'),
              leading: const Icon(LucideIcons.images, color: PawPalette.mint),
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
      _toast('Could not open the picker. Please try again.');
    }
  }

  // -------------------------------------------------------------------------
  // Sheets
  // -------------------------------------------------------------------------

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ink900,
      isScrollControlled: true,
      builder: (_) => const _ConversationsSheet(),
    );
  }

  void _openHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A0F0B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What PawDoc AI is for',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: AppSpace.s12),
              Text(
                'Everyday pet life: routines, behaviour, food, grooming, '
                'training and breeds. It answers in general terms and it is '
                'not a veterinarian.\n\n'
                'If you are worried about something you can see on your pet, '
                'run an AI Health Check instead — that flow is built for it. '
                'Anything that sounds like an emergency goes straight to the '
                'red help screen, before any model is asked.',
                style: TextStyle(
                    color: Color(0xFF9BA5A0), fontSize: 14, height: 1.45),
              ),
            ],
          ),
        ),
      ),
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
                icon: LucideIcons.crown,
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

  void _openPetMenu(Pet? pet) {
    if (pet == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PawSystemScope(
        system: PawSystem.b,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PawListRow(
                  key: const Key('assistant_view_profile'),
                  title: 'View profile',
                  subtitle: '${petDisplayName(pet.name)}’s record',
                  leading: const PawIconTile(child: PawIcon(LucideIcons.pawPrint)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => HealthHistoryScreen(),
                    ));
                  },
                ),
                const SizedBox(height: AppSpace.s8),
                PawListRow(
                  title: 'New conversation',
                  subtitle: 'Start a fresh thread',
                  leading: const PawIconTile(
                      child: PawIcon(LucideIcons.messageCirclePlus)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref.read(chatControllerProvider.notifier).startNew();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PawSystemScope(
        system: PawSystem.b,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PawListRow(
                  key: const Key('assistant_new_button'),
                  title: 'New conversation',
                  subtitle: 'Keep this one in history',
                  leading: const PawIconTile(
                      child: PawIcon(LucideIcons.messageCirclePlus)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref.read(chatControllerProvider.notifier).startNew();
                  },
                ),
                const SizedBox(height: AppSpace.s8),
                PawListRow(
                  title: 'How PawDoc AI works',
                  subtitle: 'What it is for, and what it is not',
                  leading:
                      const PawIconTile(child: PawIcon(LucideIcons.circleHelp)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openHelp();
                  },
                ),
                const SizedBox(height: AppSpace.s8),
                PawListRow(
                  title: 'AI transparency',
                  subtitle: 'How answers are produced',
                  leading:
                      const PawIconTile(child: PawIcon(LucideIcons.scanEye)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    LegalUrls.open(LegalUrls.aiTransparency);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Per-message actions (mockup `ai_message_actions`)
  // -------------------------------------------------------------------------

  static const _followUpPool = <String>[
    'How do I build a daily routine?',
    'What should I ask at the next vet visit?',
    'How often should grooming happen?',
    'How do I make nail trims calmer?',
    'What does a good sleep setup look like?',
    'How do I introduce a new food safely?',
    'What indoor enrichment actually works?',
    'How do I keep records a vet can use?',
    'How much water should I be putting out?',
    'What size should treats be?',
  ];

  List<String> _followUps(int offset) => [
        for (var i = 0; i < 3; i++)
          _followUpPool[(offset + i) % _followUpPool.length],
      ];

  void _rate(int index, bool helpful) {
    setState(() => _ratings[index] = helpful);
    if (helpful) {
      _toast('Marked as helpful.');
    } else {
      _toast('Marked as not helpful.',
          action: SnackBarAction(label: 'Try again', onPressed: _regenerate));
    }
  }

  Future<void> _openMessageActions(int index, String text) async {
    final pet = ref.read(activePetProvider);
    final name = petDisplayName(pet?.name);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => AssistantActionSheet(
          followUps: _followUps(_followUpOffset),
          onShuffle: () {
            setSheet(() => _followUpOffset += 3);
            setState(() {});
          },
          onFollowUp: (prompt) {
            Navigator.pop(sheetContext);
            _send(prompt);
          },
          actions: [
            AssistantAction(
              actionKey: const Key('assistant_action_copy'),
              icon: LucideIcons.copy,
              label: 'Copy',
              caption: 'Copy message',
              tint: AssistantTone.info,
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: text));
                _toast('Copied.');
              },
            ),
            AssistantAction(
              actionKey: const Key('assistant_action_diary'),
              icon: LucideIcons.notebookPen,
              label: 'Save to Diary',
              caption: pet == null ? 'Add a pet first' : 'Add to $name’s diary',
              tint: PawTone.of(sheetContext).accent,
              onTap: () {
                Navigator.pop(sheetContext);
                if (pet?.id == null) {
                  _toast('Add a pet first, then this saves to their diary.');
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => HealthEventFormScreen(
                    petId: pet!.id!,
                    petName: pet.name,
                    initialNotes: _diaryNote(text),
                  ),
                ));
              },
            ),
            AssistantAction(
              actionKey: const Key('assistant_action_share'),
              icon: LucideIcons.share2,
              label: 'Share',
              caption: 'Share with vet or family',
              tint: AssistantTone.violet,
              onTap: () {
                Navigator.pop(sheetContext);
                // V-22 in spirit: whatever leaves the app says where it came
                // from, so a vet reading it cannot mistake it for a finding.
                SharePlus.instance.share(ShareParams(text: _diaryNote(text)));
              },
            ),
            AssistantAction(
              actionKey: const Key('assistant_action_reminder'),
              icon: LucideIcons.bell,
              label: 'Create Reminder',
              caption: pet == null ? 'Add a pet first' : 'Set a reminder',
              tint: AssistantTone.gold,
              onTap: () {
                Navigator.pop(sheetContext);
                if (pet?.id == null) {
                  _toast('Add a pet first, then you can set reminders.');
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReminderFormScreen(
                      petId: pet!.id!, petName: pet.name),
                ));
              },
            ),
            AssistantAction(
              actionKey: const Key('assistant_action_helpful'),
              icon: LucideIcons.thumbsUp,
              label: 'Helpful',
              caption: 'Mark as helpful',
              tint: PawTone.of(sheetContext).accent,
              onTap: () {
                Navigator.pop(sheetContext);
                _rate(index, true);
              },
            ),
            AssistantAction(
              actionKey: const Key('assistant_action_not_helpful'),
              icon: LucideIcons.thumbsDown,
              label: 'Not Helpful',
              caption: 'Send feedback',
              tint: AssistantTone.coral,
              onTap: () {
                Navigator.pop(sheetContext);
                _rate(index, false);
              },
            ),
            AssistantAction(
              actionKey: const Key('assistant_action_regenerate'),
              icon: LucideIcons.sparkles,
              label: 'Regenerate',
              caption: 'Get a different answer',
              tint: AssistantTone.sky,
              onTap: () {
                Navigator.pop(sheetContext);
                _regenerate();
              },
            ),
            AssistantAction(
              actionKey: const Key('assistant_action_report'),
              icon: LucideIcons.flag,
              label: 'Report',
              caption: 'Report an issue',
              tint: AssistantTone.rose,
              onTap: () {
                Navigator.pop(sheetContext);
                LegalUrls.open(LegalUrls.contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// What leaves the app: the reply, stamped with what produced it.
  String _diaryNote(String text) =>
      'PawDoc AI — general guidance, not a diagnosis and not reviewed by a '
      'veterinarian.\n\n$text';

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final active = ref.watch(activePetProvider);
    final name = petDisplayName(active?.name);

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

    final hub = chat.isEmpty;

    return PawSystemScope(
      system: PawSystem.b,
      child: PawBackground(
        variant: PawSurface.dark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          appBar: AssistantAppBar(
            title: hub ? 'AI Assistant' : 'PawDoc AI',
            // V-23: the mockups print "AI Vet Assistant" in both slots.
            subtitle: hub
                ? 'Your everyday pet-care companion'
                : 'Everyday pet care · not a diagnosis',
            showPill: hub,
            actions: hub
                ? [
                    AssistantCircleButton(
                      icon: LucideIcons.circleHelp,
                      tooltip: 'What this is for',
                      onTap: _openHelp,
                      color: PawTone.of(context).accent,
                    ),
                    AssistantCircleButton(
                      key: const Key('assistant_history_button'),
                      icon: LucideIcons.history,
                      tooltip: 'Conversations',
                      onTap: _openHistory,
                    ),
                  ]
                : const [],
          ),
          body: Column(
            children: [
              Expanded(
                child: hub
                    ? _HubView(
                        pet: active,
                        onPrompt: (p) => _send(p.prompt),
                        onViewAllConversations: _openHistory,
                        onOpenConversation: (c) async {
                          await ref
                              .read(chatControllerProvider.notifier)
                              .openConversation(c);
                        },
                        onTopic: (t) => _send(t.prompt),
                        onEmergency: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const EmergencyHelpScreen())),
                        premiumDismissed: _premiumDismissed,
                        onDismissPremium: () =>
                            setState(() => _premiumDismissed = true),
                      )
                    : _ChatView(
                        chat: chat,
                        scroll: _scroll,
                        pet: active,
                        ratings: _ratings,
                        onRate: _rate,
                        onMore: _openMessageActions,
                        onCopy: (text) async {
                          await Clipboard.setData(ClipboardData(text: text));
                          _toast('Copied.');
                        },
                        onSwitchPet: () => _openPetMenu(active),
                        onHistory: _openHistory,
                        onMoreMenu: _openMoreMenu,
                      ),
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
              AssistantComposer(
                controller: _input,
                hint: hub
                    ? 'Ask PawDoc AI anything…'
                    : 'Ask something about $name…',
                streaming: chat.isStreaming,
                uploading: _uploadingImage,
                sendIcon: hub ? LucideIcons.send : LucideIcons.arrowUp,
                pendingImage: _pendingImage == null
                    ? null
                    : Image.memory(_pendingImage!, fit: BoxFit.cover),
                onRemoveImage: () => setState(() => _pendingImage = null),
                onAttach: _attach,
                onVoice: () => _toast('Voice input is coming soon.'),
                onSend: _send,
                onStop: () =>
                    ref.read(chatControllerProvider.notifier).stopStreaming(),
                above: hub
                    ? null
                    : AssistantSuggestionRail(
                        prompts: _railPrompts(active),
                        onSelect: (p) => _send(p.prompt),
                        onViewAll: _openHelp,
                      ),
                disclaimer: const AssistantDisclaimer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prompt sets
// ---------------------------------------------------------------------------

/// The four openers under the hero.
///
/// **V-12.** The mockup's first chip is "Why is Buddy itching?" — it asserts a
/// symptom before the owner has said anything, and a suggestion that puts words
/// in an owner's mouth about their animal is not a suggestion. Every opener
/// here is care-framed; anything that turns out to be a symptom belongs in the
/// Check flow, which is built for it.
List<AssistantPrompt> _hubPrompts(Pet? pet) {
  final name = petDisplayName(pet?.name);
  final kind = pet == null ? 'pets' : '${speciesName(pet.species).toLowerCase()}s';
  // Two words a chip: the mockup fits about eleven characters to a line and a
  // third line of a broken word reads as a bug, not as design.
  return [
    AssistantPrompt(LucideIcons.pawPrint, 'Daily routine?',
        'What does a good daily care routine look like for $name?'),
    AssistantPrompt(LucideIcons.soup, 'Is this food OK?',
        'How do I tell whether a food is a sensible choice for $kind?'),
    AssistantPrompt(LucideIcons.dog, 'Exercise needs?',
        'How much exercise do $kind like $name usually need?'),
    AssistantPrompt(LucideIcons.syringe, 'Vaccines due?',
        'What does a typical vaccination schedule look like for $kind?'),
  ];
}

/// The rail above the conversation composer.
List<AssistantPrompt> _railPrompts(Pet? pet) {
  final name = petDisplayName(pet?.name);
  final kind = pet == null ? 'pets' : '${speciesName(pet.species).toLowerCase()}s';
  return [
    AssistantPrompt(LucideIcons.shieldCheck, 'Paw care basics',
        'How should I look after $name’s paws day to day?'),
    AssistantPrompt(LucideIcons.brush, 'Grooming routine',
        'What grooming routine suits $name?'),
    AssistantPrompt(LucideIcons.soup, 'Feeding schedule',
        'How should I structure $name’s feeding schedule?'),
    AssistantPrompt(LucideIcons.syringe, 'Vaccine schedule',
        'What does a typical vaccination schedule look like for $kind?'),
  ];
}

/// The six topic tiles.
///
/// The mockup's first tile is "Health & Symptoms". The assistant is not a
/// second triage entry point — a symptom belongs in the Check flow, where the
/// emergency override, the quota rules and the action ladder all apply — so the
/// tile keeps its place and asks about the record instead.
List<AssistantTopic> _topics(Pet? pet, VoidCallback onEmergency) {
  final name = petDisplayName(pet?.name);
  return [
    AssistantTopic(LucideIcons.heartPulse, 'Health &', 'Records',
        'What is worth writing down in $name’s health record, and how often?'),
    AssistantTopic(LucideIcons.leaf, 'Nutrition', '& Diet',
        'How should I think about $name’s diet?'),
    AssistantTopic(LucideIcons.brain, 'Behaviour', '& Training',
        'What training approach works well for $name?'),
    AssistantTopic(LucideIcons.brush, 'Care &', 'Grooming',
        'What does a good grooming routine look like for $name?'),
    AssistantTopic(LucideIcons.pill, 'Meds &', 'Routines',
        'How do I keep track of $name’s medications and doses?'),
    AssistantTopic(
      LucideIcons.siren,
      'Emergency',
      'Help',
      '',
      tint: AppColors.emergencyDark,
      // Never a prompt: an emergency is not a question for a model. This tile
      // opens the offline red screen, exactly as every other emergency
      // affordance in the app does.
      onTap: onEmergency,
    ),
  ];
}

// ---------------------------------------------------------------------------
// The hub (mockup `ai_assistant_home`)
// ---------------------------------------------------------------------------

class _HubView extends ConsumerWidget {
  const _HubView({
    required this.pet,
    required this.onPrompt,
    required this.onViewAllConversations,
    required this.onOpenConversation,
    required this.onTopic,
    required this.onEmergency,
    required this.premiumDismissed,
    required this.onDismissPremium,
  });

  final Pet? pet;
  final ValueChanged<AssistantPrompt> onPrompt;
  final VoidCallback onViewAllConversations;
  final ValueChanged<AssistantConversation> onOpenConversation;
  final ValueChanged<AssistantTopic> onTopic;
  final VoidCallback onEmergency;
  final bool premiumDismissed;
  final VoidCallback onDismissPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = petDisplayName(pet?.name);
    final conversations = ref.watch(assistantConversationsProvider);
    final isPremium = ref
        .watch(userProfileProvider)
        .maybeWhen(data: (p) => p.isPremium, orElse: () => false);

    return ListView(
      key: const Key('assistant_greeting'),
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s16, AppSpace.s4, AppSpace.s16, AppSpace.s12),
      children: [
        AssistantHero(
          greeting: 'Hi there! 👋',
          promise: pet == null
              ? 'I’m here to help with everyday pet life'
              : 'I’m here to help you and $name',
          invitation: pet == null
              ? 'Ask me about routines, food, behaviour or grooming. For '
                  'symptoms, I’ll point you to a Check.'
              : 'Ask me about $name’s routine, food, behaviour or grooming. '
                  'For symptoms, I’ll point you to a Check.',
          privacyTitle: 'Private & Secure',
          privacyBody:
              'Your conversations are private and never stored with your '
              'pet’s personal data.',
          portrait: _HeroPortrait(pet: pet),
        ),
        const SizedBox(height: AppSpace.s12),
        AssistantPromptRow(prompts: _hubPrompts(pet), onSelect: onPrompt),
        const SizedBox(height: AppSpace.s12),
        AssistantContinueCard(
          title: 'Continue a conversation',
          onViewAll: onViewAllConversations,
          emptyLabel:
              'Nothing yet. Ask something above and it will wait here for you.',
          rows: conversations.maybeWhen(
            data: (list) => [
              for (final c in list.take(1))
                AssistantConversationRow(
                  key: Key('conversation_${c.id}'),
                  avatar: _HeroPortrait(pet: pet, size: 40),
                  title: c.title,
                  preview: 'Pick up where you left off.',
                  age: relativeTime(c.updatedAt),
                  status: 'Active',
                  onTap: () => onOpenConversation(c),
                ),
            ],
            orElse: () => const <AssistantConversationRow>[],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        AssistantTopicsCard(
          topics: _topics(pet, onEmergency),
          onSelect: onTopic,
          onViewAll: onViewAllConversations,
        ),
        const SizedBox(height: AppSpace.s12),
        _GlanceCard(pet: pet, name: name),
        if (!isPremium && !premiumDismissed) ...[
          const SizedBox(height: AppSpace.s12),
          AssistantPremiumBanner(
            title: 'Unlock deeper insights',
            body: 'Unlimited chats and every record kept.',
            ctaLabel: 'Explore Premium',
            onCta: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
            onDismiss: onDismissPremium,
          ),
        ],
      ],
    );
  }
}

/// The pet as the hero draws them: their own photo when there is one, the
/// photoreal species portrait when there is not, and the assistant's own face
/// before a pet exists at all.
class _HeroPortrait extends StatelessWidget {
  const _HeroPortrait({required this.pet, this.size = 150});

  final Pet? pet;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (pet == null) {
      return AssistantAvatar(size: size, glow: false);
    }
    if (pet!.photoKey != null) {
      return LivingPetAvatar(
        species: pet!.species,
        size: size,
        seed: pet!.id,
        photoKey: pet!.photoKey,
      );
    }
    // Top-anchored: the hero slot is tall and narrow, and a centred cover crop
    // of a square portrait lands on the muzzle.
    return Image.asset(
      AppAssets.species(pet!.species),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// "…'s health at a glance" — the Care Score dial and the signal list.
class _GlanceCard extends ConsumerWidget {
  const _GlanceCard({required this.pet, required this.name});

  final Pet? pet;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = pet?.id;
    final checkedAt = id == null
        ? null
        : ref.watch(latestTriageProvider(id)).value?.checkedAt;
    final hasReminder = id == null
        ? false
        : ref
            .watch(remindersForPetProvider(id))
            .maybeWhen(data: (list) => list.isNotEmpty, orElse: () => false);
    final score = pet == null
        ? 0
        : careScore(pet!, hasCheck: checkedAt != null, hasReminder: hasReminder);

    return AssistantGlanceCard(
      title: pet == null ? 'Your pet at a glance' : '$name’s health at a glance',
      score: score,
      scoreBand: careBand(score),
      // D-2: the dial counts how complete the RECORD is. "Keep it up! 🎉" is
      // the mockup's own caption and it praises record-keeping, never health.
      scoreCaption: score >= 70 ? 'Keep it up! 🎉' : 'Add more detail.',
      // Nothing in the product records energy, appetite, mood or activity. The
      // rows are drawn exactly as the mockup draws them and marked instead of
      // invented — a fabricated reading is a claim about an animal nobody saw.
      signals: const [
        AssistantSignal(LucideIcons.zap, 'Energy', 'Soon', available: false),
        AssistantSignal(LucideIcons.soup, 'Appetite', 'Soon', available: false),
        AssistantSignal(LucideIcons.smile, 'Mood', 'Soon', available: false),
        AssistantSignal(LucideIcons.footprints, 'Activity', 'Soon',
            available: false),
      ],
      onOpen: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => HealthHistoryScreen())),
      onDetails: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => HealthHistoryScreen())),
    );
  }
}

/// How complete the record is, in one word. Never a statement about the animal
/// — the dial counts fields, not health (owner decision D-2).
String careBand(int score) {
  if (score >= 90) return 'Complete';
  if (score >= 70) return 'Detailed';
  if (score >= 40) return 'Building';
  return 'Starting';
}

// ---------------------------------------------------------------------------
// The conversation (mockups `ai_assistant_chat` / `ai_message_actions`)
// ---------------------------------------------------------------------------

class _ChatView extends StatelessWidget {
  const _ChatView({
    required this.chat,
    required this.scroll,
    required this.pet,
    required this.ratings,
    required this.onRate,
    required this.onMore,
    required this.onCopy,
    required this.onSwitchPet,
    required this.onHistory,
    required this.onMoreMenu,
  });

  final ChatState chat;
  final ScrollController scroll;
  final Pet? pet;
  final Map<int, bool> ratings;
  final void Function(int index, bool helpful) onRate;
  final void Function(int index, String text) onMore;
  final ValueChanged<String> onCopy;
  final VoidCallback onSwitchPet;
  final VoidCallback onHistory;
  final VoidCallback onMoreMenu;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...chat.messages,
      if (chat.isStreaming)
        ChatUiMessage(role: 'assistant', content: chat.streamingText),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s16, 0, AppSpace.s16, 0),
          child: AssistantPetBar(
            avatar: _HeroPortrait(pet: pet, size: 42),
            name: petDisplayName(pet?.name),
            detail: _petDetail(pet),
            onSwitch: onSwitchPet,
            actions: [
              AssistantCircleButton(
                icon: LucideIcons.shield,
                tooltip: 'Privacy',
                label: 'Private',
                size: 36,
                onTap: () => LegalUrls.open(LegalUrls.privacy),
              ),
              AssistantCircleButton(
                key: const Key('assistant_history_button'),
                icon: LucideIcons.history,
                tooltip: 'Conversations',
                label: 'History',
                size: 36,
                onTap: onHistory,
              ),
              AssistantCircleButton(
                key: const Key('assistant_more_button'),
                icon: LucideIcons.ellipsis,
                tooltip: 'More',
                label: 'More',
                size: 36,
                onTap: onMoreMenu,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: AssistantPrivacyStrip(
              onLearnMore: () => LegalUrls.open(LegalUrls.privacy)),
        ),
        Expanded(
          child: ListView.builder(
            key: const Key('assistant_messages'),
            controller: scroll,
            // Newest at the bottom and pinned there while a reply streams in.
            reverse: true,
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s8),
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == items.length) {
                return const AssistantDayChip(label: 'Today');
              }
              final index = items.length - 1 - i;
              final message = items[index];
              final live = chat.isStreaming && index == items.length - 1;
              final stamp = _stamp(context, message.at);

              if (message.isUser) {
                return AssistantUserBubble(
                  text: message.content,
                  stamp: stamp,
                  hasImage: message.imageStorageKey != null,
                );
              }

              final bubble = AssistantReplyBubble(
                stamp: stamp,
                rating: ratings[index],
                onCopy: live ? null : () => onCopy(message.content),
                onHelpful: live ? null : () => onRate(index, true),
                onNotHelpful: live ? null : () => onRate(index, false),
                onMore: live ? null : () => onMore(index, message.content),
                child: live && message.content.isEmpty
                    ? const _TypingDots()
                    : GptMarkdown(
                        message.content,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.45),
                      ),
              );

              // The mockup's "Was this helpful?" pill, offered once under the
              // newest reply and retired as soon as it is answered.
              final askHelpful =
                  i == 0 && !live && !ratings.containsKey(index);
              if (!askHelpful) return bubble;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bubble,
                  AssistantHelpfulPrompt(
                    onHelpful: () => onRate(index, true),
                    onNotHelpful: () => onRate(index, false),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static String _petDetail(Pet? pet) {
    if (pet == null) return 'No pet selected yet';
    final parts = <String>[
      if (pet.breed != null && pet.breed!.trim().isNotEmpty)
        pet.breed!.trim()
      else
        speciesName(pet.species),
      if (petAgeLabel(pet.birthDate) != null) petAgeLabel(pet.birthDate)!,
      if (pet.weightKg != null) '${_trim(pet.weightKg!)}kg',
    ];
    return parts.join(' • ');
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _stamp(BuildContext context, DateTime? at) {
    final t = at ?? DateTime.now();
    return TimeOfDay.fromDateTime(t).format(context);
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('…',
            key: const Key('assistant_typing'),
            style: TextStyle(
                color: PawTone.of(context).accent,
                fontSize: 20,
                height: 1.0)),
      );
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

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
      key: Key('conversation_tile_${conversation.id}'),
      leading: const Icon(LucideIcons.messageCircle, color: PawPalette.mint),
      title: Text(conversation.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(relativeTime(conversation.updatedAt)),
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

/// `2 days ago` — the age stamp the conversation rows print.
String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}

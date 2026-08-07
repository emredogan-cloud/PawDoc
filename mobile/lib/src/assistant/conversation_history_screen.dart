import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/legal_urls.dart';
import '../core/living_pet_avatar.dart';
import '../core/dates.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../pets/pet_switcher.dart';
import '../pets/pets_list_screen.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'assistant_models.dart';
import 'assistant_repository.dart';
import 'chat_controller.dart';

/// Every conversation the owner has had with the assistant, rebuilt against
/// mockup `conversation_history`.
///
/// Replaces the half-height sheet the assistant's **History** button used to
/// open: a pet header, a search field, the topic rail, the privacy card, the
/// threads grouped by day, the statistics strip and the clear-history card,
/// over the app's bottom navigation.
///
/// **Everything on it is real.** The preview is the thread's own opening reply,
/// the photo count is how many messages carry an image, the topic is derived
/// from the thread's words (see [conversationTopic] — a filing label on the
/// owner's own question, never a claim about the animal) and the statistics are
/// counted, not invented.
///
/// **Copy departure.** The mockup's third statistic is "2h 14m · Total time
/// saved". The app has no idea what a conversation saved anyone, and a number
/// that flatters the product with a fabricated measurement is the same class of
/// claim as a fabricated health score. The cell keeps its place and counts
/// messages instead.
class ConversationHistoryScreen extends ConsumerStatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  ConsumerState<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState
    extends ConsumerState<ConversationHistoryScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  String _filter = 'all';
  String _query = '';

  static const _filters = [
    HealthFilter('all', 'All Conversations', LucideIcons.messageCircle),
    HealthFilter('health', 'Health Questions', LucideIcons.heartPulse),
    HealthFilter('behavior', 'Behavior', LucideIcons.dog),
    HealthFilter('nutrition', 'Nutrition', LucideIcons.bone),
    HealthFilter('grooming', 'Grooming', LucideIcons.scissors),
    HealthFilter('general', 'General', LucideIcons.sparkles),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------

  Future<void> _open(ConversationSummary summary) async {
    final nav = Navigator.of(context);
    await ref
        .read(chatControllerProvider.notifier)
        .openConversation(summary.conversation);
    if (mounted) nav.pop(true);
  }

  Future<void> _delete(ConversationSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: const Text(
            'Its messages will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
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
    if (confirmed != true) return;
    await ref.read(assistantRepositoryProvider).delete(summary.id);
    if (ref.read(chatControllerProvider).conversationId == summary.id) {
      ref.read(chatControllerProvider.notifier).startNew();
    }
    ref
      ..invalidate(conversationSummariesProvider)
      ..invalidate(assistantConversationsProvider);
  }

  Future<void> _clearAll(int count) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all history?'),
        content: Text(
            'This permanently deletes ${count == 1 ? 'your conversation' : 'all $count conversations'} '
            'and their messages. It cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep them'),
          ),
          TextButton(
            key: const Key('conversation_clear_all_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete everything',
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(assistantRepositoryProvider).deleteAll();
      ref.read(chatControllerProvider.notifier).startNew();
      ref
        ..invalidate(conversationSummariesProvider)
        ..invalidate(assistantConversationsProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text('All conversations deleted.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not clear the history. Please try again.')));
    }
  }

  // -------------------------------------------------------------------------

  List<ConversationSummary> _visible(List<ConversationSummary> all) {
    final q = _query.trim().toLowerCase();
    return all.where((s) {
      if (_filter != 'all' && s.topic.id != _filter) return false;
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.preview.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  /// `Today` / `Yesterday` / `May 19, 2026` — the mockup's grouping.
  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return shortDate(d);
  }

  /// The right-hand stamp: a clock time today, a word yesterday, a date before.
  static String _stamp(DateTime d) {
    final label = _dayLabel(d);
    if (label == 'Today') {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
    }
    if (label == 'Yesterday') return 'Yesterday';
    return '${_monthShort(d.month)} ${d.day}';
  }

  static String _monthShort(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final pet = ref.watch(activePetProvider);
    final async = ref.watch(conversationSummariesProvider);
    // `valueOrNull`, not `asData`: while a pull-to-refresh is in flight the
    // state is AsyncLoading and the list would blink away under the user.
    final all = async.value ?? const <ConversationSummary>[];
    final visible = _visible(all);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Conversation History',
          subtitleLead: 'PawDoc AI ✨',
          subtitle: '',
          actions: [
            HealthCircleButton(
              key: const Key('history_search_button'),
              icon: _searching ? LucideIcons.x : LucideIcons.search,
              tooltip: _searching ? 'Close search' : 'Search conversations',
              onTap: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _search.clear();
                  _query = '';
                }
              }),
            ),
          ],
        ),
        onRefresh: () async {
          ref.invalidate(conversationSummariesProvider);
          await ref.read(conversationSummariesProvider.future);
        },
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(2),
          if (pet != null)
            PetModuleHeaderCard(
              portrait: _portrait(pet, 52),
              name: petDisplayName(pet.name),
              meta: _petMeta(pet),
              onSwitch: () => showPetSwitcher(context, ref),
              aside: HealthAsidePill(
                icon: LucideIcons.pawPrint,
                label: 'All Pets',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PetsListScreen()),
                ),
              ),
            ),
          if (_searching) ...[
            gap(10),
            _SearchField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
            ),
          ],
          gap(11),
          // Full-bleed: the rail scrolls past both gutters, as drawn.
          HealthBleed(
            child: HealthFilterChips(
              filters: _filters,
              selected: _filter,
              onSelect: (id) => setState(() => _filter = id),
              trailing: HealthCircleButton(
                key: const Key('history_topic_reset'),
                icon: LucideIcons.slidersHorizontal,
                tooltip: 'Reset topic filter',
                onTap: () => setState(() => _filter = 'all'),
              ),
            ),
          ),
          gap(11),
          HealthPrivacyCard(
            title: 'Your conversations are private',
            body: 'Only you can see your conversation history.\n'
                'Your pet’s data is never shared.',
            actionLabel: 'Learn more',
            onTap: () => LegalUrls.open(LegalUrls.privacy),
          ),
          gap(4),
          ...switch (async) {
            AsyncError() => [
                gap(24),
                const _HistoryNotice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load your history',
                  body: 'Check your connection and pull down to retry.',
                ),
              ],
            AsyncLoading() when all.isEmpty => [
                gap(24),
                const Center(child: CircularProgressIndicator()),
              ],
            _ when all.isEmpty => [
                gap(20),
                _HistoryNotice(
                  icon: LucideIcons.messageCircle,
                  title: 'No conversations yet',
                  body: 'Ask PawDoc AI about ${petDisplayName(pet?.name)}’s '
                      'routine, food or day-to-day care and it will appear here.',
                ),
              ],
            _ when visible.isEmpty => [
                gap(20),
                _HistoryNotice(
                  icon: LucideIcons.search,
                  title: 'Nothing matches',
                  body: _query.isEmpty
                      ? 'No conversations filed under this topic yet.'
                      : 'No conversation mentions “${_query.trim()}”.',
                ),
              ],
            _ => _groupedRows(visible),
          },
          gap(10),
          _StatsCard(all: all),
          gap(7),
          HealthDangerCard(
            key: const Key('history_clear_all'),
            title: 'Clear all history',
            body: 'This will permanently delete all your conversations.',
            onTap: all.isEmpty
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('There is nothing to clear.')),
                    )
                : () => _clearAll(all.length),
          ),
          gap(8),
          // The disclaimer the assistant carries everywhere it speaks.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'PawDoc AI offers general pet-care information. It is not '
              'veterinary advice and never a diagnosis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.textMuted, fontSize: 10.5, height: 1.35),
            ),
          ),
          gap(6),
        ],
      ),
    );
  }

  List<Widget> _groupedRows(List<ConversationSummary> rows) {
    final out = <Widget>[];
    String? bucket;
    for (final s in rows) {
      final label = _dayLabel(s.updatedAt);
      if (label != bucket) {
        out.add(HealthGroupLabel(label: label));
        bucket = label;
      }
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: _ConversationRow(
          summary: s,
          stamp: _stamp(s.updatedAt),
          onTap: () => _open(s),
          onLongPress: () => _delete(s),
        ),
      ));
    }
    return out;
  }

  Widget _portrait(Pet pet, double size) => PetPortrait(
        pet: pet,
        size: size,
        livingAvatar: pet.photoKey == null
            ? null
            : LivingPetAvatar(
                species: pet.species,
                size: size,
                seed: pet.id,
                photoKey: pet.photoKey,
              ),
      );

  static String _petMeta(Pet pet) => [
        if (pet.breed?.trim().isNotEmpty == true)
          pet.breed!.trim()
        else
          speciesName(pet.species),
        ?petAgeLabel(pet.birthDate),
        if (pet.weightKg != null) '${_kg(pet.weightKg!)}kg',
      ].join(' · ');

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------

/// One thread, as the mockup draws it: a topic-tinted glyph, the title, the
/// opening reply, the topic chip with a photo count, and the time stamp.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.summary,
    required this.stamp,
    required this.onTap,
    required this.onLongPress,
  });

  final ConversationSummary summary;
  final String stamp;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final tint = topicTint(context, summary.topic);
    return HealthRecordRow(
      key: Key('conversation_tile_${summary.id}'),
      background: HealthTone.card,
      padding: const EdgeInsets.all(10),
      leading: HealthGlyphDisc(icon: topicIcon(summary.topic), tint: tint),
      title: summary.title,
      subtitle: summary.preview.isEmpty ? 'No messages yet' : summary.preview,
      // Both halves shrink: a topic label and a photo count are each short, and
      // at a large text scale the pair still has to fit a 180dp column. Found
      // by the widget test before the device saw it.
      footer: Row(children: [
        Flexible(
          child: HealthPill(label: summary.topic.label, tint: tint),
        ),
        if (summary.photoCount > 0) ...[
          const SizedBox(width: 8),
          const Icon(LucideIcons.image, size: 11, color: HealthTone.faint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
                '${summary.photoCount} '
                '${summary.photoCount == 1 ? 'Photo' : 'Photos'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: HealthTone.faint, fontSize: 10.5)),
          ),
        ],
      ]),
      trailing: Text(stamp,
          style: const TextStyle(color: HealthTone.faint, fontSize: 11)),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// The glyph and tint a topic is drawn with.
///
/// The tints are decorative and, like `AssistantTone`, none of them is one of
/// the action ladder's four safety-locked hues — a red or amber disc beside a
/// chat title would read as a severity signal.
IconData topicIcon(ConversationTopic topic) => switch (topic) {
      ConversationTopic.health => LucideIcons.heartPulse,
      ConversationTopic.behavior => LucideIcons.dog,
      ConversationTopic.nutrition => LucideIcons.bone,
      ConversationTopic.grooming => LucideIcons.scissors,
      ConversationTopic.general => LucideIcons.sparkles,
    };

Color topicTint(BuildContext context, ConversationTopic topic) =>
    switch (topic) {
      ConversationTopic.health => PawTone.of(context).accent,
      ConversationTopic.behavior => HealthTone.teal,
      ConversationTopic.nutrition => HealthTone.gold,
      ConversationTopic.grooming => HealthTone.violet,
      ConversationTopic.general => HealthTone.info,
    };

// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.search, size: 16, color: HealthTone.muted),
        const SizedBox(width: 9),
        Expanded(
          child: TextField(
            key: const Key('history_search_field'),
            controller: controller,
            onChanged: onChanged,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Search your conversations…',
              hintStyle: TextStyle(color: HealthTone.faint, fontSize: 13.5),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The statistics strip. Every figure is counted from the rows on screen.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.all});

  final List<ConversationSummary> all;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = all
        .where((s) =>
            s.updatedAt.year == now.year && s.updatedAt.month == now.month)
        .length;
    final messages = all.fold<int>(0, (sum, s) => sum + s.messageCount);
    return HealthStatTiles(
      grouped: true,
      ringedIcons: true,
      title: 'Your conversation stats',
      stats: [
        HealthStat(
          icon: LucideIcons.messageCircle,
          value: '${all.length}',
          label: 'Conversations',
        ),
        HealthStat(
          icon: LucideIcons.calendarDays,
          value: '$thisMonth',
          label: 'This month',
        ),
        HealthStat(
          icon: LucideIcons.messagesSquare,
          value: '$messages',
          label: 'Messages',
        ),
      ],
    );
  }
}

class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: [
          Icon(icon, size: 28, color: HealthTone.muted),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}

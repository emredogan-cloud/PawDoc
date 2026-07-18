import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/analytics.dart';
import '../auth/supabase_providers.dart';
import '../core/action_labels.dart';
import '../core/dates.dart';
import '../core/pet_display.dart';
import '../export/health_report.dart';
import '../health/health_event.dart';
import '../health/health_events_repository.dart';
import '../health/weight_trend_card.dart';
import '../pets/pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// THE VET VISIT PREP PACK (evolution Phase 5 / E1) — the record product's
/// centerpiece, promoted from a share-sheet action buried in an overflow menu
/// to a first-class destination.
///
/// Answers the five questions every owner fails in the exam room: when did it
/// start · is it better or worse · what's been logged · which vaccines/meds ·
/// what did I want to ask. Zero AI judgment — it organizes what the OWNER
/// recorded, which is exactly why a vet can use it.
class VetVisitPrepScreen extends ConsumerStatefulWidget {
  const VetVisitPrepScreen({super.key, required this.pet});
  final Pet pet;

  @override
  ConsumerState<VetVisitPrepScreen> createState() => _VetVisitPrepScreenState();
}

/// Recent checks for the prep pack (action + observation + date; RLS-scoped).
final _recentChecksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('analyses')
      .select('action, observation, created_at')
      .eq('pet_id', petId)
      .order('created_at', ascending: false)
      .limit(5);
  return (rows as List).cast<Map<String, dynamic>>();
});

final _eventsProvider = FutureProvider.autoDispose
    .family<List<HealthEvent>, String>((ref, petId) {
  return ref.watch(healthEventsRepositoryProvider).listForPet(petId);
});

class _VetVisitPrepScreenState extends ConsumerState<VetVisitPrepScreen> {
  final _questions = TextEditingController();

  /// Prompts owners actually forget — general, non-diagnostic.
  static const suggestedQuestions = [
    'Is this weight still healthy for their age?',
    'Are the vaccinations up to date for our area?',
    'Anything in the recent checks that needs a closer look?',
    'What should I watch for at home after this visit?',
  ];

  @override
  void dispose() {
    _questions.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final analyses =
        ref.read(_recentChecksProvider(widget.pet.id!)).asData?.value ?? [];
    final events =
        ref.read(_eventsProvider(widget.pet.id!)).asData?.value ?? [];
    final text = buildVetVisitPrepPack(
      pet: widget.pet,
      recentAnalyses: analyses,
      events: events,
      ownerQuestions: _questions.text
          .split('\n')
          .where((q) => q.trim().isNotEmpty)
          .toList(),
    );
    await Analytics.healthReportExported();
    await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Vet visit prep — ${widget.pet.name}'));
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final checks = ref.watch(_recentChecksProvider(pet.id!));
    final events = ref.watch(_eventsProvider(pet.id!));

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.ink50),
          title: Text('Vet visit prep',
              style: const TextStyle(
                  color: AppColors.ink50, fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpace.s16),
          children: [
            Text(
              'Walk in with ${petDisplayName(pet.name)}’s story organized — '
              'the questions vets always ask, answered before they ask them.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.ink300),
            ),
            const SizedBox(height: AppSpace.s16),

            // Pet basics.
            PawCard(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(petDisplayName(pet.name),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.ink50)),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    [
                      speciesName(pet.species),
                      if (pet.breed?.isNotEmpty == true) pet.breed!,
                      if (pet.sex?.isNotEmpty == true) pet.sex!,
                      if (pet.weightKg != null) '${pet.weightKg} kg',
                    ].join(' · '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.ink300),
                  ),
                  if (pet.medicalNotes?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpace.s8),
                    Text('Notes: ${pet.medicalNotes}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.ink300)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            WeightTrendCard(petId: pet.id!),
            const SizedBox(height: AppSpace.s12),

            // Recent checks.
            _sectionTitle(context, 'Recent checks'),
            checks.maybeWhen(
              data: (list) => list.isEmpty
                  ? _muted(context, 'No checks recorded yet.')
                  : Column(
                      children: [
                        for (final a in list)
                          _rowCard(
                            context,
                            title: (a['observation'] as String?) ?? '',
                            subtitle: [
                              if (DateTime.tryParse(
                                      (a['created_at'] as String?) ?? '') !=
                                  null)
                                shortDate(DateTime.parse(
                                    a['created_at'] as String)),
                              actionLabel((a['action'] as String?) ?? ''),
                            ].join(' · '),
                          ),
                      ],
                    ),
              orElse: () => _muted(context, 'Loading…'),
            ),
            const SizedBox(height: AppSpace.s12),

            // Vaccines + meds extracted from the record.
            _sectionTitle(context, 'Vaccinations & medications'),
            events.maybeWhen(
              data: (list) {
                final rel = list
                    .where((e) =>
                        e.eventType == 'vaccination' ||
                        e.eventType == 'medication')
                    .toList(growable: false);
                if (rel.isEmpty) {
                  return _muted(context,
                      'Nothing logged yet — add them from Log event.');
                }
                return Column(children: [
                  for (final e in rel)
                    _rowCard(
                      context,
                      title: (e.metadata?['vaccine_name'] as String?) ??
                          e.notes ??
                          healthEventLabel(e.eventType),
                      subtitle: [
                        shortDate(e.eventDate),
                        healthEventLabel(e.eventType),
                        if ((e.metadata?['next_due'] as String?) != null)
                          'next due ${e.metadata!['next_due']}',
                      ].join(' · '),
                    ),
                ]);
              },
              orElse: () => _muted(context, 'Loading…'),
            ),
            const SizedBox(height: AppSpace.s16),

            // Owner questions.
            _sectionTitle(context, 'Questions to ask'),
            Text(
              'Tap to add, or write your own — they go at the end of the pack.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.ink300),
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final q in suggestedQuestions)
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      final cur = _questions.text.trim();
                      if (cur.contains(q)) return;
                      _questions.text = cur.isEmpty ? q : '$cur\n$q';
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            TextField(
              key: const Key('prep_questions_field'),
              controller: _questions,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'One question per line…',
                filled: true,
              ),
            ),
            const SizedBox(height: AppSpace.s20),

            PawPrimaryButton(
              key: const Key('prep_share_button'),
              icon: Icons.ios_share,
              onPressed: _share,
              child: const Text('Share the prep pack'),
            ),
            const SizedBox(height: AppSpace.s24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.ink50)),
      );

  Widget _muted(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.ink300)),
      );

  Widget _rowCard(BuildContext context,
          {required String title, required String subtitle}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: PawCard(
          padding: const EdgeInsets.all(AppSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.ink50)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.ink300)),
            ],
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/user_profile.dart';
import '../analytics/analytics.dart';
import '../core/app_image.dart';
import '../core/dates.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../export/health_report_service.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../reminders/reminders_screen.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import 'health_event_form_screen.dart';
import 'journal_card.dart';
import 'pdf_report_service.dart';
import 'timeline.dart';

/// The combined health-history timeline for the **active** pet (analyses +
/// manual events, newest first). Watches [activePetProvider], so switching the
/// active pet re-points the whole screen reactively.
///
/// Phase I restyle: a real vertical timeline (status-coloured nodes + date
/// grouping), a warm empty state, and the three ambiguous AppBar icons folded
/// into a single labeled overflow menu. Export/share/PDF/reminders logic is
/// unchanged — only moved + relabeled.
class HealthHistoryScreen extends ConsumerWidget {
  const HealthHistoryScreen({super.key});

  // --- Actions (logic unchanged; moved off the bare AppBar icons) ---

  Future<void> _shareMarkdown(BuildContext context, WidgetRef ref, Pet pet) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(healthReportServiceProvider).exportForPet(pet);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not prepare the report. Please try again.')),
      );
    }
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref, String petId, String petName) async {
    final messenger = ScaffoldMessenger.of(context);
    final profile = ref.read(userProfileProvider).asData?.value;
    await Analytics.pdfReportRequested(
      profile?.isPremium == true
          ? 'premium'
          : (profile?.pdfReportsRemaining ?? 0) > 0
              ? 'credits'
              : 'free',
    );
    try {
      await ref.read(pdfReportServiceProvider).generateAndShare(petId: petId, petName: petName);
      await Analytics.pdfReportGenerated();
      ref.invalidate(userProfileProvider); // reflect a consumed credit
    } on PdfReportPaywallException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Buy a PDF Health Report (\$4.99) or upgrade to Premium '
            'to unlock detailed exports.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not generate the PDF. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(activePetProvider);

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health history')),
        body: const Center(child: Text('Add a pet to start a health history.')),
      );
    }

    final timeline = ref.watch(healthTimelineProvider(pet.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('${petDisplayName(pet.name)}’s history'),
        actions: [
          PopupMenuButton<String>(
            key: const Key('history_actions_menu'),
            tooltip: 'Report & reminders',
            onSelected: (v) {
              switch (v) {
                case 'share':
                  _shareMarkdown(context, ref, pet);
                case 'pdf':
                  _exportPdf(context, ref, pet.id!, pet.name);
                case 'reminders':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemindersScreen()),
                  );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                key: Key('export_health_report'),
                value: 'share',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.ios_share),
                  title: Text('Share report'),
                ),
              ),
              PopupMenuItem(
                key: Key('generate_pdf_report'),
                value: 'pdf',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Export PDF'),
                ),
              ),
              PopupMenuItem(
                key: Key('open_reminders'),
                value: 'reminders',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.alarm),
                  title: Text('Reminders'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('log_event_fab'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final logged = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => HealthEventFormScreen(petId: pet.id!, petName: pet.name),
          ));
          ref.invalidate(healthTimelineProvider(pet.id!));
          if (logged == true) {
            messenger.showSnackBar(
              SnackBar(content: Text('Logged to ${petDisplayName(pet.name)}’s history')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Log event'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(healthTimelineProvider(pet.id!)),
        child: timeline.when(
          loading: () => ListView(
            children: const [
              SkeletonTimelineNode(),
              SkeletonTimelineNode(),
              SkeletonTimelineNode(),
            ],
          ),
          error: (e, _) => ListView(
            children: [Padding(padding: const EdgeInsets.all(AppSpace.s24), child: Text('Could not load history:\n$e'))],
          ),
          data: (items) {
            if (items.isEmpty) {
              return _HistoryEmptyState(petName: pet.name);
            }
            // Journal card on top, then date-grouped status-node timeline.
            final children = <Widget>[
              Padding(padding: const EdgeInsets.all(AppSpace.s8), child: JournalCard(petId: pet.id!)),
            ];
            String? lastBucket;
            for (var i = 0; i < items.length; i++) {
              final bucket = _dateBucket(items[i].date);
              if (bucket != lastBucket) {
                children.add(_GroupHeader(label: bucket));
                lastBucket = bucket;
              }
              children.add(_TimelineNode(item: items[i], isLast: i == items.length - 1));
            }
            if (reduceMotion(context)) {
              return ListView(children: children);
            }
            return ListView(
              children: [
                for (var i = 0; i < children.length; i++)
                  children[i].animate().fadeIn(
                      duration: AppMotion.standard,
                      delay: Duration(milliseconds: 30 * i)),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _dateBucket(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.s16, AppSpace.s16, AppSpace.s16, AppSpace.s4),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}

/// One timeline entry: a status-coloured node on a connecting rail + an entry
/// card (icon, title, subtitle, date, and a triage chip for analyses).
class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.item, required this.isLast});

  final TimelineItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _nodeColor(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail: status dot + connecting line.
          SizedBox(
            width: 36,
            child: Column(
              children: [
                const SizedBox(height: AppSpace.s16),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : scheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  right: AppSpace.s16, bottom: AppSpace.s8, top: AppSpace.s8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s12),
                  child: Row(
                    children: [
                      Icon(_iconFor(item), color: color),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: Theme.of(context).textTheme.titleSmall),
                            if (item.subtitle != null)
                              Text(item.subtitle!,
                                  style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Text(shortDate(item.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _nodeColor(BuildContext context) {
    if (item.kind == TimelineKind.analysis) {
      return switch (item.triageLevel) {
        'EMERGENCY' => AppColors.emergencyLight,
        'MONITOR' => AppColors.monitorLight,
        'NORMAL' => AppColors.normalLight,
        _ => Theme.of(context).colorScheme.primary,
      };
    }
    return Theme.of(context).colorScheme.primary;
  }

  static IconData _iconFor(TimelineItem item) {
    if (item.kind == TimelineKind.analysis) {
      return switch (item.triageLevel) {
        'EMERGENCY' => Icons.warning_amber_rounded,
        'MONITOR' => Icons.visibility_outlined,
        _ => Icons.health_and_safety_outlined,
      };
    }
    return switch (item.eventType) {
      'vaccination' => Icons.vaccines_outlined,
      'vet_visit' => Icons.local_hospital_outlined,
      'medication' => Icons.medication_outlined,
      'weight' => Icons.monitor_weight_outlined,
      _ => Icons.note_alt_outlined,
    };
  }
}

/// Warm, illustrated empty timeline — "your pet's health story starts here"
/// (turns the void into reassurance, §3.6.1). No journal upsell on an empty list.
class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: AppSpace.s48),
        AppImage(
          AppAssets.emptyHistory,
          height: 140,
          fallback: Icon(Icons.timeline_rounded, size: 72, color: scheme.primary),
        ),
        const SizedBox(height: AppSpace.s24),
        Text('${petDisplayName(petName)}’s health story starts here',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s32),
          child: Text(
            'Run a check or log an event — everything you track helps spot changes early.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

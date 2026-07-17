import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/user_profile.dart';
import '../analytics/analytics.dart';
import '../core/app_image.dart';
import '../core/app_motion_asset.dart';
import '../core/dates.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../export/health_report_service.dart';
import '../monetization/paywall_screen.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../reminders/reminders_screen.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'health_event_form_screen.dart';
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
///
/// NEW UI translation: wrapped in PawBackground (dark world), transparent
/// Scaffold, mint-accented timeline rail, PawCard entries, PawPrimaryButton CTA.
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
    final navigator = Navigator.of(context);
    final profile = ref.read(userProfileProvider).asData?.value;
    await Analytics.pdfReportRequested(
      profile?.isPremium == true ? 'premium' : 'free',
    );
    try {
      await ref.read(pdfReportServiceProvider).generateAndShare(petId: petId, petName: petName);
      await Analytics.pdfReportGenerated();
    } on PdfReportPaywallException {
      // GAP-E10: make the 402 actionable — surface the paywall, not a dead end.
      messenger.showSnackBar(
        SnackBar(
          content: const Text('PDF Health Reports are part of PawDoc Premium.'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: () => navigator.push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
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
      return PawBackground(
        variant: PawSurface.dark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Health history', style: TextStyle(color: AppColors.ink50)),
          ),
          body: const Center(
            child: Text(
              'Add a pet to start a health history.',
              style: TextStyle(color: AppColors.ink300),
            ),
          ),
        ),
      );
    }

    final timeline = ref.watch(healthTimelineProvider(pet.id!));

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.ink50),
          title: Text(
            "${petDisplayName(pet.name)}’s history",
            style: const TextStyle(
              color: AppColors.ink50,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              key: const Key('history_actions_menu'),
              tooltip: 'Report & reminders',
              icon: const Icon(Icons.more_vert, color: AppColors.ink50),
              color: const Color(0xFF1A2220),
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
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: PawPalette.mint,
                backgroundColor: const Color(0xFF1A2220),
                onRefresh: () async => ref.invalidate(healthTimelineProvider(pet.id!)),
                child: timeline.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s16, vertical: AppSpace.s8),
                    children: const [
                      SkeletonTimelineNode(),
                      SkeletonTimelineNode(),
                      SkeletonTimelineNode(),
                    ],
                  ),
                  error: (e, _) => ListView(
                    padding: const EdgeInsets.all(AppSpace.s24),
                    children: [
                      Text(
                        'Could not load history:\n$e',
                        style: const TextStyle(color: AppColors.ink300),
                      ),
                    ],
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return _HistoryEmptyState(petName: pet.name);
                    }
                    // Date-grouped status-node timeline.
                    final children = <Widget>[];
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
                      return ListView(
                        padding: const EdgeInsets.only(bottom: AppSpace.s16),
                        children: children,
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.only(bottom: AppSpace.s16),
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
            ),
            // "+ Log event" CTA pinned at the bottom (replaces the FAB).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.s24, AppSpace.s8, AppSpace.s24, AppSpace.s24),
              child: PawPrimaryButton(
                key: const Key('log_event_fab'),
                icon: Icons.add,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final logged = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          HealthEventFormScreen(petId: pet.id!, petName: pet.name),
                    ),
                  );
                  ref.invalidate(healthTimelineProvider(pet.id!));
                  if (logged == true) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Row(children: [
                          const Icon(Icons.pets_rounded, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  "Logged to ${petDisplayName(pet.name)}'s history")),
                        ]),
                      ),
                    );
                  }
                },
                child: const Text('Log event'),
              ),
            ),
          ],
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.ink50,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

/// One timeline entry: a status-coloured node on a connecting rail + a PawCard
/// (icon, title, subtitle, date, and a triage chip for analyses).
class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.item, required this.isLast});

  final TimelineItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _nodeColor(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail: status dot + connecting line.
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: AppSpace.s16),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : PawPalette.teal.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  right: AppSpace.s16, bottom: AppSpace.s8, top: AppSpace.s8),
              child: PawCard(
                padding: const EdgeInsets.all(AppSpace.s12),
                radius: AppRadius.md,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(_iconFor(item), size: 18, color: color),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.ink50,
                                ),
                          ),
                          if (item.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.ink300,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shortDate(item.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.ink300,
                              ),
                        ),
                        if (item.triageLevel != null) ...[
                          const SizedBox(height: AppSpace.s4),
                          _TriageChip(level: item.triageLevel!),
                        ],
                      ],
                    ),
                  ],
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
        _ => PawPalette.mint,
      };
    }
    return PawPalette.mint;
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

/// Small status chip shown on triage timeline entries.
class _TriageChip extends StatelessWidget {
  const _TriageChip({required this.level});
  final String level;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      'EMERGENCY' => ('Emergency', AppColors.emergencyLight),
      'MONITOR' => ('Monitor', AppColors.monitorLight),
      'NORMAL' => ('Healthy', AppColors.normalLight),
      _ => ('Check', PawPalette.mint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8, vertical: AppSpace.s4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Warm, illustrated empty timeline — "your pet's health story starts here"
/// (turns the void into reassurance, §3.6.1). No journal upsell on an empty list.
class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s32),
      children: [
        const SizedBox(height: AppSpace.s48),
        // M1 (matrix #8): "story starts here" art breathes, trail sparkles
        // twinkle; static PNG under reduce-motion / load failure.
        AppMotionAsset(
          AppMotionAssets.historyEmptyLoop,
          fallbackAsset: AppAssets.resultHistoryEmpty,
          height: 140,
          fallback: AppImage(
            AppAssets.resultHistoryEmpty,
            height: 120,
            fallback: const Icon(Icons.nightlight_round, size: 64, color: PawPalette.mint),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        Text(
          "${petDisplayName(petName)}'s health story starts here",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.ink50,
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'Run a check or log an event — everything you track helps spot changes early.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink300,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

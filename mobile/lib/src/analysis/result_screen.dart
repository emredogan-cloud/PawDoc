import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../analytics/analytics.dart';
import '../health/timeline.dart';
import '../reminders/reminders_screen.dart';
import '../pets/active_pet.dart';
import '../health/health_event_form_screen.dart';
import '../theme/app_assets.dart';
import '../theme/paw_components.dart';
import '../home/home_sections.dart';
import '../health_check/result_sections.dart';
import '../health_check/health_check_chrome.dart';
import '../assistant/assistant_screen.dart';
import '../config/legal_urls.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../feedback/result_feedback_widget.dart';
import '../models/analysis_result.dart';
import '../reminders/reminder.dart';
import '../reminders/reminders_repository.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import '../vet_finder/maps_links.dart';
import 'emergency_result_screen.dart';

/// Routes to the GET_HELP_NOW screen or the standard result screen.
/// [analysisId] (null if the row failed to store) gates the in-app feedback
/// widget. [petName] feeds the "Saved to {Pet}'s history" confirmation —
/// standard screen ONLY; the GET_HELP_NOW screen receives no motion or
/// celebration additions, ever.
class ResultScreen extends StatelessWidget {
  const ResultScreen(
      {super.key,
      required this.result,
      this.analysisId,
      this.onDone,
      this.petId,
      this.petName,
      this.petSpecies,
      this.petPhotoKey,
      this.firstCheckToast = false});
  final AnalysisResult result;
  final String? analysisId;
  final VoidCallback? onDone;

  /// Enables the re-check reminder CTA on WATCH_AND_RECHECK results.
  final String? petId;
  final String? petName;

  /// M2 (#13): enables the attentive avatar beat on the standard screen.
  /// GET_HELP_NOW ignores it entirely — that screen renders zero rig.
  final String? petSpecies;

  /// The owner's pet photo, shown instead of the species rig when set.
  final String? petPhotoKey;

  /// M3 (#17): the one-time-ever "story has begun" toast. The runner only
  /// sets this for non-emergency results; the emergency route ignores it.
  final bool firstCheckToast;

  @override
  Widget build(BuildContext context) {
    if (result.action == ActionLevel.getHelpNow) {
      // `petSpecies` reaches the emergency screen only as a STILL portrait for
      // the mockup's photo slot — never the rig. `no_motion_on_safety_surfaces_test`
      // still pins zero motion widgets there.
      return EmergencyResultScreen(result: result, petSpecies: petSpecies);
    }
    return StandardResultScreen(
        result: result,
        analysisId: analysisId,
        onDone: onDone,
        petId: petId,
        petName: petName,
        petSpecies: petSpecies,
        petPhotoKey: petPhotoKey,
        firstCheckToast: firstCheckToast);
  }
}

// Safety-locked action hues (contract v2 ladder). Never colour alone (a11y) —
// each pairs with a distinct icon + text label. Deliberately no green anywhere:
// the floor is calm slate, never "all clear".
Color _actionColor(ActionLevel a) => switch (a) {
      ActionLevel.getHelpNow => AppColors.emergencyLight,
      ActionLevel.callToday => AppColors.monitorLight,
      ActionLevel.bookVisit => AppColors.actionBookVisit,
      ActionLevel.watchAndRecheck => AppColors.actionWatch,
    };

IconData _actionIcon(ActionLevel a) => switch (a) {
      ActionLevel.getHelpNow => Icons.warning_amber_rounded,
      ActionLevel.callToday => Icons.phone_in_talk_rounded,
      ActionLevel.bookVisit => Icons.event_available_rounded,
      ActionLevel.watchAndRecheck => Icons.visibility_outlined,
    };

String _actionLabel(ActionLevel a) => switch (a) {
      ActionLevel.getHelpNow => 'GET HELP NOW',
      ActionLevel.callToday => 'CALL YOUR VET TODAY',
      ActionLevel.bookVisit => 'BOOK A ROUTINE VISIT',
      ActionLevel.watchAndRecheck => 'WATCH AND RE-CHECK',
    };

/// The hardcoded escalation floor — ALWAYS shown, merged with the AI's
/// specific watch_for signs. Not AI output; can never be prompted away.
const _escalationTriggers = [
  'Symptoms get worse or new ones appear',
  'Your pet stops eating or drinking',
  'You feel something is wrong',
];

class StandardResultScreen extends ConsumerStatefulWidget {
  const StandardResultScreen(
      {super.key,
      required this.result,
      this.analysisId,
      this.onDone,
      this.petId,
      this.petName,
      this.petSpecies,
      this.petPhotoKey,
      this.firstCheckToast = false});
  final AnalysisResult result;
  final String? analysisId;
  final VoidCallback? onDone;
  final String? petId;
  final String? petName;
  final String? petSpecies;
  final String? petPhotoKey;
  final bool firstCheckToast;

  @override
  ConsumerState<StandardResultScreen> createState() => _StandardResultScreenState();
}

class _StandardResultScreenState extends ConsumerState<StandardResultScreen> {
  OverlayEntry? _storyToast;
  bool _recheckScheduled = false;
  bool _schedulingRecheck = false;

  @override
  void initState() {
    super.initState();
    Analytics.resultViewed(widget.result.action.wireValue);
    if (widget.firstCheckToast && widget.petName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showStoryToast());
    }
  }

  /// M3 (#17): one-time-ever toast — 1.5s, tap-skippable, never blocks
  /// anything (overlay above the screen). Reduce-motion: plain snackbar.
  void _showStoryToast() {
    if (!mounted) return;
    final message = '${petDisplayName(widget.petName!)}’s story has begun';
    if (reduceMotion(context)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    _storyToast = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        right: 0,
        bottom: 96,
        child: Center(
          child: GestureDetector(
            onTap: _removeStoryToast, // tap = skip
            child: Material(
              color: Colors.transparent,
              child: Container(
                key: const Key('first_check_toast'),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16, vertical: AppSpace.s12),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pets_rounded,
                        size: 18, color: scheme.onInverseSurface),
                    const SizedBox(width: AppSpace.s8),
                    Text(message,
                        style: TextStyle(color: scheme.onInverseSurface)),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 220))
                  .slideY(begin: 0.4, end: 0, curve: AppMotion.emphasized)
                  .then(delay: const Duration(milliseconds: 1500))
                  .fadeOut(duration: const Duration(milliseconds: 280)),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_storyToast!);
    Future<void>.delayed(const Duration(seconds: 2, milliseconds: 200),
        _removeStoryToast);
  }

  void _removeStoryToast() {
    _storyToast?.remove();
    _storyToast = null;
  }

  @override
  void dispose() {
    _removeStoryToast();
    super.dispose();
  }

  Future<void> _share() async {
    final r = widget.result;
    // Record framing: share what was OBSERVED plus the action — never a verdict.
    final text = 'PawDoc check — ${_actionLabel(r.action)}.\n'
        '${r.observation}\n\n'
        'Shared via PawDoc 🐾';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// WATCH_AND_RECHECK CTA: one tap schedules the re-check as a reminder row.
  /// (On-device notification delivery is wired in the reminders phase.)
  Future<void> _scheduleRecheck() async {
    final petId = widget.petId;
    final hours = widget.result.recheckHours ?? 24;
    if (petId == null || _schedulingRecheck) return;
    setState(() => _schedulingRecheck = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final due = DateTime.now().add(Duration(hours: hours));
      await ref.read(remindersRepositoryProvider).create(Reminder(
            petId: petId,
            reminderType:
                'Re-check ${petDisplayName(widget.petName ?? 'your pet')}',
            dueDate: due,
          ));
      await Analytics.reminderSet('recheck');
      if (mounted) setState(() => _recheckScheduled = true);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not schedule the re-check. Please try again.')));
      if (mounted) setState(() => _schedulingRecheck = false);
    }
  }

  /// Checks per week over the last six, normalised for the sparkline.
  List<double> _checksPerWeek() {
    final id = widget.petId;
    if (id == null) return const [];
    final items = ref.read(healthTimelineProvider(id)).value;
    if (items == null || items.length < 2) return const [];
    final now = DateTime.now();
    final buckets = List<double>.filled(6, 0);
    for (final e in items) {
      final weeks = now.difference(e.date).inDays ~/ 7;
      if (weeks >= 0 && weeks < 6) buckets[5 - weeks] += 1;
    }
    final peak = buckets.reduce((a, b) => a > b ? a : b);
    if (peak == 0) return const [];
    return [for (final b in buckets) (b / peak) * 0.9 + 0.05];
  }

  /// "in 2 days" / "in 12 hours" — the phrasing the mockup's reminder row uses.
  String _recheckIn(int hours) {
    if (hours % 24 == 0) {
      final days = hours ~/ 24;
      return days == 1 ? 'again tomorrow' : 'again in $days days';
    }
    return 'again in $hours hours';
  }

  String _recheckLabel(int hours) {
    if (hours % 24 == 0) {
      final days = hours ~/ 24;
      return days == 1 ? 'Re-check me in 1 day' : 'Re-check me in $days days';
    }
    return 'Re-check me in $hours hours';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    // The AI's specific signs first, then the hardcoded floor (deduped) — the
    // floor triggers can never be prompted away.
    final watchFor = <String>[
      ...r.watchFor,
      for (final t in _escalationTriggers)
        if (!r.watchFor.contains(t)) t,
    ];

    // Mockups `ai_analysis_result_low_risk` / `_monitor`: the node rail with
    // Results lit, a split hero, the action card, the AI summary, two list
    // cards, the recommendation rows, the three-button bar, the trend and
    // score cells, and the assistant strip. See `result_sections.dart` for
    // what those mockups claim and what ships in its place.
    // Two different colours, deliberately. `accent` dresses the page; the
    // action card takes the ladder's SAFETY-LOCKED hue, which is calm slate at
    // the floor and never a reassuring green.
    final tint = PawTone.of(context).accent;
    final actionTint = _actionColor(r.action);
    final name = petDisplayName(widget.petName ?? 'your pet');
    final pet = ref.watch(activePetProvider);
    final score = pet == null
        ? 45
        : careScore(pet,
            hasCheck: true, hasReminder: _recheckScheduled);

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const HealthCheckAppBar(),
        // A Column in a scroll view rather than a lazy ListView: the result is
        // ~15 blocks, and laziness meant the "saved to history" chip and the
        // Paw Pal simply did not exist until scrolled to — which is also how a
        // screen reader would have found them.
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          // M1 (matrix #7): sections fade-up in 280ms beats instead of popping
          // in; instant under reduce-motion. Decorative only — every element is
          // present and hittable from the first frame.
          children: _staggered(context, [
            const HealthCheckSteps(current: 4, steps: healthCheckSteps5),
            const SizedBox(height: AppSpace.s20),
            ResultHero(
              // The mockup opens "Good news! / No signs of a serious
              // condition". An output may never terminate on reassurance, so
              // the headline is what the check is *for*.
              headline: 'Here’s what our AI found',
              deck: 'This is not a diagnosis. If symptoms persist or worsen, '
                  'please consult your veterinarian.',
              tint: tint,
              photo: widget.petSpecies == null
                  ? null
                  : Image.asset(AppAssets.species(widget.petSpecies!),
                      fit: BoxFit.cover, excludeFromSemantics: true),
            ),
            const SizedBox(height: AppSpace.s12),
            ResultActionCard(
              action: _actionLabel(r.action),
              icon: _actionIcon(r.action),
              detail: r.urgencyTimeframe,
              chip: r.recheckHours == null
                  ? 'Keep watching'
                  : _recheckLabel(r.recheckHours!),
              tint: actionTint,
            ),
            if (widget.petSpecies != null) ...[
              const SizedBox(height: AppSpace.s12),
              // M2 (#13): the pet stays ATTENTIVE on every standard result —
              // the avatar never signals "all clear". GET_HELP_NOW never
              // reaches this screen.
              Center(
                child: LivingPetAvatar(
                  species: widget.petSpecies!,
                  size: 64,
                  seed: widget.analysisId,
                  photoKey: widget.petPhotoKey,
                  mountBeat: PalBeat.attentive,
                ),
              ),
            ],
            if (widget.analysisId != null && widget.petName != null) ...[
              const SizedBox(height: AppSpace.s12),
              _SavedConfirmation(petName: widget.petName!),
            ],
            const SizedBox(height: AppSpace.s12),
            ResultSummaryCard(
                body: r.observation, stamp: 'Generated just now', tint: tint),
            const SizedBox(height: AppSpace.s12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ResultListCard(
                      icon: LucideIcons.search,
                      // The mockup's heavier left cell — a named cause, a
                      // confidence pill and a ranked differential. It carries
                      // what the OWNER reported instead, with the pill saying
                      // where that came from rather than how sure anything is.
                      title: 'What we noticed',
                      lead: r.visibleSymptoms.isEmpty
                          ? 'Nothing specific stood out'
                          : r.visibleSymptoms.first,
                      chip: 'From what you described',
                      items: r.visibleSymptoms.skip(1).toList(),
                      emptyLabel: r.visibleSymptoms.isEmpty
                          ? 'Add a photo or more detail for a closer look.'
                          : null,
                      tint: tint,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: ResultListCard(
                      icon: LucideIcons.stethoscope,
                      // Educational: what a vet looks at with this KIND of
                      // presentation, never a finding about this animal.
                      title: 'What vets look for',
                      items: r.vetsLookFor,
                      emptyLabel: 'Your vet will examine this in person.',
                      tint: tint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            HomeCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(LucideIcons.heartPulse, size: 17, color: tint),
                    const SizedBox(width: 7),
                    const Text('Recommendations',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  for (var i = 0; i < r.recommendedActions.length; i++)
                    ResultActionRow(
                      icon: LucideIcons.circleCheck,
                      title: r.recommendedActions[i],
                      detail: i == r.recommendedActions.length - 1
                          ? r.urgencyTimeframe
                          : 'Step ${i + 1}',
                      badge: i == r.recommendedActions.length - 1
                          ? 'Timing'
                          : 'Care',
                      tint: tint,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            // "Call sooner if you see" — the AI's signs plus the hardcoded
            // floor, deduped. The floor triggers can never be prompted away.
            ResultListCard(
              icon: LucideIcons.triangleAlert,
              title: 'Call sooner if you see',
              items: watchFor,
              tint: tint,
            ),
            const SizedBox(height: AppSpace.s12),
            if (r.action == ActionLevel.callToday ||
                r.action == ActionLevel.bookVisit) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('result_find_vet'),
                  onPressed: () {
                    Analytics.vetFinderOpened();
                    launchUrl(vetSearchMapsUri(),
                        mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.local_hospital_outlined),
                  label: const Text('Find a nearby vet'),
                ),
              ),
              const SizedBox(height: AppSpace.s8),
            ],
            if (r.action == ActionLevel.watchAndRecheck &&
                widget.petId != null) ...[
              // The mockup's "Reminder set · We'll remind you to check Buddy
              // again in 2 days · View Reminder" row — live, not decorative.
              // It appears once the re-check is actually scheduled.
              if (_recheckScheduled)
                ResultReminderRow(
                  detail: 'We’ll remind you to check $name '
                      '${_recheckIn(r.recheckHours ?? 24)}.',
                  onView: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RemindersScreen())),
                  tint: tint,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    key: const Key('result_recheck'),
                    onPressed: _schedulingRecheck ? null : _scheduleRecheck,
                    icon: const Icon(Icons.update_rounded),
                    label: Text(_recheckLabel(r.recheckHours ?? 24)),
                  ),
                ),
              const SizedBox(height: AppSpace.s8),
            ],
            ResultGuideStrip(
              title: 'When to see a vet?',
              detail: watchFor.isEmpty
                  ? 'Know the signs that mean it should not wait.'
                  : watchFor.first,
              onOpen: () => LegalUrls.open(LegalUrls.vetDisclaimer),
              tint: tint,
            ),
            const SizedBox(height: AppSpace.s12),
            ResultActionBar(
              shareKey: const Key('result_share'),
              // The PDF export exists for the vet-prep pack, not yet from a
              // single result — so the mockup's button stays put and says so.
              saveSoon: true,
              onSave: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Saving a single result as a PDF is coming soon. '
                          'Share with Vet sends it now.'))),
              onShare: _share,
              onDiary: widget.petId == null
                  ? _share
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => HealthEventFormScreen(
                            petId: widget.petId!, petName: name),
                      )),
              tint: tint,
            ),
            const SizedBox(height: AppSpace.s12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ResultTrendCard(
                      petName: name,
                      // Checks logged over the last six weeks — activity, not
                      // severity. A line that trended "better" or "worse"
                      // would be a graded verdict drawn from nothing.
                      points: _checksPerWeek(),
                      onTap: () => context.push('/history'),
                      tint: tint,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    // The mockup's "Health Score 92 · Excellent". D-2: wellness
                    // only, never a verdict — so it counts how complete the
                    // record is, off the real pet, and says exactly that.
                    child: ResultStatusCard(
                      label: 'Care Score',
                      value: 'Record $score% complete',
                      caption: score >= 85
                          ? 'This check is part of it.'
                          : 'Add more detail to $name’s profile.',
                      tint: tint,
                      ring: score / 100,
                      ringLabel: '$score',
                      onTap: () => context.push('/pets'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            ResultAssistantStrip(
              title: 'Still have questions?',
              detail: 'Ask PawDoc AI for more about $name.',
              onAsk: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AssistantScreen())),
              tint: tint,
            ),
            // In-app feedback (Phase 4.1) — only when the analysis was stored.
            if (widget.analysisId != null) ...[
              const SizedBox(height: AppSpace.s16),
              ResultFeedbackWidget(analysisId: widget.analysisId!),
            ],
            if (r.disclaimerRequired) ...[
              const SizedBox(height: AppSpace.s16),
              // The disclaimer card is tappable and opens the full Veterinary
              // Disclaimer page. Whether it shows at all is forced server-side.
              GestureDetector(
                onTap: () => LegalUrls.open(LegalUrls.vetDisclaimer),
                behavior: HitTestBehavior.opaque,
                child: HomeCard(
                  padding: const EdgeInsets.all(AppSpace.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFF9BA5A0)),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          // GAP-E13: localized (en/de). Null-safe EN fallback
                          // so this safety string is NEVER empty if delegates
                          // are absent.
                          AppLocalizations.of(context)?.resultDisclaimer ??
                              'PawDoc provides information, not a veterinary diagnosis. When in doubt, contact your vet.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB8C2BB),
                              height: 1.35),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: Color(0xFF9BA5A0)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('result_done'),
                onPressed:
                    widget.onDone ?? () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ),
            ]),
          ),
        ),
      ),
    );
  }


  /// 280ms fade-up beats, 40ms apart (M1 #7). Widgets are in the tree (and
  /// tappable) immediately; only opacity/offset animate. Reduce-motion: none.
  List<Widget> _staggered(BuildContext context, List<Widget> children) {
    if (reduceMotion(context)) return children;
    return [
      for (var i = 0; i < children.length; i++)
        children[i]
            .animate()
            .fadeIn(
                duration: const Duration(milliseconds: 280),
                delay: Duration(milliseconds: 40 * i))
            .slideY(
                begin: 0.04,
                end: 0,
                duration: const Duration(milliseconds: 280),
                curve: AppMotion.emphasized),
    ];
  }
}

/// M1 (matrix #7): the quiet "it's in the record" reassurance beat — a calm
/// confirmation chip, not a celebration. Slides in after the action lands;
/// static under reduce-motion.
class _SavedConfirmation extends StatelessWidget {
  const _SavedConfirmation({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Container(
      key: const Key('result_saved_confirmation'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpace.s8),
          Flexible(
            child: Text(
              'Saved to ${petDisplayName(petName)}’s history',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
    if (reduceMotion(context)) return chip;
    return chip
        .animate()
        .fadeIn(
            delay: const Duration(milliseconds: 400),
            duration: const Duration(milliseconds: 280))
        .slideY(
            begin: -0.3,
            end: 0,
            delay: const Duration(milliseconds: 400),
            duration: const Duration(milliseconds: 280),
            curve: AppMotion.emphasized);
  }
}

/// Action hero: colour + distinct shape (icon) + text label + timeframe —
/// never colour alone (a11y). AA on-colour; live-region announces the action

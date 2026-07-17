import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../analytics/analytics.dart';
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

  /// M3 (#17): the one-time-ever "story has begun" toast. The runner only
  /// sets this for non-emergency results; the emergency route ignores it.
  final bool firstCheckToast;

  @override
  Widget build(BuildContext context) {
    if (result.action == ActionLevel.getHelpNow) {
      return EmergencyResultScreen(result: result);
    }
    return StandardResultScreen(
        result: result,
        analysisId: analysisId,
        onDone: onDone,
        petId: petId,
        petName: petName,
        petSpecies: petSpecies,
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

// On-colour for the action hero. CALL_TODAY amber is light → dark text/icon
// for AA contrast; the saturated red/blue/slate carry white.
Color _actionOnColor(ActionLevel a) =>
    a == ActionLevel.callToday ? AppColors.ink900 : Colors.white;

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
      this.firstCheckToast = false});
  final AnalysisResult result;
  final String? analysisId;
  final VoidCallback? onDone;
  final String? petId;
  final String? petName;
  final String? petSpecies;
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

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Result'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        // M1 (matrix #7): sections fade-up in 280ms beats instead of popping
        // in; instant under reduce-motion. Decorative only — every element is
        // present and hittable from the first frame.
        children: _staggered(context, [
          _ActionHero(action: r.action, timeframe: r.urgencyTimeframe),
          // M2 (#13): the pet stays ATTENTIVE on every standard result — the
          // avatar never signals "all clear" (no happy/relief beat; the app
          // does not own reassurance). GET_HELP_NOW never reaches this screen.
          if (widget.petSpecies != null) ...[
            const SizedBox(height: 12),
            Center(
              child: LivingPetAvatar(
                species: widget.petSpecies!,
                size: 64,
                seed: widget.analysisId,
                mountBeat: PalBeat.attentive,
              ),
            ),
          ],
          // "Saved to {Pet}'s history" — only when the row truly stored
          // (honesty: confirmations fire on real events only).
          if (widget.analysisId != null && widget.petName != null) ...[
            const SizedBox(height: 12),
            _SavedConfirmation(petName: widget.petName!),
          ],
          const SizedBox(height: 16),
          _section('What we observed', [r.observation]),
          if (r.visibleSymptoms.isNotEmpty) ...[
            const SizedBox(height: 16),
            _section('What we noticed', [for (final s in r.visibleSymptoms) '• $s']),
          ],
          if (r.vetsLookFor.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Educational: about this KIND of presentation — never findings
            // or condition names about this animal.
            _section('What vets look for with this', [for (final v in r.vetsLookFor) '• $v']),
          ],
          const SizedBox(height: 16),
          _section('Call sooner if you see', [for (final w in watchFor) '• $w']),
          if (r.recommendedActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _section('What to do', [
              for (var i = 0; i < r.recommendedActions.length; i++)
                '${i + 1}. ${r.recommendedActions[i]}',
            ]),
          ],
          const SizedBox(height: 16),
          _section('Timing', [r.urgencyTimeframe]),
          if (r.disclaimerRequired) ...[
            const SizedBox(height: 16),
            // The disclaimer card is tappable and opens the full Veterinary
            // Disclaimer page.
            GestureDetector(
              onTap: () => LegalUrls.open(LegalUrls.vetDisclaimer),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(AppSpace.s12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        // GAP-E13: localized (en/de). Null-safe EN fallback so
                        // this safety string is NEVER empty if delegates are
                        // absent. The server still forces WHETHER it shows.
                        AppLocalizations.of(context)?.resultDisclaimer ??
                            'PawDoc provides information, not a veterinary diagnosis. When in doubt, contact your vet.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Per-action CTAs. CALL_TODAY / BOOK_VISIT surface the maps deep
          // link (no location permission — the OS handles it); the floor
          // surfaces the one-tap re-check.
          if (r.action == ActionLevel.callToday ||
              r.action == ActionLevel.bookVisit) ...[
            OutlinedButton.icon(
              key: const Key('result_find_vet'),
              onPressed: () {
                Analytics.vetFinderOpened();
                launchUrl(vetSearchMapsUri(),
                    mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.local_hospital_outlined),
              label: const Text('Find a nearby vet'),
            ),
            const SizedBox(height: 8),
          ],
          if (r.action == ActionLevel.watchAndRecheck && widget.petId != null) ...[
            FilledButton.tonalIcon(
              key: const Key('result_recheck'),
              onPressed: _recheckScheduled || _schedulingRecheck
                  ? null
                  : _scheduleRecheck,
              icon: Icon(_recheckScheduled
                  ? Icons.check_rounded
                  : Icons.update_rounded),
              label: Text(_recheckScheduled
                  ? 'Re-check scheduled'
                  : _recheckLabel(r.recheckHours ?? 24)),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            key: const Key('result_share'),
            onPressed: _share,
            icon: const Icon(Icons.share),
            label: const Text('Share this entry'),
          ),
          // In-app feedback (Phase 4.1) — only when the analysis was stored.
          if (widget.analysisId != null) ...[
            const SizedBox(height: 16),
            ResultFeedbackWidget(analysisId: widget.analysisId!),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('result_done'),
              onPressed: widget.onDone ?? () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ),
        ]),
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

  Widget _section(String title, List<String> lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final l in lines) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l)),
        ],
      );
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
/// first. Gentle reduce-motion-gated reveal; no bounce.
class _ActionHero extends StatelessWidget {
  const _ActionHero({required this.action, required this.timeframe});
  final ActionLevel action;
  final String timeframe;

  @override
  Widget build(BuildContext context) {
    final onColor = _actionOnColor(action);
    final hero = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s20),
      decoration: BoxDecoration(
        color: _actionColor(action),
        borderRadius: AppRadius.brXl,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_actionIcon(action), color: onColor, size: 28),
              const SizedBox(width: AppSpace.s12),
              Flexible(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _actionLabel(action),
                    style: TextStyle(
                        color: onColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            timeframe,
            style: TextStyle(
                color: onColor.withValues(alpha: 0.9), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    if (reduceMotion(context)) return hero;
    return hero.animate().fadeIn(duration: AppMotion.standard).scaleXY(
        begin: 0.98,
        end: 1.0,
        duration: AppMotion.standard,
        curve: AppMotion.emphasized);
  }
}

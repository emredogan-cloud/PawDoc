import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/profile_screen.dart';
import '../account/user_profile.dart';
import '../analysis/analysis_service.dart';
import '../assistant/assistant_screen.dart';
import '../community/community_card.dart';
import '../core/action_labels.dart';
import '../core/app_motion_asset.dart';
import '../core/app_views.dart';
import '../core/connectivity.dart';
import '../core/friendly_error.dart';
import '../core/last_check.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../emergency/emergency_help_screen.dart';
import '../encyclopedia/encyclopedia_screen.dart';
import '../feedback/followup_banner.dart';
import '../health/breed_insight_card.dart';
import '../health/health_event_form_screen.dart';
import '../health/timeline.dart';
import '../memories/memories_screen.dart';
import '../pets/active_pet.dart';
import '../pets/add_pet_flow.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../health_check/health_check_start_screen.dart';
import 'home_sections.dart';
import '../prep/vet_visit_prep_screen.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import '../walks/walk_card.dart';

/// Sentinel value for the "Add pet" entry in the pet switcher menu.
const _addPetSentinel = '__add_pet__';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// The hero CTA now opens the guided AI Health Check (mockups
  /// `ai_health_check_start` → `photo_analysis_upload` → `symptom_selection`
  /// → `ai_analysis_loading`) rather than the two-way capture sheet.
  Future<void> _healthCheck(
      BuildContext context, WidgetRef ref, Pet pet, bool isPremium) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HealthCheckStartScreen(pet: pet, isPremium: isPremium),
    ));
    ref.invalidate(userProfileProvider);
    ref.invalidate(latestTriageProvider(pet.id!));
  }

  Future<void> _logEvent(BuildContext context, WidgetRef ref, Pet pet) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => HealthEventFormScreen(petId: pet.id!, petName: pet.name),
    ));
    ref.invalidate(healthTimelineProvider(pet.id!));
  }

  /// Emergency must stay reachable even when the pet list can't load (e.g. an
  /// offline cold start) — the red path is offline-capable and must never be
  /// gated behind a network fetch.
  Widget _petsErrorBody(WidgetRef ref, Object error) => Column(
        children: [
          const EmergencyHelpButton(),
          const SizedBox(height: AppSpace.s12),
          AppErrorView(
            message: friendlyLoadError(error, noun: 'pets'),
            onRetry: () => ref.invalidate(petsListProvider),
          ),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsListProvider);
    final profile = ref.watch(userProfileProvider);
    final activePet = ref.watch(activePetProvider);

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // No AppBar: mockup `010` opens with a brand bar that scrolls with the
        // page, so the pet rail can sit flush beneath it. Account keeps its
        // key and moves onto the avatar at the bar's right.
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(petsListProvider);
          ref.invalidate(userProfileProvider);
          final id = activePet?.id;
          if (id != null) {
            ref.invalidate(healthTimelineProvider(id));
            // F-2: pull-to-refresh also refreshes the hero's last-check line.
            ref.invalidate(latestTriageProvider(id));
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.s16, AppSpace.s4, AppSpace.s16, AppSpace.s16),
          children: [
            HomeBrandBar(
              switcher: petsAsync.maybeWhen(
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : _PetSwitcher(pets: list, active: activePet),
                orElse: () => const SizedBox.shrink(),
              ),
              hasNotifications: true,
              onNotifications: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              ),
              onAccount: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            const OfflineBanner(),
            // 72h "was this helpful?" follow-up (self-hides when nothing pending).
            const FollowUpBanner(),
            petsAsync.when(
              // Skeletons matching the final layout (§4.3); static under reduce-motion.
              // Emergency stays reachable while pets load.
              //
              // Riverpod 3 retries a failed provider on its own, and each retry
              // puts the value back into AsyncLoading while *retaining* the last
              // error — so an offline cold start would sit on these skeletons
              // forever and never reach `error:` below. When we have an error and
              // have never had data, show the error body instead of pretending to
              // still be loading. (A failed *refresh* over existing data keeps the
              // skeletons: the retry usually wins and the flicker isn't worth it.)
              loading: () => petsAsync.hasError && !petsAsync.hasValue
                  ? _petsErrorBody(ref, petsAsync.error!)
                  : const Column(
                      children: [
                        EmergencyHelpButton(),
                        SizedBox(height: AppSpace.s12),
                        SkeletonCard(height: 120),
                        SizedBox(height: AppSpace.s8),
                        SkeletonCard(height: 72),
                        SizedBox(height: AppSpace.s8),
                        SkeletonCard(height: 44),
                      ],
                    ),
              error: (e, _) => _petsErrorBody(ref, e),
              data: (list) {
                if (list.isEmpty) {
                  return _HomeEmptyState(
                    freeRemaining: profile.maybeWhen(
                      data: (p) => p.isPremium ? null : p.photoLogsRemaining,
                      orElse: () => null,
                    ),
                    onAddPet: () => context.push('/onboarding'),
                  );
                }
                final isPremium =
                    profile.maybeWhen(data: (p) => p.isPremium, orElse: () => false);
                final pet = activePet ?? list.first;
                // The order mockup `010` lays out: pet rail → greeting → hero →
                // quick actions → the two insight columns → the pill grid →
                // the stat strip → the quota line.
                final content = <Widget>[
                  PetRail(
                    pets: list,
                    activeId: pet.id,
                    onSelect: (p) => ref
                        .read(activePetIdProvider.notifier)
                        .select(p.id!),
                    onAdd: () => context.push('/onboarding'),
                    avatarBuilder: (p, size) => PetPortrait(
                      pet: p,
                      size: size,
                      livingAvatar: LivingPetAvatar(
                        species: p.species,
                        size: size,
                        seed: p.id,
                        photoKey: p.photoKey,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  HomeGreeting(
                    name: profile.maybeWhen(
                        data: (_) => null, orElse: () => null),
                    petName: petDisplayName(pet.name),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  _HeroPanel(
                      pet: pet,
                      onCheck: () =>
                          _healthCheck(context, ref, pet, isPremium)),
                  const SizedBox(height: AppSpace.s12),
                  HomeQuickActions(items: [
                    (
                      const Key('home_assistant'),
                      LucideIcons.messageCircle,
                      'AI Assistant',
                      'Ask PawDoc AI',
                      () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AssistantScreen())),
                      null,
                    ),
                    (
                      const Key('home_quick_emergency'),
                      LucideIcons.circlePlus,
                      'Emergency',
                      'Get help now',
                      () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const EmergencyHelpScreen())),
                      AppColors.emergencyDark,
                    ),
                    (
                      const Key('home_add_record'),
                      LucideIcons.camera,
                      'Add Record',
                      'Photo / Note',
                      () => _logEvent(context, ref, pet),
                      null,
                    ),
                    (
                      const Key('home_reminders'),
                      LucideIcons.calendarClock,
                      'Reminders',
                      'Manage all',
                      () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const RemindersScreen())),
                      null,
                    ),
                  ]),
                  const SizedBox(height: AppSpace.s12),
                  // Emergency keeps its full-width button as well as the tile
                  // above: owner decision D-1 makes the red path unmissable,
                  // and a quarter-width tile is not that.
                  const EmergencyHelpButton(),
                  const SizedBox(height: AppSpace.s12),
                  // The mockup runs two columns here — insight cards on the
                  // left, the live lists on the right.
                  // Deliberately NOT wrapped in IntrinsicHeight: the walk card
                  // now measures itself with a LayoutBuilder, which has no
                  // intrinsic dimension, and the whole two-column block
                  // rendered blank because of it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Expanded(
                          flex: 45,
                          child: Column(children: [
                            BreedInsightCard(
                              key: ValueKey('breed_${pet.id}'),
                              species: pet.species,
                              breed: pet.breed,
                            ),
                            const SizedBox(height: AppSpace.s8),
                            const WalkCard(),
                            const SizedBox(height: AppSpace.s8),
                            const CommunityCard(),
                          ]),
                        ),
                        const SizedBox(width: AppSpace.s8),
                        Expanded(
                          flex: 55,
                          child: Column(children: [
                            _RemindersCard(pet: pet),
                            const SizedBox(height: AppSpace.s8),
                            _TimelineCard(pet: pet),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s12),
                  // Secondary navigation, laid out as the mockup's pill grid.
                  // Keys are preserved verbatim — the home tests address these
                  // by key, and the redesign must not silently move them.
                  _PillGrid(
                    rows: [
                      [
                        (
                          const Key('home_view_history'),
                          LucideIcons.history,
                          'History',
                          () => context.push('/history'),
                        ),
                        (
                          const Key('home_log_event'),
                          LucideIcons.chartNoAxesColumnIncreasing,
                          'Log event',
                          () => _logEvent(context, ref, pet),
                        ),
                        (
                          const Key('home_memories'),
                          LucideIcons.images,
                          'Memories',
                          () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => MemoriesScreen(pet: pet)),
                              ),
                        ),
                      ],
                      [
                        (
                          const Key('home_vet_prep'),
                          LucideIcons.clipboardList,
                          'Prepare for a vet visit',
                          () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => VetVisitPrepScreen(pet: pet)),
                              ),
                        ),
                        (
                          const Key('home_encyclopedia'),
                          LucideIcons.bookOpen,
                          'Breed Encyclopedia',
                          () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => EncyclopediaScreen(
                                        initialSpecies: pet.species)),
                              ),
                        ),
                      ],
                      [
                        (
                          const Key('home_manage_pets'),
                          LucideIcons.pawPrint,
                          'Manage pets',
                          () => context.push('/pets'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpace.s12),
                  _StatStrip(pet: pet),
                  const SizedBox(height: AppSpace.s12),
                  profile.maybeWhen(
                    data: (p) => _QuotaStrip(
                        isPremium: p.isPremium,
                        photoLogsRemaining: p.photoLogsRemaining),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ];
                return _staggered(context, content);
              },
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// Stagger-fade-up the dashboard cards on load (§3.3). Static under reduce-motion.
  Widget _staggered(BuildContext context, List<Widget> children) {
    if (reduceMotion(context)) {
      return Column(children: children);
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          children[i]
              .animate()
              .fadeIn(
                  duration: AppMotion.standard,
                  delay: Duration(milliseconds: 60 * i))
              .slideY(
                  begin: 0.06,
                  end: 0,
                  duration: AppMotion.standard,
                  curve: AppMotion.emphasized),
      ],
    );
  }
}

/// App-bar pet switcher. Selecting a pet updates [activePetIdProvider], which
/// reactively re-points the breed card, the "Check" target, and the history
/// timeline. The trailing "Add pet" item runs the tier-gated add flow.
class _PetSwitcher extends ConsumerWidget {
  const _PetSwitcher({required this.pets, required this.active});

  final List<Pet> pets;
  final Pet? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('pet_switcher'),
      tooltip: 'Switch pet',
      onSelected: (value) {
        if (value == _addPetSentinel) {
          startAddPetFlow(context, ref);
          return;
        }
        ref.read(activePetIdProvider.notifier).select(value);
      },
      itemBuilder: (_) => [
        for (final p in pets)
          CheckedPopupMenuItem<String>(
            value: p.id!,
            checked: p.id == active?.id,
            child: Text(petDisplayName(p.name)),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: _addPetSentinel,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add),
            title: Text('Add pet'),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              active == null ? 'PawDoc' : petDisplayName(active!.name),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

/// Mockup `010`'s hero: the pet's status line, three signals, the primary
/// action, and the pet lit against a bloom.
///
/// **Safety.** The mockup's headline is "Buddy is doing great!" over "No health
/// issues detected" — an all-clear the app cannot substantiate, and the exact
/// shape a false negative takes. What is actually known is when the pet was
/// last checked, so that is what the hero says. `home_hero_last_check_test`
/// pins the line.
class _HeroPanel extends ConsumerWidget {
  const _HeroPanel({required this.pet, required this.onCheck});

  final Pet pet;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastTriage = ref.watch(latestTriageProvider(pet.id!));
    final name = petDisplayName(pet.name);
    final subtitle = lastTriage.when(
      loading: () => '…',
      error: (_, _) => 'Tap below to run a check',
      // F-2: recency, not the raw wire level.
      data: (t) => t == null
          ? 'No checks yet'
          : 'Last check: ${t.checkedAt == null ? actionLabel(t.level) : lastCheckLabel(t.checkedAt!)}',
    );

    return PetHeroPanel(
      title: '$name’s day at a glance',
      subtitle: subtitle,
      // The mockup fills these with Energy/Mood/Activity readings. Nothing in
      // the product records them yet, so they are drawn as the mockup draws
      // them and marked unavailable rather than invented — a fabricated
      // "Mood: Happy" is a claim about an animal nobody observed.
      signals: const [
        (LucideIcons.zap, 'Energy', 'Soon', false),
        (LucideIcons.smile, 'Mood', 'Soon', false),
        (LucideIcons.footprints, 'Activity', 'Soon', false),
      ],
      ctaLabel: 'AI Health Check',
      ctaKey: Key('check_${pet.id}'),
      onCta: onCheck,
      art: _HeroArt(pet: pet),
    );
  }
}

/// The pet, cut into the hero's right edge.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    // The mockup fills this with a photograph, so the portrait resolves to the
    // pet's own photo when there is one and the photoreal species art when
    // there is not — the illustrated Paw Pal rig is right for a 56dp chip and
    // wrong here.
    return SizedBox(
      width: 164,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.white, Colors.white],
          stops: [0.0, 0.34, 1.0],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: pet.photoKey != null
            ? LivingPetAvatar(
                species: pet.species,
                size: 164,
                seed: pet.id,
                photoKey: pet.photoKey,
              )
            : Image.asset(
                AppAssets.species(pet.species),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
      ),
    );
  }
}

/// "Today's Reminders" — the next few due for this pet.
class _RemindersCard extends ConsumerWidget {
  const _RemindersCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(remindersForPetProvider(pet.id!));
    final rows = async.maybeWhen(
      data: (list) {
        final upcoming = [...list]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return [
          for (final r in upcoming.take(2))
            (
              LucideIcons.syringe,
              reminderTypeLabel(r.reminderType),
              dueDescription(r.dueDate),
              dueStamp(r.dueDate),
              null as Color?,
              (() => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RemindersScreen()))) as VoidCallback?,
            ),
        ];
      },
      orElse: () => const <(IconData, String, String, String, Color?, VoidCallback?)>[],
    );

    return HomeListCard(
      icon: LucideIcons.calendarDays,
      title: 'Today’s Reminders',
      actionLabel: 'See All',
      onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RemindersScreen())),
      emptyLabel: 'Nothing due. Add a reminder to be nudged about vaccines, '
          'medication or a check-up.',
      rows: rows,
    );
  }
}

/// "Health Timeline" — the three most recent entries, spine and all.
class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(healthTimelineProvider(pet.id!));
    final rows = async.maybeWhen(
      data: (list) => [
        for (final e in list.take(3))
          (
            timelineGlyph(e.kind),
            e.title,
            e.subtitle ?? '',
            lastCheckLabel(e.date),
            null as Color?,
            (() => context.push('/history')) as VoidCallback?,
          ),
      ],
      orElse: () => const <(IconData, String, String, String, Color?, VoidCallback?)>[],
    );

    return HomeListCard(
      icon: LucideIcons.activity,
      title: 'Health Timeline',
      actionLabel: 'View All',
      onAction: () => context.push('/history'),
      emptyLabel: 'Nothing recorded yet. Checks, notes and vet visits land '
          'here as you add them.',
      spine: true,
      rows: rows,
    );
  }
}

/// The closing three-cell strip.
class _StatStrip extends ConsumerWidget {
  const _StatStrip({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastTriage = ref.watch(latestTriageProvider(pet.id!));
    final reminders = ref.watch(remindersForPetProvider(pet.id!));
    final next = reminders.maybeWhen(
      data: (list) {
        if (list.isEmpty) return null;
        final sorted = [...list]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return sorted.first;
      },
      orElse: () => null,
    );
    final checkedAt = lastTriage.value?.checkedAt;

    return HomeStatStrip(
      score: careScore(pet, hasCheck: checkedAt != null, hasReminder: next != null),
      scoreCaption: 'Record\nfilled in',
      lastCheckup: checkedAt == null ? 'Not yet' : formatDay(checkedAt),
      lastCheckupCaption:
          checkedAt == null ? 'Run your first check' : lastCheckLabel(checkedAt),
      nextReminder: next == null ? 'None set' : dueStamp(next.dueDate),
      nextReminderCaption:
          next == null ? 'Add one to be nudged' : reminderTypeLabel(next.reminderType),
    );
  }
}

String formatDay(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// `08:30`, or the date when it is not today.
String dueStamp(DateTime due) {
  final now = DateTime.now();
  final sameDay =
      due.year == now.year && due.month == now.month && due.day == now.day;
  if (sameDay) {
    return '${due.hour.toString().padLeft(2, '0')}:'
        '${due.minute.toString().padLeft(2, '0')}';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[due.month - 1]} ${due.day}';
}

String dueDescription(DateTime due) {
  final days = due.difference(DateTime.now()).inDays;
  if (days < 0) return 'Overdue';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due in $days days';
}

String reminderTypeLabel(String type) => switch (type) {
      'vaccine' => 'Vaccine',
      'medication' => 'Medication',
      'checkup' => 'Check-up',
      'weight' => 'Weight check',
      _ => type.isEmpty
          ? 'Reminder'
          : type[0].toUpperCase() + type.substring(1),
    };

IconData timelineGlyph(TimelineKind kind) => switch (kind) {
      TimelineKind.analysis => LucideIcons.scanHeart,
      TimelineKind.healthEvent => LucideIcons.notebookPen,
    };

/// Warm, illustrated welcome for the first run (replaces the two stranded cards).
/// Quota v3 framing: text checks are FREE and unmetered; only photo logs
/// carry a friendly counter — never a billing meter on safety.
class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.onAddPet, this.freeRemaining});
  final VoidCallback onAddPet;
  final int? freeRemaining;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s32),
      child: Column(
        children: [
          // M1 (A2): welcome duo breathes + blinks; static PNG (the new
          // duo-under-moon art) under reduce-motion / load failure.
          AppMotionAsset(
            AppMotionAssets.emptyHomeLoop,
            fallbackAsset: AppAssets.onbWelcomeDuoMoon,
            height: 184,
            fallback: const Icon(Icons.pets_rounded,
                size: 88, color: PawPalette.mint),
          ),
          const SizedBox(height: AppSpace.s24),
          Text('Welcome to PawDoc 🐾',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Add your first pet to start watching over their health.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.ink300),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.s24),
          PawPrimaryButton(
            key: const Key('home_add_pet'),
            icon: Icons.add_rounded,
            onPressed: onAddPet,
            child: const Text('Add your pet'),
          ),
          const SizedBox(height: AppSpace.s16),
          _FreeChecksChip(freeRemaining: freeRemaining),
          // Emergency stays reachable before a pet is even added.
          const SizedBox(height: AppSpace.s24),
          const EmergencyHelpButton(),
        ],
      ),
    );
  }
}

/// Positive-framed free-checks pill for the home empty state ("⚡ 3 free checks
/// ready"), shown as a small rounded chip rather than a billing meter.
class _FreeChecksChip extends StatelessWidget {
  const _FreeChecksChip({required this.freeRemaining});
  final int? freeRemaining;

  @override
  Widget build(BuildContext context) {
    final label = freeRemaining == null
        ? 'Premium — unlimited photo logs'
        : 'Free text checks · $freeRemaining photo logs ready';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: PawPalette.mint.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 16, color: PawPalette.mint),
          const SizedBox(width: AppSpace.s4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.ink50)),
        ],
      ),
    );
  }
}

/// Slim, low-emphasis quota row at the bottom of the dashboard (demoted from the
/// top "billing meter"). Care before quota (roadmap §3.3).
class _QuotaStrip extends StatelessWidget {
  const _QuotaStrip(
      {required this.isPremium, required this.photoLogsRemaining});
  final bool isPremium;
  final int photoLogsRemaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bolt, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpace.s4),
        if (isPremium)
          Text('Premium — unlimited photo logs', style: style)
        else
          // M3 (#18): a 300ms count-DOWN tick when the remaining number
          // changes (it's "remaining", so the old value slides up and out);
          // instant under reduce-motion.
          AnimatedSwitcher(
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.6), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: Text(
              // v3: text checks are unmetered — only photo logs count.
              'Text checks free · $photoLogsRemaining of 5 photo logs left',
              key: ValueKey(photoLogsRemaining),
              style: style,
            ),
          ),
      ],
    );
  }
}

class _PillGrid extends StatelessWidget {
  const _PillGrid({required this.rows});

  final List<List<(Key, IconData, String, VoidCallback)>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: PawPillButton(
                      key: row[i].$1,
                      icon: row[i].$2,
                      label: row[i].$3,
                      onTap: row[i].$4,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

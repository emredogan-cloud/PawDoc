import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/account_screen.dart';
import '../account/user_profile.dart';
import '../analysis/analysis_runner.dart';
import '../analysis/analysis_service.dart';
import '../capture/camera_screen.dart';
import '../capture/video_capture_screen.dart';
import '../core/app_motion_asset.dart';
import '../core/app_views.dart';
import '../core/connectivity.dart';
import '../core/last_check.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../feedback/followup_banner.dart';
import '../health/breed_insight_card.dart';
import '../health/health_event_form_screen.dart';
import '../health/timeline.dart';
import '../monetization/telehealth_button.dart';
import '../pets/active_pet.dart';
import '../pets/add_pet_flow.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../referral/referral_screen.dart';
import '../text_input/symptom_text_screen.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// Sentinel value for the "Add pet" entry in the pet switcher menu.
const _addPetSentinel = '__add_pet__';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _check(BuildContext context, WidgetRef ref, Pet pet, bool isPremium) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CaptureSheet(),
    );
    if (mode == null || !context.mounted) return;

    if (mode == 'photo') {
      final key = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
      if (key != null && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnalysisRunnerScreen(
            petId: pet.id!, petName: pet.name, petSpecies: pet.species, inputType: 'photo',
            imageStorageKey: key, isPremium: isPremium,
          ),
        ));
        ref.invalidate(userProfileProvider);
      }
    } else if (mode == 'video') {
      final frameKeys = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(builder: (_) => const VideoCaptureScreen()),
      );
      if (frameKeys != null && frameKeys.isNotEmpty && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnalysisRunnerScreen(
            petId: pet.id!, petName: pet.name, petSpecies: pet.species, inputType: 'video',
            frameStorageKeys: frameKeys, isPremium: isPremium,
          ),
        ));
        ref.invalidate(userProfileProvider);
      }
    } else {
      final text = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => SymptomTextScreen(petName: pet.name)),
      );
      if (text != null && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnalysisRunnerScreen(
            petId: pet.id!, petName: pet.name, petSpecies: pet.species, inputType: 'text',
            textDescription: text, isPremium: isPremium,
          ),
        ));
        ref.invalidate(userProfileProvider);
      }
    }
  }

  Future<void> _logEvent(BuildContext context, WidgetRef ref, Pet pet) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => HealthEventFormScreen(petId: pet.id!, petName: pet.name),
    ));
    ref.invalidate(healthTimelineProvider(pet.id!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsListProvider);
    final profile = ref.watch(userProfileProvider);
    final activePet = ref.watch(activePetProvider);

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        title: petsAsync.maybeWhen(
          data: (list) =>
              list.isEmpty ? const Text('PawDoc') : _PetSwitcher(pets: list, active: activePet),
          orElse: () => const Text('PawDoc'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refer a friend',
            icon: const Icon(Icons.card_giftcard),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            ),
          ),
          // Account consolidates family / sign-out / delete (roadmap §3.10.2);
          // sign-out now lives there behind a confirm, so it can't be a one-tap
          // AppBar mis-hit. The pet switcher stays in the AppBar title.
          IconButton(
            key: const Key('home_account_button'),
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
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
          padding: const EdgeInsets.all(AppSpace.s16),
          children: [
            const OfflineBanner(),
            // 72h "was this helpful?" follow-up (self-hides when nothing pending).
            const FollowUpBanner(),
            petsAsync.when(
              // Skeletons matching the final layout (§4.3); static under reduce-motion.
              loading: () => const Column(
                children: [
                  SkeletonCard(height: 120),
                  SizedBox(height: AppSpace.s8),
                  SkeletonCard(height: 72),
                  SizedBox(height: AppSpace.s8),
                  SkeletonCard(height: 44),
                ],
              ),
              error: (e, _) => AppErrorView(
                message: 'Could not load your pets.',
                onRetry: () => ref.invalidate(petsListProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return _HomeEmptyState(
                    freeRemaining: profile.maybeWhen(
                      data: (p) => p.isPremium ? null : p.freeRemaining,
                      orElse: () => null,
                    ),
                    onAddPet: () => context.push('/onboarding'),
                  );
                }
                final isPremium =
                    profile.maybeWhen(data: (p) => p.isPremium, orElse: () => false);
                final pet = activePet ?? list.first;
                // Care-first hierarchy: pet hero → quick actions → insight →
                // secondary → quota (the billing meter is demoted to the bottom).
                final content = <Widget>[
                  _PetHeroCard(pet: pet, onCheck: () => _check(context, ref, pet, isPremium)),
                  const SizedBox(height: AppSpace.s12),
                  BreedInsightCard(
                    key: ValueKey('breed_${pet.id}'),
                    species: pet.species,
                    breed: pet.breed,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('home_view_history'),
                          onPressed: () => context.push('/history'),
                          icon: const Icon(Icons.history),
                          label: const Text('History'),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('home_log_event'),
                          onPressed: () => _logEvent(context, ref, pet),
                          icon: const Icon(Icons.add_chart),
                          label: const Text('Log event'),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/pets'),
                    icon: const Icon(Icons.pets),
                    label: const Text('Manage pets'),
                  ),
                  // Phase 5.4 — embedded telehealth (Airvet-style affiliate).
                  // Self-hides when AIRVET_AFFILIATE_URL isn't configured.
                  const TelehealthButton(source: 'home'),
                  const SizedBox(height: AppSpace.s8),
                  profile.maybeWhen(
                    data: (p) => _QuotaStrip(
                        isPremium: p.isPremium, freeRemaining: p.freeRemaining),
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

/// The #1 dashboard element (roadmap §3.3): pet identity (avatar + name + breed
/// + last-check) and the primary "Check" CTA. Pet-first, care-first.
class _PetHeroCard extends ConsumerWidget {
  const _PetHeroCard({required this.pet, required this.onCheck});
  final Pet pet;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lastTriage = ref.watch(latestTriageProvider(pet.id!));
    final hasBreed = pet.breed != null && pet.breed!.trim().isNotEmpty;
    final subtitle =
        hasBreed ? '${speciesName(pet.species)} · ${pet.breed!.trim()}' : speciesName(pet.species);

    return PawCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(context, lastTriage),
                const SizedBox(width: AppSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(petDisplayName(pet.name),
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant)),
                      lastTriage.when(
                        loading: () => const Text('…'),
                        error: (_, _) => const SizedBox.shrink(),
                        // F-2: recency, not the raw wire level — "Last check:
                        // just now" right after a completed analysis.
                        data: (t) => Text(
                          t == null
                              ? 'No checks yet'
                              : 'Last check: ${t.checkedAt == null ? t.level : lastCheckLabel(t.checkedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            PawPrimaryButton(
              key: Key('check_${pet.id}'),
              icon: Icons.health_and_safety_rounded,
              onPressed: onCheck,
              child: Text('Check ${petDisplayName(pet.name)}'),
            ),
          ],
        ),
    );
  }

  /// M2 (#9/#11): the pet's living avatar — the rig owns breath/blink now
  /// (the old code-breath on a generic disc is gone). The last-check
  /// timestamp is the beat key: when a new check lands (F-2 invalidation),
  /// the avatar does the attentive→relieved beat on return.
  Widget _avatar(BuildContext context, AsyncValue<LatestTriage?> lastTriage) {
    return LivingPetAvatar(
      species: pet.species,
      size: 56,
      seed: pet.id,
      beatKey: lastTriage.value?.checkedAt,
    );
  }
}

/// Warm, illustrated welcome for the first run (replaces the two stranded cards).
/// Quota is framed positively ("3 free checks ready"), not as a billing meter.
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
        ? 'Premium — unlimited checks'
        : '$freeRemaining free checks ready';
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
  const _QuotaStrip({required this.isPremium, required this.freeRemaining});
  final bool isPremium;
  final int freeRemaining;

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
          Text('Premium — unlimited checks', style: style)
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
              '$freeRemaining of 3 free checks left',
              key: ValueKey(freeRemaining),
              style: style,
            ),
          ),
      ],
    );
  }
}

/// Frosted capture sheet (roadmap §3.4.1): three guided mode tiles + a
/// "what makes a good photo?" tip. Returns 'photo' / 'video' / 'text' — the
/// capture/analysis flow is unchanged.
class _CaptureSheet extends StatelessWidget {
  const _CaptureSheet();

  void _tips(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('What makes a good photo?'),
        content: const Text(
          '• Good, even lighting — avoid harsh shadows\n'
          '• Fill the frame with the area of concern\n'
          '• Hold steady so it stays in focus\n'
          '• Unsure? Take it from a couple of angles',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      _CaptureModeTile(
        icon: Icons.camera_alt_rounded,
        title: 'Take a photo',
        hint: 'Best for skin, eyes, wounds',
        onTap: () => Navigator.pop(context, 'photo'),
      ),
      _CaptureModeTile(
        icon: Icons.videocam_rounded,
        title: 'Record a video',
        hint: 'Best for limping, breathing, seizures',
        onTap: () => Navigator.pop(context, 'video'),
      ),
      _CaptureModeTile(
        icon: Icons.edit_note_rounded,
        title: 'Describe symptoms',
        hint: 'No camera? Tell us what you see',
        onTap: () => Navigator.pop(context, 'text'),
      ),
    ];
    final animate = !reduceMotion(context);
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: AppGlass.sheetBlur, sigmaY: AppGlass.sheetBlur),
        child: Container(
          color: scheme.surface.withValues(alpha: AppGlass.sheetOpacity),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpace.s12),
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  for (var i = 0; i < tiles.length; i++)
                    animate
                        ? tiles[i].animate().fadeIn(
                            duration: AppMotion.standard,
                            delay: Duration(milliseconds: 50 * i))
                        : tiles[i],
                  TextButton.icon(
                    onPressed: () => _tips(context),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: const Text('What makes a good photo?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureModeTile extends StatelessWidget {
  const _CaptureModeTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          borderRadius: AppRadius.brMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: AppSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(hint,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

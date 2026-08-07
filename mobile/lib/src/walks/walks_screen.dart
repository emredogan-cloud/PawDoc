import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart' show petMetaLine;
import '../home/home_sections.dart';
import '../notifications/local_notifications.dart';
import '../pets/active_pet.dart';
import '../pets/pet_profile_screen.dart';
import '../pets/pet_switcher.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import '../vet_finder/maps_links.dart' show directionsUri, distanceLabel;
import 'places_service.dart' show WalkPlace;
import 'walk_scorer.dart';
import 'walk_sections.dart';
import 'walks_controller.dart';
import 'weather_service.dart';
import 'weather_walk_advisor_screen.dart';

/// Smart Walks, rebuilt against its mockup.
///
/// The hub: who is walking, what today's sky is doing, where to go, and the
/// walk log. Weather comes from MET Norway and is scored on this device by a
/// pure function; coordinates never reach a PawDoc server.
///
/// ## What the reference draws that the app does not record
///
/// There is **no walk tracking**. `walks_controller` reads a location once to
/// fetch a forecast and find nearby parks; it does not follow a route, and
/// nothing writes a walk anywhere. So the reference's live-walk card, its
/// weekly totals, its history rows and its badge progress have no data behind
/// them. Every one keeps its place, its shape and its glyph, and says *Soon* —
/// tapping any of them explains what is missing.
///
/// **Calories are not among them.** A burned-calorie figure needs the animal's
/// weight, its gait and its metabolism, and would be a fabricated number on a
/// health-adjacent screen. The tile it occupied holds a walk count instead,
/// which is a thing that can be counted once there is anything to count.
///
/// ## What the reference says that cannot be said
///
/// Its advice panel is branded **"AI Suggestion"** and reads "up to 60 minutes
/// a day is ideal for heart health and weight control". That is an exercise
/// prescription for an animal the app has never examined, and there is no
/// model behind it — [scoreWalkHour] is a pure function. See
/// `walk_sections.dart` for the full table of what was replaced.
class WalksScreen extends ConsumerStatefulWidget {
  const WalksScreen({super.key});

  @override
  ConsumerState<WalksScreen> createState() => _WalksScreenState();
}

class _WalksScreenState extends ConsumerState<WalksScreen> {
  void _soon(String what, String why) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: what,
        scrollable: true,
        children: [
          Text(why,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12.5, height: 1.45)),
          const HealthEduCard(
            icon: LucideIcons.mapPin,
            title: 'What tracking would need',
            body: 'Following a route means the app reads your location while '
                'the screen is off. That is a permission worth asking for '
                'properly, and a promise worth keeping — so it ships when it '
                'can be done without sending a single coordinate anywhere.',
          ),
        ],
      ),
    );
  }

  void _openAdvisor() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const WeatherWalkAdvisorScreen()),
    );
  }

  void _openTips() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthSheet(
        title: 'Walking notes',
        scrollable: true,
        children: [
          for (final tip in kWalkTips)
            HealthDetailRow(
              icon: LucideIcons.lightbulb,
              label: '',
              value: tip,
            ),
          const HealthEduCard(
            icon: LucideIcons.stethoscope,
            title: 'How much walking is right',
            body: kWalkDurationDisclaimer,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walksControllerProvider);
    final pet = ref.watch(activePetProvider);
    final species = pet?.species ?? 'dog';

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pawPrint,
          title: 'Smart Walks',
          subtitle: 'Weather-aware walks for ',
          subtitleTrail: pet == null ? 'your pet' : petDisplayName(pet.name),
          actions: [
            HealthCircleButton(
              key: const Key('walks_forecast_button'),
              icon: LucideIcons.calendarDays,
              tooltip: 'Full forecast',
              onTap: _openAdvisor,
            ),
            HealthCircleButton(
              key: const Key('walks_more'),
              icon: LucideIcons.ellipsis,
              tooltip: 'More',
              onTap: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) => HealthSheet(
                  title: 'Smart Walks',
                  children: [
                    HealthRecordRow(
                      key: const Key('walks_menu_forecast'),
                      leading: const HealthGlyphDisc(
                          icon: LucideIcons.cloudSun, tint: HealthTone.info),
                      title: 'Weather Walk Advisor',
                      subtitle: 'The full forecast, hour by hour',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openAdvisor();
                      },
                    ),
                    HealthRecordRow(
                      key: const Key('walks_menu_refresh'),
                      leading: const HealthGlyphDisc(
                          icon: LucideIcons.refreshCw, tint: HealthTone.teal),
                      title: 'Refresh the forecast',
                      subtitle: 'Read the sky again',
                      chevron: false,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ref
                            .read(walksControllerProvider.notifier)
                            .refresh(species: species);
                      },
                    ),
                    HealthRecordRow(
                      key: const Key('walks_menu_tips'),
                      leading: const HealthGlyphDisc(
                          icon: LucideIcons.lightbulb, tint: HealthTone.gold),
                      title: 'Walking notes',
                      subtitle: 'Ground, water, weather',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openTips();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        onRefresh: () =>
            ref.read(walksControllerProvider.notifier).refresh(species: species),
        children: [
          gap(2),
          if (pet != null)
            PetModuleHeaderCard(
              portrait: PetPortrait(
                pet: pet,
                size: 52,
                livingAvatar: pet.photoKey == null
                    ? null
                    : LivingPetAvatar(
                        species: pet.species,
                        size: 52,
                        seed: pet.id,
                        photoKey: pet.photoKey,
                      ),
              ),
              name: petDisplayName(pet.name),
              meta: petMetaLine(pet),
              onSwitch: () => showPetSwitcher(context, ref),
              onViewProfile: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PetProfileScreen(pet: pet)),
              ),
            ),
          gap(11),
          _TodayStats(state: state, species: species),
          gap(11),
          _TrackCard(onSoon: _soon),
          gap(11),
          _ConditionsCard(
            state: state,
            species: species,
            petName: pet?.name,
            onMore: _openAdvisor,
            onEnable: () => ref
                .read(walksControllerProvider.notifier)
                .enable(species: species),
          ),
          gap(11),
          if (state is WalksReady && state.places.isNotEmpty) ...[
            _PlacesCard(places: state.places),
            gap(11),
          ],
          _LogCard(onSoon: _soon),
          gap(11),
          _BadgesCard(onSoon: _soon),
          gap(11),
          const _WalkReminderCard(),
          gap(11),
          HealthEduCard(
            key: const Key('walks_tips_card'),
            icon: LucideIcons.lightbulb,
            title: 'Walking notes',
            body: kWalkTips.first,
            art: HealthActionPill(
              label: 'All notes',
              icon: LucideIcons.chevronRight,
              onTap: _openTips,
            ),
          ),
          gap(10),
          const Text(
            'Weather: MET Norway (CC BY 4.0) · Places: © OpenStreetMap '
            'contributors · Scored on this device. Your coordinates never '
            'reach a PawDoc server.',
            key: Key('walks_attribution'),
            style:
                TextStyle(color: HealthTone.faint, fontSize: 10.5, height: 1.35),
          ),
          gap(8),
        ],
      ),
    );
  }
}

/// The educational notes the reference's tip strip carries. Observational —
/// nothing here is a diagnosis, a dose or a prescription.
const List<String> kWalkTips = [
  'On a hot day, press the back of your hand to the pavement for seven '
      'seconds. If you cannot hold it there, it is too hot for paws.',
  'Grit and de-icing salt gather between the toes in winter. A rinse and a '
      'dry towel at the door is usually all it takes.',
  'Shade changes the felt temperature more than a few degrees on the forecast '
      'does. A shaded route on a warm day is a different walk.',
  'Wind makes cold weather bite. Sheltered streets are the kinder ones when '
      'it is blowing.',
  'A harness spreads pressure across the chest instead of the throat, which '
      'most dogs find more comfortable on a lead.',
  'Anything new — limping, lagging, refusing the door — is worth a word with '
      'your vet rather than a change of route.',
];

// ---------------------------------------------------------------------------
// Today, in four numbers
// ---------------------------------------------------------------------------

/// The reference's weekly totals strip. Those totals need tracked walks, so
/// the four tiles hold what the app really knows about *today's conditions*
/// instead — every one of them counted from the forecast in hand.
class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.state, required this.species});

  final WalksState state;
  final String species;

  @override
  Widget build(BuildContext context) {
    if (state is! WalksReady) {
      return const HealthStatTiles(
        key: Key('walks_stats'),
        stats: [
          HealthStat(icon: LucideIcons.sun, value: '—', label: 'Kind hours left'),
          HealthStat(icon: LucideIcons.clock, value: '—', label: 'Best window'),
          HealthStat(
              icon: LucideIcons.thermometer, value: '—', label: 'Right now'),
          HealthStat(icon: LucideIcons.trees, value: '—', label: 'Parks near'),
        ],
      );
    }
    final ready = state as WalksReady;
    // Daylight hours on the same calendar day as the first sample — the same
    // window `bestWalkWindows` scans, so the two can never disagree.
    final day = ready.hours.isEmpty ? null : ready.hours.first.time;
    final today = day == null
        ? const <HourlyWeather>[]
        : ready.hours
            .where((h) =>
                h.time.year == day.year &&
                h.time.month == day.month &&
                h.time.day == day.day &&
                h.time.hour >= 6 &&
                h.time.hour <= 22)
            .toList();
    final kind = today
        .where((h) => scoreWalkHour(h, species: species).score >= 70)
        .length;
    final window = ready.todayWindows.isEmpty
        ? '—'
        : '${ready.todayWindows.first.start.hour.toString().padLeft(2, '0')}'
            ':00';
    return HealthStatTiles(
      key: const Key('walks_stats'),
      stats: [
        // "Left", not "today": the forecast starts at the current hour, so
        // this counts the comfortable hours still ahead — which is the number
        // an owner reading it at eight in the evening actually wants.
        HealthStat(
            icon: LucideIcons.sun, value: '$kind', label: 'Kind hours left'),
        HealthStat(
            icon: LucideIcons.clock, value: window, label: 'Best window'),
        HealthStat(
            icon: LucideIcons.thermometer,
            value: '${ready.now.score}',
            label: 'Comfort now'),
        HealthStat(
            icon: LucideIcons.trees,
            value: '${ready.places.length}',
            label: 'Parks nearby'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The live walk card — drawn, and honest about being empty
// ---------------------------------------------------------------------------

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.onSoon});

  final void Function(String, String) onSoon;

  static const _why =
      'PawDoc does not follow a walk yet. It reads your location once, on '
      'this device, to fetch the forecast and find nearby parks — it does not '
      'record where you went, how far, or for how long, and nothing is stored '
      'anywhere. Distance, duration and pace appear here when it does.';

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('walks_track_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: HealthTone.faint),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Current Walk',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700)),
            ),
            const HealthPill(label: 'Soon', tint: HealthTone.faint),
          ]),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Metric(
                          icon: LucideIcons.route,
                          value: '—',
                          label: 'Distance'),
                      SizedBox(height: 11),
                      _Metric(
                          icon: LucideIcons.clock, value: '—', label: 'Time'),
                      SizedBox(height: 11),
                      _Metric(
                          icon: LucideIcons.gauge, value: '—', label: 'Pace'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HealthDashedTile(
                    key: const Key('walks_track_panel'),
                    radius: 14,
                    color: Colors.white.withValues(alpha: 0.14),
                    onTap: () => onSoon('Walk tracking', _why),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.mapPinned,
                              size: 26, color: HealthTone.faint),
                          SizedBox(height: 9),
                          Text('No route is recorded',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: HealthTone.muted,
                                  fontSize: 12,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 3),
                          Text('Tap to see what tracking will need',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: HealthTone.faint,
                                  fontSize: 10.5,
                                  height: 1.25)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 5,
              // No ringed glyph: with one, "Start a Walk · Soon" truncated to
              // "Start a Walk · …" at its 5-share on the device.
              child: HealthPrimaryCta(
                key: const Key('walks_start'),
                icon: null,
                label: 'Start a Walk · Soon',
                enabled: false,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 8),
            _GhostButton(
              buttonKey: const Key('walks_hold'),
              icon: LucideIcons.pause,
              label: 'Hold',
              onTap: () => onSoon('Walk tracking', _why),
            ),
            const SizedBox(width: 8),
            _GhostButton(
              buttonKey: const Key('walks_finish'),
              icon: LucideIcons.square,
              label: 'Finish',
              onTap: () => onSoon('Walk tracking', _why),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: HealthTone.faint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: HealthTone.muted,
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w800)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 10.5, height: 1.25)),
              ],
            ),
          ),
        ],
      );
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: HealthTone.muted),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: HealthTone.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Weather + guidance
// ---------------------------------------------------------------------------

class _ConditionsCard extends StatelessWidget {
  const _ConditionsCard({
    required this.state,
    required this.species,
    required this.petName,
    required this.onMore,
    required this.onEnable,
  });

  final WalksState state;
  final String species;
  final String? petName;
  final VoidCallback onMore;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    if (state is! WalksReady) {
      return HomeCard(
        key: const Key('walks_conditions_card'),
        radius: 18,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HealthSectionHead(
              title: 'Today’s Conditions',
              leading: Icon(LucideIcons.cloudSun,
                  size: 15, color: HealthTone.muted),
            ),
            const SizedBox(height: 8),
            Text(
              switch (state) {
                WalksLoading() => 'Reading the sky…',
                WalksError() =>
                  'The forecast is unavailable right now. Pull to try again.',
                WalksPermissionNeeded() =>
                  'PawDoc needs a rough location to fetch a forecast. It is '
                      'read on this device and never sent to a PawDoc server.',
                _ => 'Turn on location to see how comfortable today is for a '
                    'walk, and where the nearby parks are. Read on this '
                    'device; never sent anywhere.',
              },
              key: const Key('walks_conditions_placeholder'),
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.4),
            ),
            if (state is! WalksLoading) ...[
              const SizedBox(height: 12),
              HealthPrimaryCta(
                key: const Key('walks_enable'),
                icon: LucideIcons.mapPin,
                label: 'Use my location',
                onTap: onEnable,
              ),
            ],
          ],
        ),
      );
    }

    final ready = state as WalksReady;
    final now = ready.hours.isEmpty ? null : ready.hours.first;
    final band = walkBand(ready.now.score);
    return HomeCard(
      key: const Key('walks_conditions_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Today’s Conditions',
            leading: Icon(LucideIcons.cloudSun, size: 15, color: t.accent),
            actionLabel: 'Full forecast',
            onAction: onMore,
          ),
          const SizedBox(height: 11),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 128,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(weatherGlyph(now?.symbol),
                            size: 30, color: HealthTone.gold),
                        const SizedBox(width: 9),
                        Text(
                          now == null ? '—' : '${now.tempC.round()}°',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1,
                              fontWeight: FontWeight.w800),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      Text(weatherWord(now?.symbol),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: HealthTone.muted, fontSize: 11.5)),
                      const SizedBox(height: 2),
                      Text(
                        now == null
                            ? ''
                            : 'Wind ${(now.windMs * 3.6).round()} km/h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: HealthTone.faint, fontSize: 10.5),
                      ),
                      const SizedBox(height: 8),
                      WalkBandChip(band: band),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ready.now.headline,
                          key: const Key('walks_headline'),
                          maxLines: 2,
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 13.5,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        walkSuggestionCopy(
                          now: ready.now,
                          windows: ready.todayWindows,
                          petName: petName,
                          species: species,
                        ),
                        style: const TextStyle(
                            color: HealthTone.dim, fontSize: 11.5, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      for (final reason in ready.now.reasons.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('· $reason',
                              maxLines: 2,
                              style: const TextStyle(
                                  color: HealthTone.faint,
                                  fontSize: 10.5,
                                  height: 1.3)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nearby places
// ---------------------------------------------------------------------------

class _PlacesCard extends StatelessWidget {
  const _PlacesCard({required this.places});

  final List<WalkPlace> places;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('walks_places_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'Places to Walk Nearby',
            leading:
                Icon(LucideIcons.trees, size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 6),
          for (final place in places.take(6))
            HealthRecordRow(
              key: Key('walk_place_${place.name.hashCode}'),
              leading: HealthGlyphDisc(
                icon: place.kind == 'dog_park'
                    ? LucideIcons.pawPrint
                    : LucideIcons.trees,
                tint: place.kind == 'dog_park'
                    ? HealthTone.teal
                    : HealthTone.info,
                size: 38,
              ),
              title: place.name,
              subtitle: [
                place.kind.replaceAll('_', ' '),
                if (place.distanceMeters != null)
                  distanceLabel(place.distanceMeters),
              ].join(' · '),
              onTap: () => launchUrl(
                directionsUri(place.lat, place.lon),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The log and the badges
// ---------------------------------------------------------------------------

class _LogCard extends StatelessWidget {
  const _LogCard({required this.onSoon});

  final void Function(String, String) onSoon;

  static const _why =
      'A walk log needs walks to log, and nothing records one yet. When '
      'tracking arrives, each finished walk lands here with its date, its '
      'length and its route.';

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('walks_log_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Recent Walks',
            leading: const Icon(LucideIcons.history,
                size: 15, color: HealthTone.muted),
            actionLabel: 'Soon',
            chevron: false,
            actionColor: HealthTone.faint,
            onAction: () => onSoon('The walk log', _why),
          ),
          const SizedBox(height: 9),
          HealthDashedTile(
            key: const Key('walks_log_empty'),
            radius: 14,
            color: Colors.white.withValues(alpha: 0.12),
            onTap: () => onSoon('The walk log', _why),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                children: [
                  Icon(LucideIcons.footprints,
                      size: 24, color: HealthTone.faint),
                  SizedBox(height: 9),
                  Text('No walks recorded yet',
                      style: TextStyle(
                          color: HealthTone.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 3),
                  Text('Walks appear here once tracking arrives.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: HealthTone.faint,
                          fontSize: 10.5,
                          height: 1.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's five hexagon badges.
///
/// Its own set counts kilometres and calories — "Walk 50 km", "Burn 500 kcal".
/// A distance or a calorie target is a goal set *for the animal*, and this app
/// does not tell anyone how far their dog should go. These five are about the
/// owner's habit instead: turning up, keeping it up, and finding somewhere new.
const List<({IconData icon, String title, String goal, int target})>
    kWalkBadges = [
  (
    icon: LucideIcons.footprints,
    title: 'First Ten',
    goal: 'Log ten walks',
    target: 10
  ),
  (
    icon: LucideIcons.calendarCheck,
    title: 'Seven Days',
    goal: 'A walk seven days running',
    target: 7
  ),
  (
    icon: LucideIcons.sunrise,
    title: 'Early Riser',
    goal: 'Ten walks before nine',
    target: 10
  ),
  (
    icon: LucideIcons.trees,
    title: 'Explorer',
    goal: 'Ten different places',
    target: 10
  ),
  (
    icon: LucideIcons.cloudRain,
    title: 'All Weathers',
    goal: 'A walk in every season',
    target: 4
  ),
];

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.onSoon});

  final void Function(String, String) onSoon;

  static const _why =
      'Badges count walks, and nothing counts a walk yet. They start filling '
      'the day tracking arrives — and they are about the habit, not about how '
      'far your pet went. How much walking suits an animal is a conversation '
      'with a vet, not a target in an app.';

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('walks_badges_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Milestones',
            leading:
                const Icon(LucideIcons.award, size: 15, color: HealthTone.muted),
            actionLabel: 'Soon',
            chevron: false,
            actionColor: HealthTone.faint,
            onAction: () => onSoon('Milestones', _why),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 152,
            child: ListView.separated(
              key: const Key('walks_badges_rail'),
              scrollDirection: Axis.horizontal,
              itemCount: kWalkBadges.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, i) {
                final badge = kWalkBadges[i];
                return _Badge(
                  badgeKey: Key('walk_badge_${badge.title}'),
                  icon: badge.icon,
                  title: badge.title,
                  goal: badge.goal,
                  target: badge.target,
                  onTap: () => onSoon('Milestones', _why),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.badgeKey,
    required this.icon,
    required this.title,
    required this.goal,
    required this.target,
    required this.onTap,
  });

  final Key badgeKey;
  final IconData icon;
  final String title;
  final String goal;
  final int target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: Material(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: badgeKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(9, 11, 9, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Icon(icon, size: 19, color: HealthTone.faint),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF12180F),
                        ),
                        child: const Icon(LucideIcons.lock,
                            size: 9, color: HealthTone.faint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted,
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                // An explicit slot, not a bare Text: inside a fixed-height
                // rail a two-line label reports its unwrapped height and gets
                // silently clipped.
                SizedBox(
                  height: 34,
                  child: Text(goal,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: HealthTone.faint,
                          fontSize: 9.5,
                          height: 1.25)),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        HealthTone.faint),
                  ),
                ),
                const SizedBox(height: 4),
                Text('0 / $target',
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 9.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The daily reminder (unchanged behaviour, rebuilt chrome)
// ---------------------------------------------------------------------------

class _WalkReminderCard extends ConsumerStatefulWidget {
  const _WalkReminderCard();

  @override
  ConsumerState<_WalkReminderCard> createState() => _WalkReminderCardState();
}

class _WalkReminderCardState extends ConsumerState<_WalkReminderCard> {
  static const _prefKey = 'walk_reminder_on';
  static const _hourKey = 'walk_reminder_hour';

  bool _on = false;
  int _hour = 8;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _on = prefs.getBool(_prefKey) ?? false;
      _hour = prefs.getInt(_hourKey) ?? 8;
      _loaded = true;
    });
  }

  Future<void> _apply(bool on, int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, on);
    await prefs.setInt(_hourKey, hour);
    final notifications = ref.read(localNotificationsProvider);
    if (on) {
      final granted = await notifications.ensurePermission();
      if (!granted) {
        if (mounted) {
          setState(() => _on = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Notifications are off for PawDoc in Settings.')));
        }
        await prefs.setBool(_prefKey, false);
        return;
      }
      await notifications.scheduleDailyWalkReminder(hour: hour, minute: 0);
    } else {
      await notifications.cancelDailyWalkReminder();
    }
    if (mounted) {
      setState(() {
        _on = on;
        _hour = hour;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('walk_reminder_card'),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.bellRing, size: 16, color: t.accent),
            const SizedBox(width: 9),
            const Expanded(
              child: Text('Daily walk reminder',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            Switch(
              key: const Key('walk_reminder_switch'),
              value: _on,
              onChanged: (v) => _apply(v, _hour),
            ),
          ]),
          Text(
            _on
                ? 'A nudge at ${_hour.toString().padLeft(2, '0')}:00, from this '
                    'phone. Nothing leaves the device.'
                : 'A quiet daily nudge, scheduled on this phone.',
            style: const TextStyle(
                color: HealthTone.dim, fontSize: 11, height: 1.35),
          ),
          if (_on) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final hour in const [6, 7, 8, 9, 17, 18, 19, 20])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        key: Key('walk_reminder_hour_$hour'),
                        selected: hour == _hour,
                        onSelected: (_) => _apply(true, hour),
                        label: Text('${hour.toString().padLeft(2, '0')}:00'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

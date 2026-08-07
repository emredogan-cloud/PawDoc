import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart' show petMetaLine;
import '../home/home_sections.dart';
import '../pets/active_pet.dart';
import '../pets/pet_profile_screen.dart';
import '../pets/pet_switcher.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'walk_scorer.dart';
import 'walk_sections.dart';
import 'walks_controller.dart';
import 'weather_service.dart';

/// The Weather Walk Advisor, rebuilt against its mockup.
///
/// Conditions now, an hour-by-hour comfort rail, what the weather suggests
/// planning around, a five-day outlook, and the notes. Every number on it is
/// read from the MET Norway forecast and scored on this device by
/// [scoreWalkHour] — a pure function, no model, no network beyond the forecast
/// itself, and no coordinate leaving the phone.
///
/// ## The three things the reference says that this screen must not
///
/// 1. **"AI Walk Suggestion".** There is no model here. Branding a lookup
///    table as AI misrepresents it, and putting an AI badge on advice about an
///    animal's exercise is exactly the confusion V-23 exists to prevent.
/// 2. **"Estimated duration 30–45 min" and "Ideal distance 3–5 km".** How far
///    and how long suits an animal is age, breed, weight and health — a
///    veterinary judgement about a specific pet, not something a thermometer
///    can answer. Both rows are gone; the slots hold what the sky really says
///    (the kindest hours, the ground, the water, the sun) and
///    [kWalkDurationDisclaimer] sits under them saying whose call it is.
/// 3. **"A great day for Buddy!"** The forecast is about the weather. Every
///    sentence here is written about conditions, never about the animal.
///
/// The reference's per-hour and per-day score chips are kept, in a palette
/// [WalkBand] guarantees is clear of the action ladder's four safety-locked
/// hues — a "poor" afternoon must never look like a triage result.
class WeatherWalkAdvisorScreen extends ConsumerWidget {
  const WeatherWalkAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walksControllerProvider);
    final pet = ref.watch(activePetProvider);
    final species = pet?.species ?? 'dog';

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pawPrint,
          title: 'Weather Walk Advisor',
          subtitle: 'The kindest hours to be ',
          subtitleTrail: 'outside',
          actions: [
            HealthCircleButton(
              key: const Key('advisor_refresh'),
              icon: LucideIcons.refreshCw,
              tooltip: 'Refresh the forecast',
              onTap: () => ref
                  .read(walksControllerProvider.notifier)
                  .refresh(species: species),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        onRefresh: () =>
            ref.read(walksControllerProvider.notifier).refresh(species: species),
        children: [
          gap(2),
          if (pet != null) ...[
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
          ],
          ...switch (state) {
            WalksReady() =>
              _ready(context, ref, state, species: species),
            WalksLoading() => const [
                _AdvisorNotice(
                  key: Key('advisor_loading'),
                  icon: LucideIcons.cloudSun,
                  title: 'Reading the sky…',
                  body: 'Fetching the forecast for where you are.',
                ),
              ],
            WalksError() => [
                const _AdvisorNotice(
                  key: Key('advisor_error'),
                  icon: LucideIcons.cloudOff,
                  title: 'The forecast is unavailable',
                  body: 'Pull down to try again.',
                ),
              ],
            _ => [
                _EnableCard(
                  onEnable: () => ref
                      .read(walksControllerProvider.notifier)
                      .enable(species: species),
                ),
              ],
          },
          gap(11),
          const _TipsCard(),
          gap(10),
          const Text(
            'Weather: MET Norway (CC BY 4.0) · Scored on this device with a '
            'plain function, not a model. Your coordinates never reach a '
            'PawDoc server.',
            key: Key('advisor_attribution'),
            style:
                TextStyle(color: HealthTone.faint, fontSize: 10.5, height: 1.35),
          ),
          gap(8),
        ],
      ),
    );
  }

  List<Widget> _ready(
    BuildContext context,
    WidgetRef ref,
    WalksReady state, {
    required String species,
  }) {
    final now = state.hours.isEmpty ? null : state.hours.first;
    final outlook = dailyWalkOutlook(state.hours, species: species);
    return [
      _NowCard(state: state, now: now),
      gap(11),
      _HourlyCard(hours: state.hours, species: species),
      gap(11),
      _GuidanceCard(state: state, now: now, species: species),
      gap(11),
      if (outlook.isNotEmpty) _OutlookCard(days: outlook),
    ];
  }
}

// ---------------------------------------------------------------------------
// Conditions now + the dial
// ---------------------------------------------------------------------------

class _NowCard extends StatelessWidget {
  const _NowCard({required this.state, required this.now});

  final WalksReady state;
  final HourlyWeather? now;

  @override
  Widget build(BuildContext context) {
    final band = walkBand(state.now.score);
    return HomeCard(
      key: const Key('advisor_now_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 5:4 shares, never two bare Flexibles — an even split squeezes
            // the temperature, which is the biggest glyph on the page.
            Flexible(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(LucideIcons.mapPin,
                        size: 13, color: HealthTone.muted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('Near you',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: HealthTone.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(weatherGlyph(now?.symbol),
                        size: 38, color: HealthTone.gold),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        now == null ? '—' : '${now!.tempC.round()}°',
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(weatherWord(now?.symbol),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: HealthTone.muted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Text(
                    now == null
                        ? ''
                        : 'Wind ${(now!.windMs * 3.6).round()} km/h'
                            '${now!.precipMm > 0 ? ' · Rain ${now!.precipMm.toStringAsFixed(1)} mm' : ''}',
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 10.5, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 4,
              child: Column(
                children: [
                  WalkBandChip(band: band),
                  const SizedBox(height: 8),
                  WalkScoreDial(score: state.now.score, size: 124),
                  const SizedBox(height: 4),
                  Text(band.blurb,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: HealthTone.dim, fontSize: 10.5, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hour by hour
// ---------------------------------------------------------------------------

class _HourlyCard extends StatelessWidget {
  const _HourlyCard({required this.hours, required this.species});

  final List<HourlyWeather> hours;
  final String species;

  @override
  Widget build(BuildContext context) {
    final slice = hours.take(12).toList();
    return HomeCard(
      key: const Key('advisor_hourly_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'Hour by Hour',
            leading:
                Icon(LucideIcons.clock, size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 138,
            child: ListView.separated(
              key: const Key('walks_hourly'),
              scrollDirection: Axis.horizontal,
              itemCount: slice.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final hour = slice[i];
                final score = scoreWalkHour(hour, species: species).score;
                return _HourChip(hour: hour, score: score, isNow: i == 0);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The number under each hour is walk comfort out of 100 — '
            'temperature, rain, wind and sun. It says nothing about your pet.',
            style: TextStyle(
                color: HealthTone.faint, fontSize: 10.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    required this.hour,
    required this.score,
    required this.isNow,
  });

  final HourlyWeather hour;
  final int score;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final band = walkBand(score);
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: isNow ? t.accent.withValues(alpha: 0.07) : HealthTone.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNow
              ? t.accent.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isNow ? 'Now' : '${hour.time.hour.toString().padLeft(2, '0')}:00',
            style: TextStyle(
                color: isNow ? t.accent : HealthTone.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Icon(weatherGlyph(hour.symbol), size: 21, color: HealthTone.gold),
          const SizedBox(height: 8),
          Text('${hour.tempC.round()}°',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: band.tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: band.tone.withValues(alpha: 0.40)),
            ),
            child: Text('$score',
                style: TextStyle(
                    color: band.tone,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// What the weather suggests planning around
// ---------------------------------------------------------------------------

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.state,
    required this.now,
    required this.species,
  });

  final WalksReady state;
  final HourlyWeather? now;
  final String species;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    if (now == null) return const SizedBox.shrink();
    final hints = walkHints(now!, state.todayWindows, species: species);
    return HomeCard(
      key: const Key('advisor_guidance_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'What to Plan Around',
            leading: Icon(LucideIcons.compass, size: 15, color: t.accent),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < hints.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _HintRow(hint: hints[i]),
          ],
          const SizedBox(height: 11),
          Container(
            key: const Key('advisor_duration_note'),
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.028),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.stethoscope,
                    size: 15, color: HealthTone.muted),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(kWalkDurationDisclaimer,
                      style: TextStyle(
                          color: HealthTone.dim, fontSize: 11, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.hint});

  final WalkHint hint;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.accent.withValues(alpha: 0.09),
          ),
          child: Icon(hint.icon, size: 16, color: t.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hint.label,
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(hint.body,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The five-day outlook
// ---------------------------------------------------------------------------

class _OutlookCard extends StatelessWidget {
  const _OutlookCard({required this.days});

  final List<WalkDayOutlook> days;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('advisor_outlook_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'The Next Few Days',
            leading: Icon(LucideIcons.calendarRange,
                size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 192,
            child: ListView.separated(
              key: const Key('advisor_outlook_rail'),
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final day = days[i];
                final today = i == 0;
                return Container(
                  key: Key('advisor_day_$i'),
                  width: 88,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: today
                        ? t.accent.withValues(alpha: 0.06)
                        : HealthTone.raised,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: today
                          ? t.accent.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(outlookDayLabel(day.day),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: today ? t.accent : Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text('${day.day.day}/${day.day.month}',
                          style: const TextStyle(
                              color: HealthTone.faint, fontSize: 9.5)),
                      const SizedBox(height: 8),
                      Icon(weatherGlyph(day.symbol),
                          size: 24, color: HealthTone.gold),
                      const SizedBox(height: 8),
                      Text('${day.maxC.round()}° / ${day.minC.round()}°',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      WalkBandChip(band: day.band, compact: true),
                      const SizedBox(height: 4),
                      // The band alone would invite a noon walk on a 34°C day
                      // whose only kind hour is at six.
                      Text('${day.score} · ${day.bestHourLabel}',
                          style: const TextStyle(
                              color: HealthTone.faint, fontSize: 9.5)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notes and states
// ---------------------------------------------------------------------------

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('advisor_tips_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'Quick Notes',
            leading:
                Icon(LucideIcons.sparkles, size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < kAdvisorNotes.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kAdvisorNotes[i].$1, size: 15, color: HealthTone.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(kAdvisorNotes[i].$2,
                      style: const TextStyle(
                          color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Observational weather notes. Nothing here diagnoses, doses or prescribes.
const List<(IconData, String)> kAdvisorNotes = [
  (
    LucideIcons.thermometer,
    'Above about 25°C, the early and late hours are the comfortable ones.'
  ),
  (
    LucideIcons.pawPrint,
    'Hot pavement can burn paws. The back of your hand held to the ground for '
        'seven seconds is the usual test.'
  ),
  (
    LucideIcons.droplets,
    'Carry water on warm days and offer it whenever you stop.'
  ),
  (
    LucideIcons.wind,
    'Wind makes cold weather bite. Sheltered streets are the kinder ones.'
  ),
];

class _AdvisorNotice extends StatelessWidget {
  const _AdvisorNotice({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => HomeCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
        child: Column(
          children: [
            Icon(icon, size: 26, color: HealthTone.muted),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
          ],
        ),
      );
}

class _EnableCard extends StatelessWidget {
  const _EnableCard({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) => HomeCard(
        key: const Key('advisor_enable_card'),
        radius: 18,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HealthSectionHead(
              title: 'Where are you walking?',
              leading:
                  Icon(LucideIcons.mapPin, size: 15, color: HealthTone.muted),
            ),
            const SizedBox(height: 8),
            const Text(
              'A rough location is enough to fetch a forecast. It is read on '
              'this device, used to ask MET Norway about the sky, and never '
              'sent to a PawDoc server.',
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            HealthPrimaryCta(
              key: const Key('advisor_enable'),
              icon: LucideIcons.mapPin,
              label: 'Use my location',
              onTap: onEnable,
            ),
          ],
        ),
      );
}

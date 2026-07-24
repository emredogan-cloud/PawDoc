import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_views.dart';
import '../notifications/local_notifications.dart';
import '../pets/active_pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import '../vet_finder/maps_links.dart' show directionsUri, distanceLabel;
import 'walk_card.dart' show WalkScoreRing;
import 'walk_scorer.dart';
import 'walks_controller.dart';
import 'weather_service.dart';

/// Smart Walks (Next Evolution Phase 5): today's walk-quality timeline, the
/// best windows, nearby walking places (OSM), and the daily on-device walk
/// reminder. Weather: MET Norway. Everything computed on this device.
class WalksScreen extends ConsumerWidget {
  const WalksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walksControllerProvider);
    final pet = ref.watch(activePetProvider);
    final species = pet?.species ?? 'dog';

    return PawScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Smart Walks'),
      ),
      body: switch (state) {
        WalksReady() => _Ready(state: state, petName: pet?.name, species: species),
        WalksLoading() => const AppLoadingView(label: 'Reading the sky…'),
        WalksError() => AppErrorView(
            message: 'Walk weather is unavailable right now.',
            onRetry: () => ref
                .read(walksControllerProvider.notifier)
                .refresh(species: species),
          ),
        _ => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off_rounded,
                      size: 40, color: AppColors.ink300),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'Enable location from the Home walk card to see '
                    'weather-aware walk times.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.ink300),
                  ),
                ],
              ),
            ),
          ),
      },
    );
  }
}

class _Ready extends ConsumerWidget {
  const _Ready({required this.state, required this.petName, required this.species});

  final WalksReady state;
  final String? petName;
  final String species;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(walksControllerProvider.notifier).refresh(species: species),
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.s16),
        children: [
          // Now.
          PawCard(
            child: Row(
              children: [
                WalkScoreRing(score: state.now.score, size: 72),
                const SizedBox(width: AppSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.now.headline,
                          key: const Key('walks_headline'),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: AppColors.ink50)),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        walkSuggestionCopy(
                          now: state.now,
                          windows: state.todayWindows,
                          petName: petName,
                          species: species,
                        ),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.ink300),
                      ),
                      const SizedBox(height: AppSpace.s8),
                      Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s4,
                        children: [
                          for (final reason in state.now.reasons.take(3))
                            Text('· $reason',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: PawPalette.mint)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),

          // Today, hour by hour.
          Text('Today, hour by hour',
              style:
                  theme.textTheme.titleMedium?.copyWith(color: PawPalette.mint)),
          const SizedBox(height: AppSpace.s8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              key: const Key('walks_hourly'),
              scrollDirection: Axis.horizontal,
              itemCount: state.hours.take(24).length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (context, i) {
                final hour = state.hours[i];
                final score = scoreWalkHour(hour, species: species).score;
                return _HourChip(hour: hour, score: score);
              },
            ),
          ),
          const SizedBox(height: AppSpace.s16),

          if (state.todayWindows.isNotEmpty) ...[
            Text('Best windows today',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: PawPalette.mint)),
            const SizedBox(height: AppSpace.s8),
            for (final window in state.todayWindows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: PawCard(
                  padding: const EdgeInsets.all(AppSpace.s12),
                  radius: AppRadius.md,
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: PawPalette.mint, size: 20),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Text(
                          '${_hh(window.start)}–${_hh(window.end)}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: AppColors.ink50),
                        ),
                      ),
                      Text('score ${window.score}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: AppColors.ink300)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s8),
          ],

          // Nearby places.
          if (state.places.isNotEmpty) ...[
            Text('Places to walk nearby',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: PawPalette.mint)),
            const SizedBox(height: AppSpace.s8),
            for (final place in state.places.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: PawCard(
                  key: Key('walk_place_${place.name.hashCode}'),
                  padding: const EdgeInsets.all(AppSpace.s12),
                  radius: AppRadius.md,
                  onTap: () => launchUrl(
                    directionsUri(place.lat, place.lon),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        place.kind == 'dog_park'
                            ? Icons.pets_rounded
                            : Icons.park_rounded,
                        color: PawPalette.mint,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(color: AppColors.ink50)),
                            Text(
                              [
                                place.kind.replaceAll('_', ' '),
                                if (place.distanceMeters != null)
                                  distanceLabel(place.distanceMeters),
                              ].join(' · '),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.ink300),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.directions_rounded,
                          color: AppColors.ink300, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s8),
          ],

          // Daily reminder.
          const _WalkReminderCard(),
          const SizedBox(height: AppSpace.s16),

          Text(
            'Weather: MET Norway (CC BY 4.0) · Places: © OpenStreetMap '
            'contributors · Computed on this device.',
            key: const Key('walks_attribution'),
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.ink300),
          ),
          const SizedBox(height: AppSpace.s24),
        ],
      ),
    );
  }
}

String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

class _HourChip extends StatelessWidget {
  const _HourChip({required this.hour, required this.score});

  final HourlyWeather hour;
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final good = score >= 70;
    final fair = score >= 45;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: good
            ? PawPalette.teal.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: AppRadius.brSm,
        border: Border.all(
          color: good
              ? PawPalette.mint.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_hh(hour.time),
              style:
                  theme.textTheme.labelSmall?.copyWith(color: AppColors.ink300)),
          const SizedBox(height: 2),
          Text('${hour.tempC.round()}°',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: AppColors.ink50)),
          const SizedBox(height: 2),
          Icon(
            hour.precipMm > 0.2
                ? Icons.water_drop_rounded
                : good
                    ? Icons.directions_walk_rounded
                    : fair
                        ? Icons.remove_rounded
                        : Icons.block_rounded,
            size: 14,
            color: good ? PawPalette.mint : AppColors.ink300,
          ),
        ],
      ),
    );
  }
}

/// Daily on-device walk reminder (no push vendor — pinned decision honored).
class _WalkReminderCard extends ConsumerStatefulWidget {
  const _WalkReminderCard();

  @override
  ConsumerState<_WalkReminderCard> createState() => _WalkReminderCardState();
}

class _WalkReminderCardState extends ConsumerState<_WalkReminderCard> {
  static const _enabledPref = 'walk_reminder_enabled';
  static const _hourPref = 'walk_reminder_hour';
  static const _minutePref = 'walk_reminder_minute';

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 30);
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
      _enabled = prefs.getBool(_enabledPref) ?? false;
      _time = TimeOfDay(
        hour: prefs.getInt(_hourPref) ?? 17,
        minute: prefs.getInt(_minutePref) ?? 30,
      );
      _loaded = true;
    });
  }

  Future<void> _apply({required bool enabled, TimeOfDay? time}) async {
    final prefs = await SharedPreferences.getInstance();
    final newTime = time ?? _time;
    final notifications = ref.read(localNotificationsProvider);
    if (enabled) {
      final permitted = await notifications.ensurePermission();
      if (!permitted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Notifications are off for PawDoc in Settings.')));
        }
        return;
      }
      final pet = ref.read(activePetProvider);
      await notifications.scheduleDailyWalkReminder(
        hour: newTime.hour,
        minute: newTime.minute,
        petName: pet?.name,
      );
    } else {
      await notifications.cancelDailyWalkReminder();
    }
    await prefs.setBool(_enabledPref, enabled);
    await prefs.setInt(_hourPref, newTime.hour);
    await prefs.setInt(_minutePref, newTime.minute);
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _time = newTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) return const SizedBox.shrink();
    return PawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  color: PawPalette.mint, size: 20),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text('Daily walk reminder',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppColors.ink50)),
              ),
              Switch(
                key: const Key('walk_reminder_toggle'),
                value: _enabled,
                onChanged: (v) => _apply(enabled: v),
              ),
            ],
          ),
          Text(
            'A gentle on-device nudge — no account, no server, works offline.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.ink300),
          ),
          if (_enabled) ...[
            const SizedBox(height: AppSpace.s8),
            OutlinedButton.icon(
              key: const Key('walk_reminder_time'),
              onPressed: () async {
                final picked = await showTimePicker(
                    context: context, initialTime: _time);
                if (picked != null) await _apply(enabled: true, time: picked);
              },
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                  '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
            ),
          ],
        ],
      ),
    );
  }
}

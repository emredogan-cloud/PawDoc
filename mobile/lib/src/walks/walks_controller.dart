import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';
import 'places_service.dart';
import 'walk_scorer.dart';
import 'weather_service.dart';

sealed class WalksState {
  const WalksState();
}

/// Feature not yet enabled — show the contextual pre-prompt (no system
/// permission dialog until the user asks for the feature).
class WalksInitial extends WalksState {
  const WalksInitial();
}

class WalksLoading extends WalksState {
  const WalksLoading();
}

class WalksPermissionNeeded extends WalksState {
  const WalksPermissionNeeded({required this.deniedForever, required this.serviceOff});
  final bool deniedForever;
  final bool serviceOff;
}

class WalksError extends WalksState {
  const WalksError();
}

class WalksReady extends WalksState {
  const WalksReady({
    required this.hours,
    required this.now,
    required this.todayWindows,
    required this.places,
    required this.lat,
    required this.lon,
  });

  final List<HourlyWeather> hours;
  final WalkAssessment now;
  final List<WalkWindow> todayWindows;
  final List<WalkPlace> places;
  final double lat;
  final double lon;
}

/// Orchestrates location → weather → places, all on-device (privacy contract:
/// PawDoc servers never see coordinates). Permission is asked only from the
/// user-initiated [enable] path; once granted, later builds refresh silently.
class WalksController extends Notifier<WalksState> {
  static const _enabledPref = 'walks_enabled';

  @override
  WalksState build() {
    _autoRefreshIfEnabled();
    return const WalksInitial();
  }

  Future<void> _autoRefreshIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledPref) ?? false) {
      await _load(species: 'dog');
    }
  }

  /// User-initiated first enable (triggers the system permission dialog).
  Future<void> enable({String species = 'dog'}) => _load(species: species);

  Future<void> refresh({String species = 'dog'}) => _load(species: species);

  Future<void> _load({required String species}) async {
    state = const WalksLoading();
    final location = await ref.read(locationServiceProvider).current();
    switch (location) {
      case LocationGranted(:final lat, :final lon):
        try {
          final hours =
              await ref.read(weatherServiceProvider).forecast(lat, lon);
          if (hours.isEmpty) {
            state = const WalksError();
            return;
          }
          // Places are decorative next to weather — a failure must not sink
          // the forecast.
          var places = const <WalkPlace>[];
          try {
            places = await ref.read(placesServiceProvider).nearby(lat, lon);
          } catch (_) {}
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enabledPref, true);
          state = WalksReady(
            hours: hours,
            now: scoreWalkHour(hours.first, species: species),
            todayWindows: bestWalkWindows(hours,
                species: species, day: DateTime.now()),
            places: places,
            lat: lat,
            lon: lon,
          );
        } catch (_) {
          state = const WalksError();
        }
      case LocationDeniedForever():
        state = const WalksPermissionNeeded(
            deniedForever: true, serviceOff: false);
      case LocationServiceOff():
        state = const WalksPermissionNeeded(
            deniedForever: false, serviceOff: true);
      case LocationDenied():
        state = const WalksPermissionNeeded(
            deniedForever: false, serviceOff: false);
    }
  }
}

final walksControllerProvider =
    NotifierProvider<WalksController, WalksState>(WalksController.new);

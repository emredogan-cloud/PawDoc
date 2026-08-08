import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Outcome of a location request — a closed set the UI can render calmly.
sealed class LocationResult {
  const LocationResult();
}

class LocationGranted extends LocationResult {
  const LocationGranted(this.lat, this.lon);
  final double lat;
  final double lon;
}

class LocationDenied extends LocationResult {
  const LocationDenied();
}

class LocationDeniedForever extends LocationResult {
  const LocationDeniedForever();
}

class LocationServiceOff extends LocationResult {
  const LocationServiceOff();
}

/// Foreground-only, while-in-use location (Next Evolution F3).
///
/// Privacy contract, stated with its scope — because the unscoped version of
/// this sentence is the one that ends up on a Data safety form and in a store
/// listing, and it is not true of the whole app:
///
/// * **This service** returns coordinates that are used **on-device only**.
///   Smart Walks calls MET Norway for weather and OSM for parks straight from
///   the phone; neither latitude nor longitude is sent to or stored on a
///   PawDoc server by this path.
/// * **Community is a different path.** If — and only if — the owner opts into
///   community discovery, `community_onboarding_screen.dart` takes a fix from
///   here, coarsens it to a **five-character geohash cell** (about 4.9 km
///   across) and stores *that cell* in `community_profiles.geohash`. A cell is
///   still approximate location, and Play's Data safety form must declare it.
///
/// No background location, ever. `ACCESS_FINE_LOCATION` is deliberately not
/// declared in the manifest.
class LocationService {
  const LocationService();

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServiceOff();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationDeniedForever();
      }
      if (permission == LocationPermission.denied) {
        return const LocationDenied();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // City-block accuracy is plenty for weather + parks; it is also the
          // privacy-proportionate choice.
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationGranted(position.latitude, position.longitude);
    } catch (_) {
      // Timeout / platform hiccup: try the (possibly stale) last fix before
      // giving up — good enough for weather.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return LocationGranted(last.latitude, last.longitude);
      } catch (_) {}
      return const LocationDenied();
    }
  }
}

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A nearby walking place from OpenStreetMap.
class WalkPlace {
  const WalkPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.kind,
    this.distanceMeters,
  });

  final String name;
  final double lat;
  final double lon;
  final String kind; // park | dog_park | garden
  final int? distanceMeters;

  WalkPlace withDistanceFrom(double fromLat, double fromLon) => WalkPlace(
        name: name,
        lat: lat,
        lon: lon,
        kind: kind,
        distanceMeters: haversineMeters(fromLat, fromLon, lat, lon).round(),
      );
}

/// Great-circle distance in meters. Pure.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

double _rad(double deg) => deg * math.pi / 180;

/// Parse an Overpass response into named places (unnamed geometry is noise for
/// a recommendation list). Pure — fixture-tested.
List<WalkPlace> parseOverpassPlaces(Map<String, dynamic> body) {
  final elements = (body['elements'] as List?) ?? const [];
  final out = <WalkPlace>[];
  final seen = <String>{};
  for (final raw in elements) {
    final el = raw as Map<String, dynamic>;
    final tags = el['tags'] as Map<String, dynamic>? ?? const {};
    final name = tags['name'] as String?;
    if (name == null || name.trim().isEmpty) continue;
    final leisure = tags['leisure'] as String? ?? 'park';
    // Nodes carry lat/lon; ways/relations carry a center.
    final lat = (el['lat'] as num?) ?? ((el['center'] as Map?)?['lat'] as num?);
    final lon = (el['lon'] as num?) ?? ((el['center'] as Map?)?['lon'] as num?);
    if (lat == null || lon == null) continue;
    if (!seen.add(name.toLowerCase())) continue;
    out.add(WalkPlace(
      name: name.trim(),
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      kind: leisure,
    ));
  }
  return out;
}

/// Nearby walking places via the Overpass API (public instance, fair use:
/// one bounded query, 24 h on-device cache). Attribution rendered in-UI:
/// "© OpenStreetMap contributors". No key, no PawDoc server involvement.
class PlacesService {
  PlacesService({http.Client? client, Future<SharedPreferences>? prefs})
      : _http = client ?? http.Client(),
        _prefs = prefs ?? SharedPreferences.getInstance();

  final http.Client _http;
  final Future<SharedPreferences> _prefs;

  static const _endpoint = 'https://overpass-api.de/api/interpreter';
  static const cacheTtl = Duration(hours: 24);
  static const radiusMeters = 2500;

  Future<List<WalkPlace>> nearby(double lat, double lon) async {
    final rlat = double.parse(lat.toStringAsFixed(3));
    final rlon = double.parse(lon.toStringAsFixed(3));
    final cacheKey = 'walks_places_${rlat}_$rlon';

    final prefs = await _prefs;
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final at = DateTime.parse(decoded['at'] as String);
        if (DateTime.now().difference(at) < cacheTtl) {
          return _withDistances(
            parseOverpassPlaces(decoded['body'] as Map<String, dynamic>),
            lat,
            lon,
          );
        }
      } catch (_) {
        // Corrupt cache — refetch.
      }
    }

    final query = '[out:json][timeout:10];('
        'nwr["leisure"~"^(park|dog_park|garden)\$"]["name"]'
        '(around:$radiusMeters,$rlat,$rlon);'
        ');out center 30;';
    final response = await _http.post(
      Uri.parse(_endpoint),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'PawDoc/1.0 (https://pawdoc.app; support@pawdoc.app)',
      },
      body: 'data=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('places unavailable (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await prefs.setString(
      cacheKey,
      jsonEncode({'at': DateTime.now().toIso8601String(), 'body': body}),
    );
    return _withDistances(parseOverpassPlaces(body), lat, lon);
  }

  List<WalkPlace> _withDistances(
      List<WalkPlace> places, double lat, double lon) {
    final withDistance = [
      for (final p in places) p.withDistanceFrom(lat, lon),
    ]..sort((a, b) =>
        (a.distanceMeters ?? 1 << 30).compareTo(b.distanceMeters ?? 1 << 30));
    return withDistance.take(12).toList(growable: false);
  }
}

final placesServiceProvider = Provider<PlacesService>((ref) => PlacesService());

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// One forecast hour (subset PawDoc needs), parsed from MET Norway
/// Locationforecast 2.0 "compact".
class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.tempC,
    required this.windMs,
    required this.precipMm,
    this.uvIndex,
    this.symbol,
  });

  final DateTime time;
  final double tempC;
  final double windMs;

  /// Precipitation expected in the following hour (mm).
  final double precipMm;
  final double? uvIndex;
  final String? symbol; // e.g. clearsky_day, rain

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temp': tempC,
        'wind': windMs,
        'precip': precipMm,
        'uv': uvIndex,
        'symbol': symbol,
      };

  factory HourlyWeather.fromJson(Map<String, dynamic> json) => HourlyWeather(
        time: DateTime.parse(json['time'] as String),
        tempC: (json['temp'] as num).toDouble(),
        windMs: (json['wind'] as num).toDouble(),
        precipMm: (json['precip'] as num).toDouble(),
        uvIndex: (json['uv'] as num?)?.toDouble(),
        symbol: json['symbol'] as String?,
      );
}

/// Parse the MET compact payload into hourly entries (next ~48h). Pure —
/// fixture-tested. Entries without a next-hour block (the far tail) still
/// parse with precip 0 so "today" is never empty.
List<HourlyWeather> parseMetCompact(Map<String, dynamic> body,
    {int maxHours = 48}) {
  final series = (((body['properties'] as Map?)?['timeseries']) as List?) ??
      const [];
  final out = <HourlyWeather>[];
  for (final raw in series) {
    if (out.length >= maxHours) break;
    final entry = raw as Map<String, dynamic>;
    final data = entry['data'] as Map<String, dynamic>? ?? const {};
    final instant =
        ((data['instant'] as Map?)?['details']) as Map<String, dynamic>? ??
            const {};
    final temp = instant['air_temperature'] as num?;
    if (temp == null) continue;
    final next1 = data['next_1_hours'] as Map<String, dynamic>?;
    out.add(HourlyWeather(
      time: DateTime.parse(entry['time'] as String).toLocal(),
      tempC: temp.toDouble(),
      windMs: ((instant['wind_speed'] as num?) ?? 0).toDouble(),
      precipMm:
          (((next1?['details'] as Map?)?['precipitation_amount'] as num?) ?? 0)
              .toDouble(),
      uvIndex: (instant['ultraviolet_index_clear_sky'] as num?)?.toDouble(),
      symbol: ((next1?['summary'] as Map?)?['symbol_code']) as String?,
    ));
  }
  return out;
}

/// MET Norway Locationforecast client.
///
/// Licensing/ToS compliance (https://api.met.no/doc/TermsOfService):
/// - identifying User-Agent with a contact point;
/// - coordinates truncated to 3 decimals (~110 m) — also a privacy floor;
/// - on-device caching (1 h) so a session never hammers the API.
/// PawDoc servers are NOT involved: the device asks MET directly and
/// coordinates are never stored anywhere.
class WeatherService {
  WeatherService({http.Client? client, Future<SharedPreferences>? prefs})
      : _http = client ?? http.Client(),
        _prefs = prefs ?? SharedPreferences.getInstance();

  final http.Client _http;
  final Future<SharedPreferences> _prefs;

  static const _endpoint = 'https://api.met.no/weatherapi/locationforecast/2.0/compact';
  static const userAgent = 'PawDoc/1.0 (https://pawdoc.app; support@pawdoc.app)';
  static const cacheTtl = Duration(hours: 1);

  Future<List<HourlyWeather>> forecast(double lat, double lon) async {
    final rlat = double.parse(lat.toStringAsFixed(3));
    final rlon = double.parse(lon.toStringAsFixed(3));
    final cacheKey = 'walks_weather_${rlat}_$rlon';

    final prefs = await _prefs;
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final at = DateTime.parse(decoded['at'] as String);
        if (DateTime.now().difference(at) < cacheTtl) {
          return [
            for (final h in decoded['hours'] as List)
              HourlyWeather.fromJson(h as Map<String, dynamic>),
          ];
        }
      } catch (_) {
        // Corrupt cache — fall through to a live fetch.
      }
    }

    final response = await _http.get(
      Uri.parse('$_endpoint?lat=$rlat&lon=$rlon'),
      headers: const {'User-Agent': userAgent},
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('weather unavailable (${response.statusCode})');
    }
    final hours =
        parseMetCompact(jsonDecode(response.body) as Map<String, dynamic>);
    await prefs.setString(
      cacheKey,
      jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'hours': [for (final h in hours) h.toJson()],
      }),
    );
    return hours;
  }
}

final weatherServiceProvider = Provider<WeatherService>((ref) => WeatherService());

// Next Evolution Phase 5 — MET/Overpass fixture parsing + geo math.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/geohash.dart';
import 'package:pawdoc/src/walks/places_service.dart';
import 'package:pawdoc/src/walks/weather_service.dart';

void main() {
  group('parseMetCompact', () {
    final fixture = {
      'properties': {
        'timeseries': [
          {
            'time': '2026-07-24T10:00:00Z',
            'data': {
              'instant': {
                'details': {
                  'air_temperature': 17.3,
                  'wind_speed': 3.2,
                  'ultraviolet_index_clear_sky': 4.1,
                },
              },
              'next_1_hours': {
                'summary': {'symbol_code': 'partlycloudy_day'},
                'details': {'precipitation_amount': 0.2},
              },
            },
          },
          {
            // Far-tail entry without a next_1_hours block still parses.
            'time': '2026-07-26T10:00:00Z',
            'data': {
              'instant': {
                'details': {'air_temperature': 20.0, 'wind_speed': 1.0},
              },
            },
          },
          {
            // Entry missing temperature is skipped.
            'time': '2026-07-26T11:00:00Z',
            'data': {
              'instant': {'details': {'wind_speed': 1.0}},
            },
          },
        ],
      },
    };

    test('extracts the fields PawDoc needs', () {
      final hours = parseMetCompact(fixture);
      expect(hours, hasLength(2));
      expect(hours.first.tempC, 17.3);
      expect(hours.first.precipMm, 0.2);
      expect(hours.first.uvIndex, 4.1);
      expect(hours.first.symbol, 'partlycloudy_day');
      expect(hours.last.precipMm, 0);
    });

    test('respects maxHours and malformed payloads', () {
      expect(parseMetCompact(fixture, maxHours: 1), hasLength(1));
      expect(parseMetCompact(const {}), isEmpty);
      expect(parseMetCompact(const {'properties': {}}), isEmpty);
    });

    test('roundtrips through the cache JSON shape', () {
      final original = parseMetCompact(fixture).first;
      final restored = HourlyWeather.fromJson(original.toJson());
      expect(restored.tempC, original.tempC);
      expect(restored.time, original.time);
      expect(restored.symbol, original.symbol);
    });
  });

  group('parseOverpassPlaces', () {
    final fixture = {
      'elements': [
        {
          'type': 'node',
          'lat': 52.52,
          'lon': 13.40,
          'tags': {'leisure': 'dog_park', 'name': 'Hunde Wiese'},
        },
        {
          'type': 'way',
          'center': {'lat': 52.53, 'lon': 13.41},
          'tags': {'leisure': 'park', 'name': 'Stadtpark'},
        },
        {
          // Unnamed geometry is dropped.
          'type': 'way',
          'center': {'lat': 52.54, 'lon': 13.42},
          'tags': {'leisure': 'park'},
        },
        {
          // Duplicate name (other mapping of the same park) is deduped.
          'type': 'relation',
          'center': {'lat': 52.531, 'lon': 13.411},
          'tags': {'leisure': 'park', 'name': 'stadtpark'},
        },
      ],
    };

    test('keeps named places, dedupes, and reads way centers', () {
      final places = parseOverpassPlaces(fixture);
      expect(places, hasLength(2));
      expect(places.first.name, 'Hunde Wiese');
      expect(places.first.kind, 'dog_park');
      expect(places.last.lat, 52.53);
    });

    test('distance decoration sorts nearest first', () {
      final places = parseOverpassPlaces(fixture)
          .map((p) => p.withDistanceFrom(52.52, 13.40))
          .toList()
        ..sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
      expect(places.first.name, 'Hunde Wiese');
      expect(places.first.distanceMeters, 0);
      expect(places.last.distanceMeters, greaterThan(1000));
    });
  });

  test('haversine matches a known distance band', () {
    // Berlin Mitte → Brandenburg an der Havel ≈ 63 km.
    final d = haversineMeters(52.5200, 13.4050, 52.3906, 12.5) / 1000;
    expect(d, inInclusiveRange(62, 64));
    expect(haversineMeters(52.52, 13.405, 52.52, 13.405), 0);
  });

  group('geohash', () {
    test('encodes the canonical test vector', () {
      // Known vector from the original geohash reference.
      expect(geohashEncode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
      expect(geohashEncode(52.52, 13.405, precision: 5), 'u33dc');
    });

    test('decode center is inside the encoded cell', () {
      final hash = geohashEncode(41.0082, 28.9784, precision: 5); // Istanbul
      final (lat, lon) = geohashDecodeCenter(hash);
      expect(geohashEncode(lat, lon, precision: 5), hash);
    });

    test('neighbors form the 3x3 block including self', () {
      final hash = geohashEncode(52.52, 13.405, precision: 5);
      final neighbors = geohashNeighbors(hash);
      expect(neighbors, contains(hash));
      expect(neighbors.toSet(), hasLength(9));
      expect(neighbors.every((n) => n.length == 5), isTrue);
    });

    test('rejects invalid characters', () {
      expect(() => geohashDecodeCenter('u33a!'), throwsFormatException);
    });
  });
}

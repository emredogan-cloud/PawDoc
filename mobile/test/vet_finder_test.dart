import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/vet_finder/maps_links.dart';
import 'package:pawdoc/src/vet_finder/vet.dart';

void main() {
  group('maps_links', () {
    test('vetSearchMapsUri builds a vet search (near me / by area)', () {
      expect(vetSearchMapsUri().toString(), contains('veterinarian%20near%20me'));
      expect(vetSearchMapsUri('10001').toString(), contains('veterinarian%2010001'));
    });

    test('directionsUri targets the coordinates', () {
      expect(directionsUri(40.7, -74.0).toString(), contains('destination=40.7,-74.0'));
    });

    test('telUri sanitizes and rejects undialable input', () {
      expect(telUri('+1 (555) 123-4567').toString(), 'tel:+15551234567');
      expect(telUri(null), isNull);
      expect(telUri('n/a'), isNull);
    });

    test('distanceLabel formats metres / km / unknown', () {
      expect(distanceLabel(450), '450 m');
      expect(distanceLabel(2300), '2.3 km');
      expect(distanceLabel(null), '');
    });
  });

  group('Vet.fromJson', () {
    test('parses the clean proxy JSON', () {
      final v = Vet.fromJson(const {
        'name': 'Happy Paws',
        'phone': '+1 555',
        'openNow': true,
        'address': '1 Main St',
        'lat': 40.7,
        'lng': -74.0,
        'distanceMeters': 500,
      });
      expect(v.name, 'Happy Paws');
      expect(v.openNow, true);
      expect(v.distanceMeters, 500);
      expect(v.lat, 40.7);
    });

    test('defaults a missing name', () {
      expect(Vet.fromJson(const {}).name, 'Veterinary clinic');
    });
  });
}

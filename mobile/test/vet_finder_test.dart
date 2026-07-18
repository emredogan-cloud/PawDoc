import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/vet_finder/maps_links.dart';

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

}

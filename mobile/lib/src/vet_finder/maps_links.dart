// Native-maps + dialer deep links for the vet finder (Phase 3.4). Pure +
// unit-tested. These are the graceful fallback when location/Places are
// unavailable — the same native-maps strategy used since Phase 1.4.

/// A Google Maps search for vets (optionally near a zip/city). Opens in the
/// native maps app; no API key needed.
Uri vetSearchMapsUri([String? near]) {
  final q = (near == null || near.trim().isEmpty)
      ? 'veterinarian near me'
      : 'veterinarian ${near.trim()}';
  return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
}

/// Turn-by-turn directions to a clinic's coordinates.
Uri directionsUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

/// `tel:` URI for a phone number, or null if there's nothing dialable.
Uri? telUri(String? phone) {
  if (phone == null) return null;
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.isEmpty) return null;
  return Uri.parse('tel:$cleaned');
}

/// Human distance label: `450 m` / `2.3 km` / `''` when unknown.
String distanceLabel(int? meters) {
  if (meters == null) return '';
  if (meters < 1000) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Emergency variant — searches specifically for emergency clinics. Opens the
/// OS maps app, which handles location itself: PawDoc requests NO location
/// permission and never sees coordinates.
Uri emergencyVetSearchMapsUri() => Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('emergency veterinarian near me')}');

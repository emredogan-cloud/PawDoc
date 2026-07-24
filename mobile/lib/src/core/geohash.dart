/// Pure geohash utilities (Next Evolution F3 foundation).
///
/// Used by Smart Walks (on-device only) and, later, Community discovery —
/// where a TRUNCATED geohash is the only location-shaped value that ever
/// leaves the device (precision 5 ≈ ±2.4 km cell; never raw coordinates).
/// No plugin: ~60 lines of well-tested arithmetic beats a dependency.
library;

const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Encode [lat]/[lon] to a geohash of [precision] characters.
String geohashEncode(double lat, double lon, {int precision = 5}) {
  assert(precision > 0 && precision <= 12);
  var latLo = -90.0, latHi = 90.0, lonLo = -180.0, lonHi = 180.0;
  var isLon = true;
  var bit = 0, ch = 0;
  final out = StringBuffer();
  while (out.length < precision) {
    if (isLon) {
      final mid = (lonLo + lonHi) / 2;
      if (lon >= mid) {
        ch = (ch << 1) | 1;
        lonLo = mid;
      } else {
        ch = ch << 1;
        lonHi = mid;
      }
    } else {
      final mid = (latLo + latHi) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latLo = mid;
      } else {
        ch = ch << 1;
        latHi = mid;
      }
    }
    isLon = !isLon;
    if (++bit == 5) {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}

/// Decode a geohash to its cell-center (lat, lon).
(double, double) geohashDecodeCenter(String hash) {
  var latLo = -90.0, latHi = 90.0, lonLo = -180.0, lonHi = 180.0;
  var isLon = true;
  for (final c in hash.toLowerCase().split('')) {
    final cd = _base32.indexOf(c);
    if (cd < 0) throw FormatException('invalid geohash char: $c');
    for (var mask = 16; mask > 0; mask >>= 1) {
      if (isLon) {
        final mid = (lonLo + lonHi) / 2;
        if (cd & mask != 0) {
          lonLo = mid;
        } else {
          lonHi = mid;
        }
      } else {
        final mid = (latLo + latHi) / 2;
        if (cd & mask != 0) {
          latLo = mid;
        } else {
          latHi = mid;
        }
      }
      isLon = !isLon;
    }
  }
  return ((latLo + latHi) / 2, (lonLo + lonHi) / 2);
}

/// The 3×3 block of cells around [hash] (itself included) — the standard
/// "nearby" query set: everything within one cell in any direction.
List<String> geohashNeighbors(String hash) {
  final (lat, lon) = geohashDecodeCenter(hash);
  // Cell size at this precision, derived from the decode bounds.
  var latLo = -90.0, latHi = 90.0, lonLo = -180.0, lonHi = 180.0;
  var isLon = true;
  for (final c in hash.toLowerCase().split('')) {
    final cd = _base32.indexOf(c);
    for (var mask = 16; mask > 0; mask >>= 1) {
      if (isLon) {
        final mid = (lonLo + lonHi) / 2;
        (cd & mask != 0) ? lonLo = mid : lonHi = mid;
      } else {
        final mid = (latLo + latHi) / 2;
        (cd & mask != 0) ? latLo = mid : latHi = mid;
      }
      isLon = !isLon;
    }
  }
  final dLat = latHi - latLo;
  final dLon = lonHi - lonLo;
  final out = <String>{};
  for (final dy in [-1, 0, 1]) {
    for (final dx in [-1, 0, 1]) {
      final nLat = (lat + dy * dLat).clamp(-90.0, 90.0);
      var nLon = lon + dx * dLon;
      if (nLon > 180) nLon -= 360;
      if (nLon < -180) nLon += 360;
      out.add(geohashEncode(nLat, nLon, precision: hash.length));
    }
  }
  return out.toList(growable: false);
}

// ENG-01/PERF-03: brand typography must be offline-deterministic. The exact
// static TTFs google_fonts resolves (family-<ApiWeightName>.ttf) must ship as
// assets, so a cold offline first launch renders correct type and no
// pre-consent request to fonts.gstatic.com can ever fire.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredFonts = [
    // Inter (body): w400/w500/w600 used by AppType; Bold for copyWith headers.
    'assets/google_fonts/Inter-Regular.ttf',
    'assets/google_fonts/Inter-Medium.ttf',
    'assets/google_fonts/Inter-SemiBold.ttf',
    'assets/google_fonts/Inter-Bold.ttf',
    // Bricolage Grotesque (display): w600 is the ramp; Regular/Bold safety net.
    'assets/google_fonts/BricolageGrotesque-Regular.ttf',
    'assets/google_fonts/BricolageGrotesque-SemiBold.ttf',
    'assets/google_fonts/BricolageGrotesque-Bold.ttf',
  ];

  test('every google_fonts static TTF ships as an asset', () {
    for (final path in requiredFonts) {
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: 'missing bundled font: $path');
      expect(f.lengthSync(), greaterThan(10 * 1024),
          reason: 'suspiciously small font file: $path');
    }
  });

  test('main.dart disables runtime font fetching', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('GoogleFonts.config.allowRuntimeFetching = false'),
        isTrue,
        reason: 'runtime font fetching must stay disabled (ENG-01)');
  });
}

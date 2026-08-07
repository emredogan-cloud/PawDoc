// Phase A guard. The redesign swaps a teal system for lime-on-black, and the
// failure mode is silent: a pairing that looks fine on a bright desktop monitor
// can be unreadable on a phone outdoors. Contrast is therefore asserted, not
// eyeballed — and the safety-locked status hues are pinned by literal value so
// a palette sweep can never quietly recolour the action ladder.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio, 1..21.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _aaText = 4.5;
const _aaLarge = 3.0;

void main() {
  group('System B (in-app) contrast', () {
    test('lime accent clears AA text on every dark surface', () {
      for (final bg in [AppColors.carbon900, AppColors.carbon850, AppColors.carbon800]) {
        expect(contrast(AppColors.lime500, bg), greaterThanOrEqualTo(_aaText));
        expect(contrast(AppColors.lime400, bg), greaterThanOrEqualTo(_aaText));
      }
    });

    test('body text clears AA on the dark canvas', () {
      expect(contrast(AppColors.ink50, AppColors.carbon900), greaterThanOrEqualTo(_aaText));
      expect(contrast(AppColors.ink300, AppColors.carbon900), greaterThanOrEqualTo(_aaText));
    });

    test('lime500 is NOT usable as light-theme text — the light ramp must be used', () {
      // Pinning the trap: 1.51:1. If someone "simplifies" accent() to return
      // lime500 in both brightnesses, this fails loudly instead of shipping
      // invisible text.
      expect(contrast(AppColors.lime500, AppColors.lightSurface), lessThan(_aaLarge));
      expect(contrast(AppColors.lime700OnLight, AppColors.lightSurface),
          greaterThanOrEqualTo(_aaText));
      expect(contrast(AppColors.lime700OnLight, AppColors.lightBackground),
          greaterThanOrEqualTo(_aaText));
    });

    test('accent() resolves to the readable value per brightness', () {
      expect(AppColors.accent(PawSystem.b, Brightness.dark), AppColors.lime500);
      expect(AppColors.accent(PawSystem.b, Brightness.light), AppColors.lime700OnLight);
    });
  });

  group('System A (onboarding) contrast', () {
    test('emerald and cyan clear AA text on navy', () {
      for (final bg in [AppColors.navy900, AppColors.navy850]) {
        expect(contrast(AppColors.emerald500, bg), greaterThanOrEqualTo(_aaText));
        expect(contrast(AppColors.cyan400, bg), greaterThanOrEqualTo(_aaText));
        expect(contrast(AppColors.cyan300, bg), greaterThanOrEqualTo(_aaText));
      }
    });

    test('body text clears AA on navy', () {
      expect(contrast(AppColors.ink50, AppColors.navy900), greaterThanOrEqualTo(_aaText));
    });
  });

  group('safety-locked status hues are unchanged', () {
    // These are contract-bearing: the action ladder's colour language. Pinned by
    // literal value so a redesign sweep cannot repurpose or drift them.
    test('literal values', () {
      expect(AppColors.emergencyLight, const Color(0xFFC62828));
      expect(AppColors.emergencyDark, const Color(0xFFFF5A52));
      expect(AppColors.monitorLight, const Color(0xFFFFB300));
      expect(AppColors.monitorDark, const Color(0xFFFFC233));
      expect(AppColors.actionBookVisit, const Color(0xFF1565C0));
      expect(AppColors.actionWatch, const Color(0xFF455A64));
    });

    test('emergency hue stays legible in both themes', () {
      expect(contrast(AppColors.emergencyLight, AppColors.lightSurface),
          greaterThanOrEqualTo(_aaText));
      expect(contrast(AppColors.emergencyDark, AppColors.carbon900),
          greaterThanOrEqualTo(_aaText));
      expect(contrast(AppColors.emergencyDark, AppColors.ink900),
          greaterThanOrEqualTo(_aaText));
    });

    test('no brand accent collides with a status hue', () {
      // Lime must never be mistakable for a triage signal. Distance is crude but
      // enough to catch someone setting monitor := lime.
      for (final brand in [AppColors.lime500, AppColors.lime400, AppColors.emerald500]) {
        for (final status in [
          AppColors.emergencyLight,
          AppColors.emergencyDark,
          AppColors.monitorLight,
          AppColors.monitorDark,
        ]) {
          expect(brand.toARGB32() == status.toARGB32(), isFalse,
              reason: 'brand accent must not equal a safety-locked status hue');
        }
      }
    });
  });

  group('canvas()', () {
    test('each system gets its own dark canvas', () {
      expect(AppColors.canvas(PawSystem.a, Brightness.dark), AppColors.navy900);
      expect(AppColors.canvas(PawSystem.b, Brightness.dark), AppColors.carbon900);
      expect(AppColors.canvas(PawSystem.legacy, Brightness.dark), AppColors.ink900);
    });

    test('light mode keeps the shared warm off-white', () {
      for (final s in PawSystem.values) {
        expect(AppColors.canvas(s, Brightness.light), AppColors.lightBackground);
      }
    });
  });
}

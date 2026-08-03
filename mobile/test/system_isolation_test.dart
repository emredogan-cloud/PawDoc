// Phase P guard — System A must stay isolated to onboarding and sign-in.
//
// The two visual systems in the mockups are not interchangeable
// (UI_ASSET_SPECIFICATION §1.3): onboarding is navy + emerald + cyan, the
// in-app product is near-black + lime, and an asset drawn for one looks wrong
// in the other.
//
// This became a live risk in Phases J–O. `PawPalette.mint`/`.teal` were
// repointed to the lime ramp — correct for the ~120 in-app call sites, but it
// means onboarding renders lime the moment it stops declaring its own system.
// The boundary is now load-bearing, so it is asserted rather than assumed.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';
import 'package:pawdoc/src/theme/paw_components.dart';

void main() {
  group('the two systems never collapse into one', () {
    test('their accents differ in both brightnesses', () {
      for (final b in Brightness.values) {
        expect(AppColors.accent(PawSystem.a, b),
            isNot(AppColors.accent(PawSystem.b, b)),
            reason: 'System A and System B must not share an accent ($b)');
      }
    });

    test('their dark canvases differ', () {
      expect(AppColors.canvas(PawSystem.a, Brightness.dark),
          isNot(AppColors.canvas(PawSystem.b, Brightness.dark)));
    });
  });

  group('System A is declared where it is required', () {
    test('onboarding declares it', () {
      final src =
          File('lib/src/onboarding/onboarding_flow.dart').readAsStringSync();
      expect(src.contains('PawSystemScope'), isTrue);
      expect(src.contains('PawSystem.a'), isTrue,
          reason: 'onboarding inherits System B from the app root otherwise, '
              'and would render lime where the mockups call for emerald/cyan');
    });

    test('sign-in declares it', () {
      final src = File('lib/src/auth/sign_in_screen.dart').readAsStringSync();
      expect(src.contains('PawSystem.a'), isTrue);
    });

    test('the app root declares System B', () {
      final src = File('lib/src/app.dart').readAsStringSync();
      expect(src.contains('PawSystem.b'), isTrue,
          reason: 'pushed routes sit above the shell scope; without this every '
              'detail screen falls back to legacy');
    });
  });

  group('System A resolves to its own tone', () {
    testWidgets('a subtree scoped to A gets emerald on navy', (tester) async {
      late PawTone tone;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: PawSystemScope(
          system: PawSystem.a,
          child: Builder(builder: (c) {
            tone = PawTone.of(c);
            return const SizedBox();
          }),
        ),
      ));
      expect(tone.accent, AppColors.emerald500);
      expect(tone.canvas, AppColors.navy900);
      expect(tone.accent, isNot(AppColors.lime500));
    });

    testWidgets('a subtree scoped to B gets lime on carbon', (tester) async {
      late PawTone tone;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: PawSystemScope(
          system: PawSystem.b,
          child: Builder(builder: (c) {
            tone = PawTone.of(c);
            return const SizedBox();
          }),
        ),
      ));
      expect(tone.accent, AppColors.lime500);
      expect(tone.canvas, AppColors.carbon900);
    });
  });
}

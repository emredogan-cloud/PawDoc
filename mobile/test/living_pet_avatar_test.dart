// M2 LivingPetAvatar contract: reduce-motion = static species PNG (zero rig
// in the tree); rig-load failure degrades to the original paw-disc; the
// kill-switch flag reverts to the paw-disc; result screen wires the beat
// only on non-emergency levels.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/result_screen.dart';
import 'package:pawdoc/src/core/app_image.dart';
import 'package:pawdoc/src/core/living_pet_avatar.dart';
import 'package:pawdoc/src/experiments/feature_flags.dart';
import 'package:pawdoc/src/models/analysis_result.dart';
import 'package:rive/rive.dart' show Rive;

Widget _wrap(Widget child,
        {bool reduceMotion = true, List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
                body: Center(
                    child: SizedBox(width: 120, height: 120, child: child))),
          ),
        ),
      ),
    );

void main() {
  group('kill-switch semantics (device finding D-2)', () {
    FeatureFlags flags(Object? Function() get) =>
        FeatureFlags(getFlag: (_) async => get());

    test('absent flag -> ON', () async {
      expect(await flags(() => null).isEnabledUnlessKilled('k'), isTrue);
    });
    test('explicit false/off strings -> OFF', () async {
      expect(await flags(() => false).isEnabledUnlessKilled('k'), isFalse);
      expect(await flags(() => 'false').isEnabledUnlessKilled('k'), isFalse);
      expect(await flags(() => 'off').isEnabledUnlessKilled('k'), isFalse);
    });
    test('true / arbitrary variant -> ON', () async {
      expect(await flags(() => true).isEnabledUnlessKilled('k'), isTrue);
      expect(await flags(() => 'B').isEnabledUnlessKilled('k'), isTrue);
    });
    test('PostHog failure -> ON', () async {
      expect(
          await flags(() => throw Exception('down')).isEnabledUnlessKilled('k'),
          isTrue);
    });
  });

  testWidgets('reduce-motion: static species PNG, zero rig', (tester) async {
    await tester.pumpWidget(_wrap(
      const LivingPetAvatar(species: 'dog', size: 56),
      reduceMotion: true,
    ));
    await tester.pump();

    expect(find.byType(Rive), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/icons/species/species_dog.png');
  });

  testWidgets('unknown species maps to the other-paw still', (tester) async {
    await tester.pumpWidget(_wrap(
      const LivingPetAvatar(species: 'axolotl', size: 56),
      reduceMotion: true,
    ));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/icons/species/species_other_paw.png');
  });

  testWidgets(
      'rig unavailable on this host → degrades to the paw-disc, never breaks',
      (tester) async {
    // Motion ON in a host without the rive native lib = the real degrade
    // path (RiveFile.import throws, the widget catches, paw-disc renders).
    await tester.pumpWidget(_wrap(
      const LivingPetAvatar(species: 'cat', size: 56),
      reduceMotion: false,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(
        find.byWidgetPredicate(
            (w) => w is CircleAvatar || w is Rive || w is AppImage),
        findsWidgets);
  });

  testWidgets('kill-switch flag OFF → original paw-disc', (tester) async {
    await tester.pumpWidget(_wrap(
      const LivingPetAvatar(species: 'dog', size: 56),
      reduceMotion: false,
      overrides: [pawPalsEnabledProvider.overrideWith((ref) async => false)],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Rive), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('NORMAL result carries the avatar slot; level routing correct',
      (tester) async {
    const normal = AnalysisResult(
      action: ActionLevel.watchAndRecheck,
      confidence: 0.9,
      observation: 'Looks fine',
      visibleSymptoms: [],
      vetsLookFor: [],
      watchFor: [],
      recommendedActions: ['nothing needed'],
      urgencyTimeframe: 'routine',
      recheckHours: null,
      disclaimerRequired: true,
    );
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ResultScreen(
            result: normal, analysisId: 'a1', petName: 'rex', petSpecies: 'dog'),
      ),
    ));
    await tester.pump();

    expect(find.byType(LivingPetAvatar), findsOneWidget);
  });
}

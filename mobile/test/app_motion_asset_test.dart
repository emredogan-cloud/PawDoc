// AppMotionAsset contract (M1): reduce-motion renders the static PNG (no
// Lottie in the tree at all), and a missing/corrupt asset degrades to the PNG.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pawdoc/src/core/app_image.dart';
import 'package:pawdoc/src/core/app_motion_asset.dart';
import 'package:pawdoc/src/theme/app_assets.dart';

Widget _wrap(Widget child, {required bool reduceMotion}) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  testWidgets('reduce-motion: static PNG only — zero Lottie in the tree',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const AppMotionAsset(
        AppMotionAssets.emptyHomeLoop,
        fallbackAsset: AppAssets.emptyHome,
        height: 160,
        fallback: Icon(Icons.pets_rounded),
      ),
      reduceMotion: true,
    ));
    await tester.pump();

    expect(find.byType(Lottie), findsNothing);
    expect(find.byType(AppImage), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, AppAssets.emptyHome,
        reason: 'reduce-motion must show the existing AppAssets PNG');
  });

  testWidgets('motion enabled: the Lottie layer is present', (tester) async {
    await tester.pumpWidget(_wrap(
      const AppMotionAsset(
        AppMotionAssets.emptyHomeLoop,
        fallbackAsset: AppAssets.emptyHome,
        height: 160,
        fallback: Icon(Icons.pets_rounded),
      ),
      reduceMotion: false,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Lottie), findsOneWidget);
  });

  testWidgets('missing asset degrades to the PNG, never a broken box',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const AppMotionAsset(
        'assets/motion/does_not_exist_v1.json',
        fallbackAsset: AppAssets.emptyHome,
        height: 160,
        fallback: Icon(Icons.pets_rounded),
      ),
      reduceMotion: false,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppImage), findsOneWidget);
  });
}

// The Assistant has one face, and it belongs to the Assistant only.
//
// The greeting hero and every assistant reply render the same widget, so the
// mask/ring/glow cannot drift apart; user bubbles must never carry it (an
// avatar on both sides makes a transcript unreadable at a glance).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/assistant/assistant_avatar.dart';
import 'package:pawdoc/src/core/app_image.dart';
import 'package:pawdoc/src/theme/app_assets.dart';

void main() {
  testWidgets('renders the portrait asset, circular, at the requested size',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AssistantAvatar(size: 88))),
    ));

    expect(find.byType(AssistantAvatar), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
    expect(tester.getSize(find.byType(AssistantAvatar)), const Size(88, 88));

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, AppAssets.assistantAvatar);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('the portrait actually ships — the asset resolves in the bundle',
      (tester) async {
    // Guards the pubspec entry: drop it and this fails instead of silently
    // shipping the paw-mark fallback to every user.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AssistantAvatar(size: 40))),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.pets_rounded), findsNothing,
        reason: 'the fallback must not be what users see');
  });

  testWidgets('a missing asset degrades to the paw mark, never a broken box',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppImage(
            'assets/ai-assistans/does_not_exist.png',
            fallback: Icon(Icons.pets_rounded),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
  });

  testWidgets('the glow is opt-out for dense rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          AssistantAvatar(size: 28, glow: false),
          AssistantAvatar(size: 88),
        ]),
      ),
    ));

    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .toList();
    final shadows = decorations.map((d) => d.boxShadow).toList();
    expect(shadows.any((s) => s == null), isTrue, reason: 'glow:false has none');
    expect(shadows.any((s) => s != null && s.isNotEmpty), isTrue,
        reason: 'the hero keeps its halo');
  });
}

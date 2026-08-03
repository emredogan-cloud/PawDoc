// Phase B guard for the redesign component library.
//
// These components carry the whole migration: every screen phase builds on
// them, so a defect here multiplies across 57 screens. The properties worth
// pinning are the ones that are invisible in a screenshot — system isolation,
// touch-target size, overflow behaviour at 320dp and 200% text scale, and that
// the Emergency accent override actually overrides.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';
import 'package:pawdoc/src/theme/paw_components.dart';

Widget _host(
  Widget child, {
  PawSystem system = PawSystem.b,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
    ),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, textTheme: AppType.textTheme()),
      home: PawSystemScope(
        system: system,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  group('PawSystemScope / PawTone', () {
    testWidgets('each system resolves its own accent and canvas', (tester) async {
      for (final (system, expected) in [
        (PawSystem.b, AppColors.lime500),
        (PawSystem.a, AppColors.emerald500),
        (PawSystem.legacy, AppColors.teal600Dark),
      ]) {
        late PawTone tone;
        await tester.pumpWidget(_host(
          Builder(builder: (c) {
            tone = PawTone.of(c);
            return const SizedBox();
          }),
          system: system,
        ));
        expect(tone.accent, expected, reason: '$system accent');
      }
    });

    test('System A and System B never share an accent', () {
      // The whole point of PawSystem: onboarding emerald must not leak into the
      // in-app screens, or vice versa, when a shared component crosses over.
      expect(AppColors.accent(PawSystem.a, Brightness.dark),
          isNot(AppColors.accent(PawSystem.b, Brightness.dark)));
    });

    testWidgets('light mode swaps System B to the readable lime', (tester) async {
      late PawTone tone;
      await tester.pumpWidget(_host(
        Builder(builder: (c) {
          tone = PawTone.of(c);
          return const SizedBox();
        }),
        brightness: Brightness.light,
      ));
      expect(tone.accent, AppColors.lime700OnLight);
    });
  });

  group('PawCta', () {
    testWidgets('fires, and meets the 48dp touch target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        PawCta(label: 'AI Health Check', onPressed: () => taps++),
      ));
      await tester.tap(find.text('AI Health Check'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(InkWell).first).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(_host(const PawCta(label: 'Go', onPressed: null)));
      final s = tester.widget<Semantics>(find
          .descendant(of: find.byType(PawCta), matching: find.byType(Semantics))
          .first);
      expect(s.properties.enabled, isFalse);
    });

    testWidgets('long label ellipsises instead of overflowing at 320dp', (tester) async {
      await tester.pumpWidget(_host(
        const PawCta(
            label: 'An extremely long call to action label that cannot fit',
            onPressed: null),
        size: const Size(320, 700),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('PawQuickAction', () {
    testWidgets('accentOverride wins over the brand accent', (tester) async {
      // The Emergency tile must render in the safety-locked red, never lime —
      // colour is part of the action ladder's language.
      await tester.pumpWidget(_host(PawQuickAction(
        icon: LucideIcons.circlePlus,
        label: 'Emergency',
        caption: 'Get help now',
        accentOverride: AppColors.emergencyDark,
        onTap: () {},
      )));
      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.circlePlus));
      expect(icon.color, AppColors.emergencyDark);
      expect(icon.color, isNot(AppColors.lime500));
    });

    testWidgets('survives 200% text scale without overflow', (tester) async {
      await tester.pumpWidget(_host(
        SizedBox(
          width: 96,
          child: PawQuickAction(
            icon: LucideIcons.messageCircle,
            label: 'AI Assistant',
            caption: 'Ask PawDoc AI',
            onTap: () {},
          ),
        ),
        textScale: 2.0,
        size: const Size(320, 700),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('PawIcon', () {
    testWidgets('core glyph renders as a tinted Lucide icon', (tester) async {
      await tester.pumpWidget(
          _host(const PawIcon(LucideIcons.heartPulse, color: Color(0xFF00FF00))));
      expect(tester.widget<Icon>(find.byType(Icon)).color, const Color(0xFF00FF00));
    });

    testWidgets('art variant is never tinted — colour is the information',
        (tester) async {
      await tester.pumpWidget(
          _host(const PawIcon.art('assets/icons/vaccines/ic-vax-rabies@3x.png')));
      expect(tester.widget<Image>(find.byType(Image)).color, isNull);
    });

    testWidgets('glyph variant is tinted via srcIn', (tester) async {
      await tester.pumpWidget(_host(const PawIcon.glyph(
          'assets/icons/symptoms/ic-symptom-itching.png',
          color: Color(0xFFFF0000))));
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.color, const Color(0xFFFF0000));
      expect(img.colorBlendMode, BlendMode.srcIn);
    });

    testWidgets('a missing asset degrades instead of throwing', (tester) async {
      await tester.pumpWidget(_host(const PawIcon.glyph('assets/does/not/exist.png')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('PawSectionHeader', () {
    testWidgets('action is tappable and meets the touch target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(PawSectionHeader(
        title: 'Health Timeline',
        icon: LucideIcons.activity,
        actionLabel: 'View All',
        onAction: () => taps++,
      )));
      await tester.tap(find.text('View All'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(InkWell).first).height,
          greaterThanOrEqualTo(48));
    });
  });

  group('PawListRow', () {
    testWidgets('renders title, subtitle and trailing text', (tester) async {
      await tester.pumpWidget(_host(const PawListRow(
        title: 'Heartworm Medication',
        subtitle: 'Due today',
        trailingText: '08:30',
      )));
      expect(find.text('Heartworm Medication'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      expect(find.text('08:30'), findsOneWidget);
    });

    testWidgets('long strings ellipsise at 320dp and 200% scale', (tester) async {
      await tester.pumpWidget(_host(
        const PawListRow(
          title: 'A very long health record title that will not fit on one line',
          subtitle: 'And an equally long supporting subtitle for good measure',
          trailingText: 'Yesterday',
        ),
        textScale: 2.0,
        size: const Size(320, 700),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('PawTimeline', () {
    testWidgets('renders every child', (tester) async {
      await tester.pumpWidget(_host(const PawTimeline(children: [
        PawListRow(title: 'One'),
        PawListRow(title: 'Two'),
        PawListRow(title: 'Three'),
      ])));
      for (final s in ['One', 'Two', 'Three']) {
        expect(find.text(s), findsOneWidget);
      }
    });
  });

  group('PawProgressRing', () {
    testWidgets('clamps out-of-range values', (tester) async {
      await tester.pumpWidget(_host(
          const PawProgressRing(value: 1.8, label: '92', semanticLabel: 'score')));
      final ind = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      expect(ind.value, 1.0);
    });
  });

  group('PawEmptyState', () {
    testWidgets('falls back to an icon when the art is missing', (tester) async {
      await tester.pumpWidget(_host(const PawEmptyState(
        title: 'No memories yet',
        body: 'Start capturing moments.',
        art: 'assets/missing/art.png',
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('No memories yet'), findsOneWidget);
    });
  });

  group('PawPanel', () {
    testWidgets('selected state changes the border', (tester) async {
      await tester.pumpWidget(_host(const Column(children: [
        PawPanel(selected: false, child: Text('a')),
        PawPanel(selected: true, child: Text('b')),
      ])));
      final boxes = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((w) => (w.decoration as BoxDecoration).border as Border)
          .toList();
      expect(boxes[0].top.width, lessThan(boxes[1].top.width));
    });
  });
}

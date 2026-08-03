// Phase C guard for the navigation shell.
//
// The contract rule this phase exists to protect: GET_HELP_NOW must never be
// paywalled or displaced. The mockups' Variant B puts Premium in the slot that
// otherwise holds Emergencies on nine screens (conflict C-7 / review V-24), so
// the shell is where that decision has to be enforced — and enforced by a test,
// because "Emergency is still in the nav" is exactly the kind of thing a later
// redesign sweep silently changes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pawdoc/src/core/root_shell.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';

Widget _host({Size size = const Size(390, 844), double textScale = 1.0}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, textTheme: AppType.textTheme()),
      home: const RootShell(),
    ),
  );
}

/// The shell's children hit Supabase/Riverpod on mount, which we neither want
/// nor need here — only the chrome is under test. Pumping without settling and
/// swallowing child exceptions keeps the assertions on the nav bar itself.
Future<void> _pumpShell(WidgetTester tester, {Widget? host}) async {
  await tester.pumpWidget(host ?? _host());
  await tester.pump(const Duration(milliseconds: 50));
  tester.takeException();
}

void main() {
  group('Emergency is a permanent destination', () {
    testWidgets('present in the nav bar', (tester) async {
      await _pumpShell(tester);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
      expect(find.text('Emergency'), findsOneWidget);
    });

    testWidgets('stays present on every tab', (tester) async {
      await _pumpShell(tester);
      for (final tab in ['Pets', 'Health', 'Home']) {
        await tester.tap(find.text(tab));
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();
        expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget,
            reason: 'Emergency disappeared while on the $tab tab');
      }
    });

    testWidgets('carries the safety-locked red, never the brand lime',
        (tester) async {
      await _pumpShell(tester);
      final icon = tester.widget<Icon>(find.descendant(
        of: find.byKey(const Key('root_nav_emergency')),
        matching: find.byIcon(LucideIcons.circleAlert),
      ));
      expect(icon.color, AppColors.emergencyDark);
      expect(icon.color, isNot(AppColors.lime500),
          reason: 'the emergency affordance must not read as a brand accent');
    });

    testWidgets('no Premium destination occupies a nav slot (C-7 / V-24)',
        (tester) async {
      await _pumpShell(tester);
      for (final forbidden in ['Premium', 'Upgrade', 'Go Pro', 'Subscribe']) {
        expect(find.text(forbidden), findsNothing,
            reason: 'Premium must never take a bottom-nav slot');
      }
    });
  });

  group('nav bar structure', () {
    testWidgets('four destinations plus the centre action', (tester) async {
      await _pumpShell(tester);
      for (final label in ['Home', 'Pets', 'Health', 'Emergency']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byKey(const Key('root_nav_centre')), findsOneWidget);
    });

    testWidgets('every target clears 48dp at 320dp width', (tester) async {
      await _pumpShell(tester, host: _host(size: const Size(320, 640)));
      for (final label in ['Home', 'Pets', 'Health', 'Emergency']) {
        final box = tester.getSize(find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        ));
        expect(box.height, greaterThanOrEqualTo(48), reason: '$label height');
        expect(box.width, greaterThanOrEqualTo(48), reason: '$label width');
      }
      expect(tester.getSize(find.byKey(const Key('root_nav_centre'))).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('labels survive 200% text scale without overflow', (tester) async {
      await _pumpShell(tester,
          host: _host(size: const Size(320, 640), textScale: 2.0));
      expect(tester.takeException(), isNull);
      // Labels must not be dropped: an icon-only nav is unusable for anyone who
      // cannot read the pictogram.
      expect(find.text('Emergency'), findsOneWidget);
    });

    testWidgets('destinations are exposed as selectable buttons', (tester) async {
      await _pumpShell(tester);
      final s = tester.widget<Semantics>(find
          .descendant(
              of: find.byKey(const Key('root_nav_emergency')),
              matching: find.byType(Semantics))
          .first);
      expect(s.properties.button, isTrue);
      expect(s.properties.label, 'Emergency');
    });
  });

  group('centre action sheet', () {
    testWidgets('offers capture and assistant, and is dismissible',
        (tester) async {
      await _pumpShell(tester);
      await tester.tap(find.byKey(const Key('root_nav_centre')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Photo check'), findsOneWidget);
      expect(find.text('Describe symptoms'), findsOneWidget);
      expect(find.text('Ask PawDoc AI'), findsOneWidget);

      // Nothing in the sheet may monetise or gate — it is the primary path to
      // a health check.
      for (final forbidden in ['Upgrade', 'Premium', 'Unlock']) {
        expect(find.text(forbidden), findsNothing);
      }
    });
  });
}

// UX-03's text-scale clamp, and the date-picker crash it used to cause.
//
// Device-found on a Redmi Note 8: tapping any date field threw
// `'maxScale > minScale': is not true` from `_ClampedTextScaler`, and the
// screen was replaced by a red error box. The cause was app-wide, not local to
// one form:
//
//   app.dart clamped with `TextScaler.clamp(min: 1.0, max: 1.6)`, which
//   returns a scaler *carrying* those bounds. Material's `_DatePickerHeader`
//   then clamps again to `min(currentScale, 1.6)`. At the default system scale
//   of 1.0 that is `max(0, 1.0)` and `min(1.0, 1.6)` — a scaler whose min and
//   max are both 1.0, which the framework asserts against.
//
// So every date picker in the app — the record form, the vaccination next-due
// field, the reminder form — crashed on every device at the default font size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/app.dart';

double _factor(TextScaler s) => s.scale(14) / 14;

/// A stand-in for Android's `SystemTextScaler`.
///
/// `TextScaler.linear` is the wrong probe for this bug: `_LinearTextScaler`
/// overrides `clamp` to collapse into another linear scaler, so it can never
/// produce the `_ClampedTextScaler` that asserts. The platform's scaler does
/// not override it and inherits the base implementation — which is exactly
/// what the device hit. Extending `TextScaler` reproduces that.
class _SystemLikeScaler extends TextScaler {
  const _SystemLikeScaler(this.factor);

  final double factor;

  @override
  double scale(double fontSize) => fontSize * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => factor;
}

void main() {
  group('pawTextScaler', () {
    test('keeps the system scaler when it is already in range', () {
      const system = _SystemLikeScaler(1.0);
      expect(identical(pawTextScaler(system), system), isTrue,
          reason: 'a non-linear OS curve must survive untouched');
      expect(_factor(pawTextScaler(const _SystemLikeScaler(1.35))), 1.35);
    });

    test('floors a shrunk system font at 1.0', () {
      expect(_factor(pawTextScaler(const _SystemLikeScaler(0.8))), 1.0);
    });

    test('caps a huge one at 1.6', () {
      expect(_factor(pawTextScaler(const _SystemLikeScaler(3.0))), 1.6);
    });

    test('never returns a scaler that cannot be re-clamped', () {
      // This is the actual invariant: Material re-clamps whatever it is given
      // to `min(currentScale, 1.6)`, and a scaler already carrying a 1.0 floor
      // turns that into min == max.
      for (final factor in [0.5, 0.85, 1.0, 1.15, 1.6, 2.0, 3.0]) {
        final scaler = pawTextScaler(_SystemLikeScaler(factor));
        final current = scaler.scale(14) / 14;
        expect(
          () => scaler.clamp(maxScaleFactor: current < 1.6 ? current : 1.6),
          returnsNormally,
          reason: 'system scale ${factor}x produced an unclampable scaler',
        );
      }
    });
  });

  group('a date picker opens under the app clamp', () {
    Future<void> pumpAndOpen(WidgetTester tester, double systemScale) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: _SystemLikeScaler(systemScale)),
          child: Builder(builder: (context) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: pawTextScaler(mq.textScaler)),
              child: MaterialApp(
                home: Builder(
                  builder: (inner) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => showDatePicker(
                          context: inner,
                          initialDate: DateTime(2026, 8, 7),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        ),
                        child: const Text('pick'),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
    }

    for (final scale in [0.85, 1.0, 1.3, 2.0]) {
      testWidgets('at a system scale of ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(393 * 3, 851 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await pumpAndOpen(tester, scale);
        expect(tester.takeException(), isNull,
            reason: 'the date picker must open, not throw');
        expect(find.byType(DatePickerDialog), findsOneWidget);
      });
    }
  });
}

// The analysis wait is deliberate: the reference sets the expectation on
// screen ("30-45 seconds") and the loading run is the app showing its work, so
// a request that returns in two seconds must not snap past it.
//
// This file pins the two cases where it must NOT hold:
//
//   * an EMERGENCY cuts through instantly — delaying the red path behind a
//     progress bar is exactly the trade this codebase does not make;
//   * reduce-motion is a request not to be shown ceremony at all.
//
// …and the case where it must: a non-emergency result is held until the run
// reaches 100.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/analysis_runner.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/health_check/health_check_loading_view.dart';
import 'package:pawdoc/src/models/analysis_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake implements AnalysisService {
  _Fake(this.result, {this.delay = Duration.zero});

  final AnalysisResult result;
  final Duration delay;

  @override
  Future<AnalysisOutcome> analyze({
    required String petId,
    required String inputType,
    String? textDescription,
    String? imageStorageKey,
    List<String>? frameStorageKeys,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return AnalysisOutcome(result: result, analysisId: 'a1');
  }
}

AnalysisResult _mk(ActionLevel level) => AnalysisResult(
      action: level,
      confidence: 0.9,
      observation: 'Concern',
      visibleSymptoms: const [],
      vetsLookFor: const [],
      watchFor: const [],
      recommendedActions: const ['do this'],
      urgencyTimeframe: 'routine',
      recheckHours: null,
      disclaimerRequired: true,
    );

Widget _runner(AnalysisService service, {required bool motion}) => ProviderScope(
      overrides: [analysisServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
            child: const AnalysisRunnerScreen(
              petId: 'p1',
              petName: 'rex',
              petSpecies: 'dog',
              inputType: 'text',
              textDescription: 'tired',
            ),
          ),
        ),
      ),
    );

/// `flutter_test_config.dart` sets `FakeAccessibilityFeatures(disableAnimations:
/// true)` on the binding, and `AnimationController` scales every duration by
/// **0.05** when that is set — regardless of any MediaQuery override. So a
/// 33.5s run finishes in ~1.7s of test time. Pumps here are expressed against
/// that, not against the wall-clock constant.
const _scale = 0.05;
Duration _run(double fraction) => Duration(
    microseconds:
        (HealthCheckLoadingView.ceremony.inMicroseconds * _scale * fraction)
            .round());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('EMERGENCY is never held behind the loading run', (tester) async {
    await tester.pumpWidget(
        _runner(_Fake(_mk(ActionLevel.getHelpNow)), motion: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // No ceremony pumped at all: the red path is already on screen.
    expect(find.byType(HealthCheckLoadingView), findsNothing);
  });

  testWidgets('a non-emergency result waits for the run to finish',
      (tester) async {
    await tester.pumpWidget(
        _runner(_Fake(_mk(ActionLevel.watchAndRecheck)), motion: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The answer is in; the run is not.
    expect(find.byType(HealthCheckLoadingView), findsOneWidget);

    // Half way: still holding.
    await tester.pump(_run(0.5));
    expect(find.byType(HealthCheckLoadingView), findsOneWidget);

    // Past the end, plus the resolve beat.
    await tester.pump(_run(0.6));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HealthCheckLoadingView), findsNothing);

    // Drain the result screen's own timers so the harness does not report
    // them as leaked.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('reduce-motion is not held', (tester) async {
    await tester.pumpWidget(
        _runner(_Fake(_mk(ActionLevel.watchAndRecheck)), motion: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HealthCheckLoadingView), findsNothing);
  });

  testWidgets('the bar holds short of the finish while the network is out',
      (tester) async {
    // The service takes far longer than a full run — the `delay` is real test
    // time, unscaled, so it outlasts the bar by a wide margin.
    await tester.pumpWidget(_runner(
        _Fake(_mk(ActionLevel.watchAndRecheck),
            delay: HealthCheckLoadingView.ceremony),
        motion: true));
    await tester.pump();

    // Run past where the bar would otherwise complete.
    await tester.pump(_run(1.2));
    await tester.pump(const Duration(milliseconds: 100));

    // Still waiting — parked one point short, not sitting at a finished bar.
    expect(find.byType(HealthCheckLoadingView), findsOneWidget);
    expect(find.text('99%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);

    // …and saying so. The copy lives at the foot of a long list, so it has to
    // be scrolled into the viewport before it exists to be found.
    await tester.scrollUntilVisible(
      find.text('Finishing up…'),
      400,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 30,
    );
    expect(find.text('Finishing up…'), findsOneWidget);

    // The answer lands; the bar closes out and hands over.
    await tester.pump(HealthCheckLoadingView.ceremony);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HealthCheckLoadingView), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}

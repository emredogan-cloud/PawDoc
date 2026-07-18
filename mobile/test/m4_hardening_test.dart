// M4 hardening gates: the pulse→verdict resolve is non-emergency-only with
// the EMERGENCY instant cut preserved; the error nap loop degrades correctly;
// the reduce-motion audit sweeps the M4 surfaces.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/analysis_runner.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/analysis/loading_screen.dart';
import 'package:pawdoc/src/core/app_views.dart';
import 'package:pawdoc/src/models/analysis_result.dart';
import 'package:rive/rive.dart' show Rive;
import 'package:shared_preferences/shared_preferences.dart';

class _Fake implements AnalysisService {
  _Fake(this.result);
  final AnalysisResult result;
  @override
  Future<AnalysisOutcome> analyze(
          {required String petId,
          required String inputType,
          String? textDescription,
          String? imageStorageKey,
          List<String>? frameStorageKeys}) async =>
      AnalysisOutcome(result: result, analysisId: 'a1');
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

Widget _runner(AnalysisResult r, {required bool motion}) => ProviderScope(
      overrides: [analysisServiceProvider.overrideWithValue(_Fake(r))],
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
                textDescription: 'tired'),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'pawdoc.first_analysis_completed': true});
  });

  testWidgets('#23 MONITOR gets the resolve beat, then the result',
      (tester) async {
    await tester.pumpWidget(_runner(_mk(ActionLevel.callToday), motion: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-resolve: still the loading surface, result not yet revealed.
    expect(find.byType(AnalysisLoadingView), findsOneWidget);
    expect(find.text('CALL YOUR VET TODAY'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CALL YOUR VET TODAY'), findsOneWidget);
  });

  testWidgets('#23 EMERGENCY keeps the INSTANT cut — zero resolve delay',
      (tester) async {
    await tester.pumpWidget(_runner(_mk(ActionLevel.getHelpNow), motion: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // No resolving phase: the emergency screen is already up.
    expect(find.text('This may be an emergency'), findsOneWidget);
    expect(find.byType(AnalysisLoadingView), findsNothing);
  });

  testWidgets('reduce-motion: straight to the result (no resolve phase)',
      (tester) async {
    await tester.pumpWidget(_runner(_mk(ActionLevel.callToday), motion: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CALL YOUR VET TODAY'), findsOneWidget);
  });

  testWidgets('error nap view: zero Lottie under reduce-motion, retry intact',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppErrorView(message: 'Could not load.', onRetry: () {}),
      ),
    ));
    await tester.pump();

    expect(find.byType(Lottie), findsNothing); // global RM test config
    expect(find.text('Could not load.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
      'reduce-motion audit: loading view (incl. resolve + pulse-pet params) '
      'renders static-only', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AnalysisLoadingView(
            resolveColor: Colors.green, pulsePetSpecies: 'dog'),
      ),
    ));
    await tester.pump();

    expect(find.byType(Lottie), findsNothing);
    expect(find.byType(Rive), findsNothing);
    expect(find.byType(Animate), findsNothing,
        reason: 'reduce-motion loading view must be fully static');
  });
}

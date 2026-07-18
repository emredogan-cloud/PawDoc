import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/result_screen.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

AnalysisResult mk(ActionLevel level, {int? recheckHours}) => AnalysisResult(
      action: level,
      confidence: 0.8,
      observation: 'A raised, dark spot on the left flank.',
      visibleSymptoms: const ['a raised, dark spot'],
      vetsLookFor: const ['changes in size or colour over time'],
      watchFor: const ['bleeding or rapid growth'],
      recommendedActions: const ['keep the area clean'],
      urgencyTimeframe: 'within a few days',
      recheckHours: recheckHours,
      disclaimerRequired: true,
    );

Widget _wrap(AnalysisResult r) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ResultScreen(result: r),
      ),
    );

/// The v2 result screen is a long scroll; give tests a tall surface so every
/// ListView child builds (off-screen children otherwise never mount).
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the floor (WATCH_AND_RECHECK) never says "normal" and always shows the ladder + disclaimer',
      (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_wrap(mk(ActionLevel.watchAndRecheck, recheckHours: 24)));
    expect(find.text('WATCH AND RE-CHECK'), findsOneWidget);
    // The retired verdict must never render anywhere.
    expect(find.textContaining('NORMAL'), findsNothing);
    expect(find.textContaining('normal'), findsNothing);
    expect(find.byKey(const Key('result_share')), findsOneWidget);
    expect(find.textContaining('information, not a veterinary diagnosis'), findsOneWidget);
    // The invariant surface: watch-for signs + the hardcoded floor triggers.
    expect(find.text('Call sooner if you see'), findsOneWidget);
    expect(find.textContaining('You feel something is wrong'), findsOneWidget);
  });

  testWidgets('CALL_TODAY shows the action hero, find-a-vet CTA, and share', (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_wrap(mk(ActionLevel.callToday)));
    expect(find.text('CALL YOUR VET TODAY'), findsOneWidget);
    expect(find.byKey(const Key('result_find_vet')), findsOneWidget);
    expect(find.byKey(const Key('result_share')), findsOneWidget);
  });

  testWidgets('BOOK_VISIT shows the calm booking hero + find-a-vet', (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_wrap(mk(ActionLevel.bookVisit)));
    expect(find.text('BOOK A ROUTINE VISIT'), findsOneWidget);
    expect(find.byKey(const Key('result_find_vet')), findsOneWidget);
  });

  testWidgets('the re-check CTA renders only when a petId enables scheduling', (tester) async {
    _tallSurface(tester);
    // Without a petId there is nothing to attach the reminder to — CTA hidden.
    await tester.pumpWidget(_wrap(mk(ActionLevel.watchAndRecheck, recheckHours: 24)));
    expect(find.byKey(const Key('result_recheck')), findsNothing);
  });

  testWidgets('GET_HELP_NOW routes to the gated emergency screen', (tester) async {
    await tester.pumpWidget(_wrap(mk(ActionLevel.getHelpNow)));
    expect(find.text('This may be an emergency'), findsOneWidget);
    expect(find.byKey(const Key('emergency_find_vet')), findsOneWidget);

    // Continue is gated until the user acknowledges.
    FilledButton cont() =>
        tester.widget<FilledButton>(find.byKey(const Key('emergency_continue')));
    expect(cont().onPressed, isNull);
    await tester.tap(find.byKey(const Key('emergency_ack_checkbox')));
    await tester.pump();
    expect(cont().onPressed, isNotNull);
  });
}

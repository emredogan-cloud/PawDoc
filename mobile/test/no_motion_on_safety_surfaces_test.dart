// HARD GUARDRAIL (roadmap §5.1, permanent): the EMERGENCY screen and the
// Delete flow receive ZERO motion additions — no Lottie, no AppMotionAsset,
// ever. If a refactor ever routes one in, this fails the build.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/account/delete_account_screen.dart';
import 'package:pawdoc/src/analysis/emergency_result_screen.dart';
import 'package:pawdoc/src/core/app_motion_asset.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

AnalysisResult _emergency() => const AnalysisResult(
      triageLevel: TriageLevel.emergency,
      confidence: 1.0,
      primaryConcern: "Emergency indicator detected: 'not breathing'.",
      visibleSymptoms: [],
      differential: [],
      recommendedActions: ['Contact an emergency veterinarian now.'],
      urgencyTimeframe: 'immediately',
      disclaimerRequired: true,
    );

void main() {
  testWidgets('EMERGENCY screen renders zero motion widgets', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmergencyResultScreen(result: _emergency()),
      ),
    ));
    await tester.pump();

    expect(find.byType(Lottie), findsNothing);
    expect(find.byType(AppMotionAsset), findsNothing);
  });

  testWidgets('Delete-account screen renders zero motion widgets', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: DeleteAccountScreen()),
    ));
    await tester.pump();

    expect(find.byType(Lottie), findsNothing);
    expect(find.byType(AppMotionAsset), findsNothing);
  });
}

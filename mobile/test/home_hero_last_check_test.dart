// M0 fix F-2 — the home hero shows "Last check: just now" right after a
// completed analysis (and "No checks yet" only when there are truly none).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/core/connectivity.dart';
import 'package:pawdoc/src/home/home_screen.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pet = Pet(id: 'p1', userId: 'u', name: 'biscuit', species: 'dog', breed: 'Golden');

Widget _home({LatestTriage? latest}) => ProviderScope(
      overrides: [
        petsListProvider.overrideWith((ref) async => const [_pet]),
        userProfileProvider.overrideWith((ref) async => const UserProfile(
            subscriptionStatus: 'free', photoLogsUsedThisMonth: 1)),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        latestTriageProvider.overrideWith((ref, petId) => latest),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hero shows "Last check: just now" for a fresh check', (tester) async {
    await tester.pumpWidget(
        _home(latest: LatestTriage(level: 'CALL_TODAY', checkedAt: DateTime.now())));
    await tester.pumpAndSettle();

    expect(find.text('Last check: just now'), findsOneWidget);
    expect(find.text('No checks yet'), findsNothing);
  });

  testWidgets('hero shows "No checks yet" when the pet has no analyses', (tester) async {
    await tester.pumpWidget(_home(latest: null));
    await tester.pumpAndSettle();

    expect(find.text('No checks yet'), findsOneWidget);
  });

  testWidgets('hero falls back to the level when created_at is unparsable', (tester) async {
    await tester.pumpWidget(
        _home(latest: const LatestTriage(level: 'CALL_TODAY', checkedAt: null)));
    await tester.pumpAndSettle();

    expect(find.text('Last check: CALL_TODAY'), findsOneWidget);
  });
}

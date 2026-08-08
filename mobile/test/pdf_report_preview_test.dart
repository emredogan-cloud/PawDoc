// Mockup `pdf_health_report_preview`.
//
// The PDF is composed in memory on the server and streamed straight to the
// share sheet, so the app has no bytes to render. The preview re-derives the
// same document in Dart — which means it can drift from the shaper that
// actually builds the file, and a preview that differs from what is sent is
// worse than none. The `parity` group reads
// `supabase/functions/_shared/pdf_report.mjs` and fails when it does.
//
// The reference draws a much richer document than PawDoc produces: an Owner
// Information panel with the owner's name, phone number, email address and
// city; "7 Vaccinations · Up to date"; "2 Lab Results · Normal"; visits at
// named clinics under named veterinarians; "All vaccinations are up to date";
// "Food Allergy · Severity: Moderate"; and a QR code captioned "Scan to
// verify". None of it is in the file, and the `safety` group keeps it out.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/health/health_event.dart';
import 'package:pawdoc/src/health/health_events_repository.dart';
import 'package:pawdoc/src/health/health_report_preview_screen.dart';
import 'package:pawdoc/src/health/report_preview.dart';
import 'package:pawdoc/src/monetization/premium_sections.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  sex: 'male',
  weightKg: 28.2,
);

void _surface(WidgetTester tester, {double height = 4200}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  List<HealthEvent>? events,
  List<Map<String, dynamic>>? checks,
  bool premium = false,
  bool checksFail = false,
  List<Pet> pets = const [_pet],
}) =>
    ProviderScope(
      overrides: [
        petsListProvider.overrideWith((ref) async => pets),
        healthEventsRepositoryProvider
            .overrideWithValue(_FakeEvents(events ?? const [])),
        if (checksFail)
          reportChecksProvider.overrideWith((ref, petId) =>
              Future<List<Map<String, dynamic>>>.error(Exception('offline')))
        else
          reportChecksProvider
              .overrideWith((ref, petId) async => checks ?? const []),
        userProfileProvider.overrideWith((ref) async => UserProfile(
              subscriptionStatus: premium ? 'premium' : 'free',
              photoLogsUsedThisMonth: 1,
            )),
      ],
      child: const MaterialApp(home: HealthReportPreviewScreen(pet: _pet)),
    );

class _FakeEvents implements HealthEventsRepository {
  _FakeEvents(this._events);

  final List<HealthEvent> _events;

  @override
  Future<List<HealthEvent>> listForPet(String petId) async => _events;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _pageText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .toLowerCase();

/// The page and its chrome, minus the card that *names* the omissions.
///
/// `PremiumHonestyNote` here says "your name, phone number, email address or
/// where you live" and "any severity, risk level, score or condition name" —
/// scanning it for those words would forbid the disclaimer that exists to
/// promise them absent. So the ban list runs over everything else, and the
/// note gets its own assertion.
String _documentText(WidgetTester tester) {
  final excluded = <Element>{};
  void mark(Element e) {
    excluded.add(e);
    e.visitChildren(mark);
  }

  find.byType(PremiumHonestyNote).evaluate().forEach(mark);
  return find
      .byType(Text)
      .evaluate()
      .where((e) => !excluded.contains(e))
      .map((e) => (e.widget as Text).data ??
          (e.widget as Text).textSpan?.toPlainText() ??
          '')
      .join(' ')
      .toLowerCase();
}

void main() {
  group('parity with the shaper that actually builds the file', () {
    final mjs = File('../supabase/functions/_shared/pdf_report.mjs');

    test('the shared shaper exists in the repo tree', () {
      expect(mjs.existsSync(), isTrue);
    });

    test('the section headings match, word for word', () {
      final src = mjs.readAsStringSync();
      for (final heading in [
        kPdfProfileHeading,
        kPdfAnalysesHeading,
        kPdfEventsHeading,
      ]) {
        expect(src.contains('"$heading"'), isTrue,
            reason: 'the preview prints "$heading"; the PDF does not');
      }
    });

    test('the disclaimer matches, word for word', () {
      final src = mjs.readAsStringSync();
      // The .mjs concatenates two string literals; compare on the words.
      final normalised = src.replaceAll(RegExp(r'"\s*\+\s*\n?\s*"'), '');
      expect(normalised.contains(kPdfReportDisclaimer), isTrue,
          reason: 'the preview promises a different disclaimer than the file');
    });

    test('the row caps match MAX_RECENT_*', () {
      final src = mjs.readAsStringSync();
      for (final name in ['MAX_RECENT_ANALYSES', 'MAX_RECENT_EVENTS']) {
        final m = RegExp('const $name = (\\d+)').firstMatch(src);
        expect(m, isNotNull, reason: name);
        expect(int.parse(m!.group(1)!), kPdfMaxRows, reason: name);
      }
    });

    test('the window matches the Edge Function\'s 30 days', () {
      final index = File('../supabase/functions/generate-pdf-report/index.ts');
      expect(index.existsSync(), isTrue);
      expect(index.readAsStringSync().contains('30 * 24 * 3600 * 1000'), isTrue,
          reason: 'the preview says "last 30 days"');
      expect(kPdfReportWindow, const Duration(days: 30));
    });

    test('the profile lines are the ones the shaper builds', () {
      // species / breed / age / sex / weight, and nothing else.
      final preview = buildReportPreview(
          pet: _pet, analyses: const [], events: const []);
      final profile = preview.sections
          .firstWhere((s) => s.heading == kPdfProfileHeading)
          .lines
          .join(' ');
      expect(profile, contains('Species: dog'));
      expect(profile, contains('Breed: Golden Retriever'));
      expect(profile, contains('Sex: male'));
      expect(profile, contains('Weight: 28.2 kg'));
    });
  });

  group('the preview shows what the file will contain', () {
    test('an empty record still produces the three sections', () {
      final p = buildReportPreview(
          pet: _pet, analyses: const [], events: const []);
      expect(p.sections.map((s) => s.heading),
          [kPdfProfileHeading, kPdfAnalysesHeading, kPdfEventsHeading]);
      expect(p.sections[1].lines.single, '(no recent analyses)');
      expect(p.sections[2].lines.single, '(no recent health events)');
    });

    test('rows older than the window are excluded, exactly as the PDF does',
        () {
      final now = DateTime(2026, 8, 8);
      final p = buildReportPreview(
        pet: _pet,
        now: now,
        analyses: [
          {
            'action': 'WATCH_AND_RECHECK',
            'observation': 'a raised spot on the flank',
            'created_at': '2026-08-01T09:00:00Z',
          },
          {
            'action': 'BOOK_VISIT',
            'observation': 'old, out of window',
            'created_at': '2026-05-01T09:00:00Z',
          },
        ],
        events: [
          HealthEvent(
              petId: 'p1',
              eventType: 'vaccination',
              eventDate: DateTime(2026, 8, 2)),
          HealthEvent(
              petId: 'p1',
              eventType: 'weight',
              eventDate: DateTime(2026, 4, 2)),
        ],
      );
      final analyses = p.sections[1].lines;
      expect(analyses, hasLength(1));
      expect(analyses.single, contains('a raised spot on the flank'));
      expect(p.sections[2].lines, hasLength(1));
      expect(p.sections[2].lines.single, contains('vaccination'));
    });

    test('no more than the shaper\'s cap of rows', () {
      final p = buildReportPreview(
        pet: _pet,
        now: DateTime(2026, 8, 8),
        analyses: [
          for (var i = 0; i < 20; i++)
            {
              'action': 'BOOK_VISIT',
              'observation': 'row $i',
              'created_at': '2026-08-0${(i % 8) + 1}T09:00:00Z',
            },
        ],
        events: const [],
      );
      expect(p.sections[1].lines, hasLength(kPdfMaxRows));
    });

    test('a short report is one page, not twelve', () {
      final p = buildReportPreview(
          pet: _pet, analyses: const [], events: const []);
      expect(paginateReport(p), hasLength(1));
    });

    test('a long report paginates rather than clipping', () {
      final p = buildReportPreview(
        pet: _pet,
        now: DateTime(2026, 8, 8),
        analyses: [
          for (var i = 0; i < kPdfMaxRows; i++)
            {
              'action': 'BOOK_VISIT',
              'observation': 'row $i',
              'created_at': '2026-08-0${(i % 8) + 1}T09:00:00Z',
            },
        ],
        events: [
          for (var i = 0; i < kPdfMaxRows; i++)
            HealthEvent(
                petId: 'p1',
                eventType: 'custom',
                eventDate: DateTime(2026, 8, 1),
                notes: 'note $i'),
        ],
      );
      final pages = paginateReport(p);
      expect(pages.length, greaterThanOrEqualTo(1));
      // No section is lost between pages.
      expect(pages.expand((page) => page).length, p.sections.length);
    });
  });

  group('the screen', () {
    testWidgets('draws the reference\'s chrome over a real page',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Health Report'), findsOneWidget);
      expect(find.byKey(const Key('report_kind_picker')), findsOneWidget);
      expect(find.byKey(const Key('report_toolbar')), findsOneWidget);
      expect(find.byKey(const Key('report_page')), findsOneWidget);
      expect(find.byKey(const Key('report_export')), findsOneWidget);
      expect(find.byKey(const Key('report_share_text')), findsOneWidget);
      expect(find.byKey(const Key('report_window_note')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
      // The page count is the real one.
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('the page carries the disclaimer', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_disclaimer')), findsOneWidget);
      expect(_pageText(tester), contains('not a veterinary diagnosis'));
    });

    testWidgets('zoom changes the readout and clamps at both ends',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report_zoom_in')));
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('report_zoom_out')));
        await tester.pumpAndSettle();
      }
      expect(find.text('75%'), findsOneWidget, reason: 'clamped, not negative');
    });

    testWidgets('page navigation is disabled on a single-page report',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // Both arrows exist (the reference draws them) and neither is live.
      expect(find.byKey(const Key('report_prev_page')), findsOneWidget);
      expect(find.byKey(const Key('report_next_page')), findsOneWidget);
      expect(
          tester
              .widget<InkWell>(find.byKey(const Key('report_next_page')))
              .onTap,
          isNull);
      expect(
          tester
              .widget<InkWell>(find.byKey(const Key('report_prev_page')))
              .onTap,
          isNull);
    });

    testWidgets('the export button is locked for a free account',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Export PDF · Premium'), findsOneWidget);
      // The preview itself is not gated — the whole page is visible.
      expect(find.byKey(const Key('report_page')), findsOneWidget);
      expect(find.byKey(const Key('report_premium_band')), findsOneWidget);
    });

    testWidgets('a subscriber gets the plain export and no upsell',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(premium: true));
      await tester.pumpAndSettle();
      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.byKey(const Key('report_premium_band')), findsNothing);
    });

    testWidgets('the report-type picker offers only real outputs',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('report_kind_picker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_kind_pdf')), findsOneWidget);
      expect(find.byKey(const Key('report_kind_text')), findsOneWidget);
      expect(find.byKey(const Key('report_kind_prep')), findsOneWidget);

      await tester.tap(find.byKey(const Key('report_kind_text')));
      await tester.pumpAndSettle();
      // A text output has no paper and no toolbar.
      expect(find.byKey(const Key('report_page')), findsNothing);
      expect(find.byKey(const Key('report_toolbar')), findsNothing);
      expect(find.byKey(const Key('report_text_card')), findsOneWidget);
      expect(find.text('Share the summary'), findsOneWidget);
    });

    testWidgets('the page renders the record, not a fixture', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(events: [
        HealthEvent(
            petId: 'p1',
            eventType: 'vet_visit',
            eventDate: DateTime.now().subtract(const Duration(days: 3)),
            notes: 'annual check'),
      ]));
      await tester.pumpAndSettle();
      expect(_pageText(tester), contains('vet_visit — annual check'));
      expect(_pageText(tester), contains('species: dog'));
    });

    testWidgets('with no pets it says so instead of drawing a blank page',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          petsListProvider.overrideWith((ref) async => const <Pet>[]),
          healthEventsRepositoryProvider
              .overrideWithValue(_FakeEvents(const [])),
          reportChecksProvider.overrideWith((ref, petId) async => const []),
          userProfileProvider.overrideWith((ref) async =>
              const UserProfile(
                  subscriptionStatus: 'free', photoLogsUsedThisMonth: 0)),
        ],
        // No `pet:` — the empty-state path.
        child: const MaterialApp(home: HealthReportPreviewScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No pet on this account yet'), findsOneWidget);
    });
  });

  group('safety and privacy: what the reference draws and the file omits', () {
    testWidgets('no owner contact details appear anywhere', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final text = _documentText(tester);
      for (final banned in [
        'owner information',
        'john doe',
        '@email',
        'phone number',
        'istanbul',
      ]) {
        expect(text.contains(banned), isFalse, reason: banned);
      }
      // And the note says the omission is deliberate.
      expect(_pageText(tester), contains('carries the animal, not you'));
    });

    testWidgets('no all-clear, no severity, no named condition, no clinician',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(events: [
        HealthEvent(
            petId: 'p1',
            eventType: 'lab_result',
            eventDate: DateTime.now().subtract(const Duration(days: 2))),
      ]));
      await tester.pumpAndSettle();
      final text = _documentText(tester);
      for (final banned in [
        'up to date',
        'fully protected',
        'severity',
        'dr.',
        'veterinary clinic',
        'scan to verify',
        'allerg',
        'professional health report',
      ]) {
        expect(text.contains(banned), isFalse, reason: banned);
      }
      // "Normal" as a lab verdict, specifically.
      expect(RegExp(r'lab results?\s*(·|:)?\s*normal').hasMatch(text), isFalse);
    });

    test('the "includes" list never promises more than the file holds', () {
      final joined = (kReportIncludes + kReportExcludes).join(' ').toLowerCase();
      for (final banned in [
        'lab result',
        'allerg',
        'microchip',
        'clinic',
        'verify',
        'professional',
      ]) {
        expect(joined.contains(banned), isFalse, reason: banned);
      }
      expect(kReportExcludes.join(' '), contains('phone number'));
    });
  });
}

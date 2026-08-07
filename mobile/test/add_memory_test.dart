// Mockup `add_memory`.
//
// The reference draws a four-stop wizard over six numbered cards. Four of the
// things it draws have no column behind them, and each keeps its control, in
// its place, marked *Soon* rather than being deleted or faked:
//
//  * **Video** — no upload path, no thumbnail, no duration.
//  * **A time of day** — `taken_on` is a date column.
//  * **Tags** — no column, and folding them into the note would put filing
//    labels into the body of the owner's own writing.
//  * **Family / Public** — every row is RLS-scoped to the account that wrote
//    it. "Private" here is a description of the table, not a preference, and
//    the tile says exactly that.
//
// The reference's "up to 10 photos" *is* honoured: one entry is written per
// photograph, sharing the pet, date, title and note, and the review step says
// so before anything is written.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/memories/add_memory_screen.dart';
import 'package:pawdoc/src/memories/media_url_cache.dart';
import 'package:pawdoc/src/memories/memories_repository.dart';
import 'package:pawdoc/src/memories/memory.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';

const _buddy = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
);

const _milo = Pet(id: 'p2', userId: 'u1', name: 'Milo', species: 'cat');

/// A handset surface, tall enough that everything below the 800x600 default
/// fold is actually built — otherwise the assertions pass vacuously.
void _surface(WidgetTester tester, {double height = 2200}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  int memoryCount = 3,
  bool premium = false,
  List<Pet> pets = const [_buddy, _milo],
}) {
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => pets),
      memoriesCountProvider.overrideWith((ref) async => memoryCount),
      userProfileProvider.overrideWith((ref) async => UserProfile(
            subscriptionStatus: premium ? 'premium' : 'free',
            photoLogsUsedThisMonth: 0,
          )),
      mediaUrlServiceProvider.overrideWithValue(
        MediaUrlService(signer: (keys) async => (const <String, String>{}, 0)),
      ),
    ],
    child: const MaterialApp(home: AddMemoryScreen(pet: _buddy)),
  );
}

/// Walks the wizard to [step] the way an owner would — through the rail.
Future<void> _goto(WidgetTester tester, MemoryStep step) async {
  await tester.tap(find.text(step.label));
  await tester.pumpAndSettle();
}

void main() {
  group('the allowance is per entry, not per memory', () {
    test('premium is bounded only by the reference ceiling', () {
      expect(
        allowedPhotoCount(wanted: 4, currentCount: 900, isPremium: true),
        4,
      );
      expect(
        allowedPhotoCount(wanted: 40, currentCount: 0, isPremium: true),
        AddMemoryScreen.maxPhotos,
      );
    });

    test('a free book takes as many as it has room for, not all or nothing',
        () {
      // Two slots left, five wanted: take two.
      expect(
        allowedPhotoCount(
            wanted: 5, currentCount: kFreeMemoryLimit - 2, isPremium: false),
        2,
      );
    });

    test('a full free book takes none, and never a negative', () {
      expect(
        allowedPhotoCount(
            wanted: 3, currentCount: kFreeMemoryLimit, isPremium: false),
        0,
      );
      expect(
        allowedPhotoCount(
            wanted: 3, currentCount: kFreeMemoryLimit + 9, isPremium: false),
        0,
      );
    });
  });

  group('the mockup, drawn', () {
    testWidgets('opens on Media with the four-stop rail', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_memory_steps')), findsOneWidget);
      for (final step in MemoryStep.values) {
        expect(find.text(step.label), findsOneWidget);
      }
      // Card 1 and card 2, with the reference's numbering and its sub-lines.
      expect(find.text('Add Photos'), findsOneWidget);
      expect(find.text('Share a special moment with your pet'), findsOneWidget);
      expect(find.text('Choose Pet'), findsOneWidget);
      expect(find.text('Who is this memory about?'), findsOneWidget);
      expect(find.byKey(const Key('add_memory_add_tile')), findsOneWidget);
      expect(find.textContaining('up to ${AddMemoryScreen.maxPhotos} photos'),
          findsOneWidget);
      expect(find.byKey(const Key('add_memory_next')), findsOneWidget);
    });

    testWidgets('every pet is offered, plus the New Pet slot', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_memory_pet_p1')), findsOneWidget);
      expect(find.byKey(const Key('add_memory_pet_p2')), findsOneWidget);
      expect(find.byKey(const Key('add_memory_new_pet')), findsOneWidget);
      // The pet the journal was showing starts selected.
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('Golden Retriever'), findsOneWidget);
    });

    testWidgets('Details draws cards 3 to 6', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _goto(tester, MemoryStep.details);

      expect(find.text('When did it happen?'), findsOneWidget);
      expect(find.text('Add a Title'), findsOneWidget);
      expect(find.text('(Optional)'), findsOneWidget);
      expect(find.text('Write a Note'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.byKey(const Key('memory_title_field')), findsOneWidget);
      expect(find.byKey(const Key('memory_note_field')), findsOneWidget);
      expect(find.byKey(const Key('add_memory_date')), findsOneWidget);
      // The reference's own button copy, on the step that precedes the tags.
      expect(find.text('Next: Add Tags'), findsOneWidget);
    });

    testWidgets('the counters count', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _goto(tester, MemoryStep.details);

      expect(find.text('0/60'), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('memory_title_field')), 'Beach day');
      await tester.pumpAndSettle();
      expect(find.text('9/60'), findsOneWidget);
    });

    testWidgets('Tags and Review are drawn in full', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _goto(tester, MemoryStep.tags);
      expect(find.text('Add Tags'), findsOneWidget);
      expect(find.text('First time'), findsOneWidget);
      expect(find.byKey(const Key('add_memory_custom_tag')), findsOneWidget);

      await _goto(tester, MemoryStep.review);
      // Twice: the rail's stop, and the card's own head.
      expect(find.text('Review'), findsNWidgets(2));
      expect(find.text('Pet'), findsOneWidget);
      expect(find.text('Happened on'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Visible to'), findsOneWidget);
    });

    testWidgets('with no photo the wizard still walks, and says what is missing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _goto(tester, MemoryStep.review);

      // The rail is not a trap: it moved. The footer explains the block, and
      // the header Save is greyed rather than silently doing nothing.
      expect(find.byKey(const Key('add_memory_hint')), findsOneWidget);
      expect(
          find.textContaining('Add at least one photo'), findsWidgets);
    });
  });

  group('Soon, never faked', () {
    testWidgets('the time field keeps its place and says Soon', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _goto(tester, MemoryStep.details);

      expect(find.byKey(const Key('add_memory_time')), findsOneWidget);
      expect(find.text('Time · Soon'), findsOneWidget);
    });

    testWidgets('Family and Public are drawn, disabled and captioned',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _goto(tester, MemoryStep.details);

      expect(find.byKey(const Key('add_memory_audience_private')),
          findsOneWidget);
      expect(
          find.byKey(const Key('add_memory_audience_family')), findsOneWidget);
      expect(
          find.byKey(const Key('add_memory_audience_public')), findsOneWidget);
      // Only Private carries a real description; the other two say Soon.
      expect(find.text('Only you'), findsOneWidget);
      expect(find.text('Soon'), findsNWidgets(2));
      expect(find.text('Family members'), findsNothing);
      expect(find.text('Share with community'), findsNothing);
    });

    testWidgets('tapping Public explains rather than pretending',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _goto(tester, MemoryStep.details);

      await tester.tap(find.byKey(const Key('add_memory_audience_public')));
      await tester.pump();
      expect(find.textContaining('private to your account today'),
          findsOneWidget);
    });

    testWidgets('the tag picker never accepts a tag it cannot keep',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _goto(tester, MemoryStep.tags);

      await tester.tap(find.text('Playtime'));
      await tester.pump();
      expect(find.textContaining('Tags are coming'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('the journal makes no claim about the animal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final step in MemoryStep.values) {
        await _goto(tester, step);
        for (final banned in const [
          'Health Score',
          'Excellent',
          'Healthy',
          'Normal',
          'AI Highlight',
          'Low Risk',
          'Diagnosis',
        ]) {
          expect(find.textContaining(banned), findsNothing,
              reason: '"$banned" on ${step.label}');
        }
      }
    });

    testWidgets('the privacy copy states the rule, not a promise',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // EXIF/GPS stripping is a standing rule, and the page says where it
      // happens: on the device, before the upload.
      expect(find.textContaining('Location and camera data are removed on this'),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('add_memory_media_info')));
      await tester.pumpAndSettle();
      expect(find.textContaining('stripped on this device'), findsOneWidget);
      expect(find.textContaining('scoped to your account'), findsOneWidget);
    });
  });
}

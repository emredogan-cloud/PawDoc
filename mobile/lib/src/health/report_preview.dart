import '../pets/pet.dart';
import 'health_event.dart';

/// A Dart mirror of the PDF's content shaper, so the preview can show the
/// **actual** report instead of a picture of one.
///
/// The report is built server-side by `supabase/functions/_shared/pdf_report.mjs`
/// and rendered by `generate-pdf-report`. That is deliberate: the PDF is
/// composed in memory, streamed to the client and never stored. It also means
/// the app has no bytes to preview until the user pays for and generates one.
///
/// So this file re-derives the same sections from the same inputs, and
/// `pdf_report_parity_test.dart` reads the `.mjs` and fails if the two drift —
/// the pattern the emergency keyword lists already use across `safety.py`,
/// `emergency_keywords.mjs` and `emergency_keywords.dart`.
///
/// ## What the reference draws that the real report does not contain
///
/// `pdf_health_report_preview` renders a rich clinical document: an **Owner
/// Information** panel with the owner's name, phone number, email address and
/// city; a **Health Summary** counting "7 Vaccinations · Up to date", "2 Lab
/// Results · Normal", "1 Allergy"; **Recent Visits** at named clinics under
/// named veterinarians ("PawCare Veterinary Clinic · Dr. Emily Carter"); a
/// **Vaccination Status** block closing on "All vaccinations are up to date";
/// **Active Medications** with named drugs and doses; an **Allergies** block
/// grading "Food Allergy · Severity: Moderate"; and a QR code captioned "Scan
/// to verify this report".
///
/// None of it is in the PDF, and most of it could not be:
///
/// * **The owner's contact details are deliberately absent.** The report
///   carries the animal, not the person. A health record that travels by share
///   sheet with a phone number and a home city on it is a privacy problem the
///   moment it is forwarded, and nothing about it helps a vet.
/// * **"All vaccinations are up to date"** is the exact claim
///   `vaccination_manager` refuses to make: the app knows which records an
///   owner typed in, not whether an animal is immune.
/// * **"Lab Results · Normal"** renders an all-clear verdict; **"Allergy ·
///   Severity: Moderate"** grades a severity beside a named condition.
/// * **Named clinics and veterinarians** are people who did not write this.
/// * **"Scan to verify"** implies a verification service. There is none.
///
/// What the report does carry is the pet profile, the last 30 days of AI
/// checks, the last 30 days of owner-logged events, and the disclaimer.

/// One block of the report.
class ReportSection {
  const ReportSection({required this.heading, required this.lines});

  final String heading;
  final List<String> lines;
}

/// The whole document, in render order.
class ReportPreview {
  const ReportPreview({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.disclaimer,
  });

  final String title;
  final String subtitle;
  final List<ReportSection> sections;
  final String disclaimer;

  /// Every printable line, for the page estimate.
  int get lineCount =>
      2 + sections.fold<int>(0, (n, s) => n + 1 + s.lines.length) + 1;
}

/// The disclaimer the PDF closes on. Mirrors `DISCLAIMER` in `pdf_report.mjs`.
const String kPdfReportDisclaimer =
    'PawDoc provides information, not a veterinary diagnosis. '
    'In an emergency, contact a veterinarian immediately.';

/// Section headings, mirroring `buildReportSections`.
const String kPdfProfileHeading = 'Pet profile';
const String kPdfAnalysesHeading = 'Recent analyses (last 30 days)';
const String kPdfEventsHeading = 'Recent health events (last 30 days)';

/// The report's own window. Mirrors the Edge Function's `since` computation.
const Duration kPdfReportWindow = Duration(days: 30);

/// Caps, mirroring `MAX_RECENT_ANALYSES` / `MAX_RECENT_EVENTS`.
const int kPdfMaxRows = 10;

/// Build the preview from the same rows the Edge Function reads.
///
/// [analyses] carry `action`, `observation` and `created_at`; [events] are the
/// pet's health events. Both are filtered to the report's 30-day window here
/// so the preview cannot show a row the PDF would leave out.
ReportPreview buildReportPreview({
  required Pet pet,
  required List<Map<String, dynamic>> analyses,
  required List<HealthEvent> events,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final since = today.subtract(kPdfReportWindow);
  return ReportPreview(
    title: 'PawDoc Health Report',
    subtitle: '${pet.name} • generated ${_iso(today)}',
    sections: [
      ReportSection(heading: kPdfProfileHeading, lines: _profileLines(pet, today)),
      ReportSection(
        heading: kPdfAnalysesHeading,
        lines: _analysesLines(analyses, since),
      ),
      ReportSection(
        heading: kPdfEventsHeading,
        lines: _eventsLines(events, since),
      ),
    ],
    disclaimer: kPdfReportDisclaimer,
  );
}

List<String> _profileLines(Pet pet, DateTime today) {
  final lines = <String>['Species: ${pet.species}'];
  if (pet.breed != null && pet.breed!.trim().isNotEmpty) {
    lines.add('Breed: ${pet.breed}');
  }
  final years = _ageYears(pet.birthDate, today);
  if (years != null) lines.add('Age: $years years');
  if (pet.sex != null && pet.sex!.trim().isNotEmpty) lines.add('Sex: ${pet.sex}');
  if (pet.weightKg != null) lines.add('Weight: ${pet.weightKg} kg');
  return lines;
}

List<String> _analysesLines(
    List<Map<String, dynamic>> analyses, DateTime since) {
  final rows = analyses.where((a) {
    final at = DateTime.tryParse((a['created_at'] as String?) ?? '');
    return at == null || !at.isBefore(since);
  }).take(kPdfMaxRows);
  if (rows.isEmpty) return const ['(no recent analyses)'];
  return [
    for (final a in rows)
      '[${_isoOrEarlier(a['created_at'] as String?)}] '
          '${((a['action'] as String?) ?? '').toUpperCase().isEmpty ? '—' : ((a['action'] as String?) ?? '').toUpperCase()} '
          '— ${(a['observation'] as String?)?.isNotEmpty == true ? a['observation'] : '(no concern recorded)'}',
  ];
}

List<String> _eventsLines(List<HealthEvent> events, DateTime since) {
  final rows =
      events.where((e) => !e.eventDate.isBefore(since)).take(kPdfMaxRows);
  if (rows.isEmpty) return const ['(no recent health events)'];
  return [
    for (final e in rows)
      '[${_iso(e.eventDate)}] ${e.eventType}'
          '${e.notes?.trim().isNotEmpty == true ? ' — ${e.notes!.trim()}' : ''}',
  ];
}

/// Age in whole-and-tenth years, as the shaper rounds it.
double? _ageYears(DateTime? birth, DateTime asOf) {
  if (birth == null) return null;
  final days = asOf.difference(birth).inDays;
  if (days < 0) return null;
  return (days / 365.25 * 10).round() / 10;
}

String _iso(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _isoOrEarlier(String? iso) {
  if (iso == null || iso.length < 10) return 'earlier';
  return iso.substring(0, 10);
}

String _two(int v) => v.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

/// How many lines the renderer fits on one US-Letter page.
///
/// `generate-pdf-report` draws at 11pt on a 612×792 page with a 48pt margin,
/// advancing 16pt a line and breaking when `y < margin + lineHeight`. That is
/// `(792 - 48 - 48 - 16) / 16` usable rows. Headings and the title advance
/// further, so this is an **upper bound** and the estimate is conservative
/// about how much fits — a preview that promised fewer pages than the export
/// produced would be the wrong way round.
const int kPdfLinesPerPage = 42;

/// Split the preview into pages of at most [kPdfLinesPerPage] printable lines.
///
/// The reference's toolbar reads **"1 / 12"** for a report of six sections.
/// This returns what the content actually comes to — for most pets, one page.
List<List<ReportSection>> paginateReport(ReportPreview preview) {
  final pages = <List<ReportSection>>[];
  var current = <ReportSection>[];
  // The title and subtitle sit on page one and cost roughly three lines.
  var used = 3;
  for (final section in preview.sections) {
    final cost = 1 + section.lines.length;
    if (current.isNotEmpty && used + cost > kPdfLinesPerPage) {
      pages.add(current);
      current = <ReportSection>[];
      used = 0;
    }
    current.add(section);
    used += cost;
  }
  if (current.isNotEmpty) pages.add(current);
  return pages.isEmpty ? [const <ReportSection>[]] : pages;
}

// ---------------------------------------------------------------------------
// What the report includes
// ---------------------------------------------------------------------------

/// The reference's "Report Includes" checklist, rewritten to the truth — and
/// with the second half the reference never draws: what it leaves out.
const List<String> kReportIncludes = [
  'Your pet’s name, species, breed, age, sex and weight',
  'AI checks from the last 30 days — the action and what was observed',
  'Health events from the last 30 days — visits, medications, vaccinations, '
      'weights and notes',
  'The disclaimer, on every copy',
];

/// Deliberate omissions, stated on the screen because a vet and an owner both
/// benefit from knowing what is *not* in the file they are about to send.
const List<String> kReportExcludes = [
  'Your name, phone number, email address or location — the report carries '
      'the animal, not you',
  'Any judgement about whether vaccinations are complete or an animal is '
      'protected',
  'Any severity grade, risk level or condition name',
  'Anything older than 30 days — the full history stays in the app',
];

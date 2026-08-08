import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../account/user_profile.dart';
import '../analytics/analytics.dart';
import '../auth/supabase_providers.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../export/health_report_service.dart';
import '../home/home_sections.dart';
import '../monetization/premium_home_screen.dart';
import '../monetization/premium_sections.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../pets/pet_switcher.dart';
import '../prep/vet_visit_prep_screen.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'health_event.dart';
import 'health_events_repository.dart';
import 'health_sections.dart';
import 'history_timeline_screen.dart';
import 'pdf_report_service.dart';
import 'report_preview.dart';

/// `pdf_health_report_preview`, rebuilt against its reference.
///
/// The PDF itself is generated on the server and never stored — it is composed
/// in memory by `generate-pdf-report` and streamed straight to the share
/// sheet — so there is no file to render here. What the preview shows instead
/// is the same document rebuilt from the same rows by [buildReportPreview],
/// with a parity test pinning it to the shaper.
///
/// **The reference draws a document PawDoc does not produce.** It sets an
/// Owner Information panel carrying the owner's name, phone number, email
/// address and city; a Health Summary reading "7 Vaccinations · Up to date"
/// and "2 Lab Results · Normal"; visits at named clinics under named
/// veterinarians; "All vaccinations are up to date"; an allergy graded
/// "Severity: Moderate"; and a QR code captioned "Scan to verify". The
/// reasoning for each removal is in [report_preview.dart]; the short version
/// is that the report carries the animal, not the owner, and it never grades
/// anything.
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | "1 / 12" pages with six thumbnails | the real page count from [paginateReport] | six sections do not make twelve pages |
/// | "Owner Information · John Doe · +90 555 … · Istanbul" | *(gone)*, and the screen says it is gone | a record forwarded by share sheet should not carry a home city and a phone number |
/// | "All vaccinations are up to date" | *(gone)* | the app knows what was typed in, not whether an animal is immune |
/// | "Lab Results · Normal" / "Allergy · Severity: Moderate" | *(gone)* | an all-clear verdict, and a severity beside a named condition |
/// | "PawCare Veterinary Clinic · Dr. Emily Carter" | *(gone)* | named people who did not write this |
/// | QR "Scan to verify this report" | *(gone)* | there is no verification service |
/// | Share · Email · Save to Device · Print, as four buttons | one **Export PDF** and one **Share as text**, with a line naming the share sheet | email, save and print are the OS's, reached through the sheet |
/// | "Complete Health Report" as one of several report types | three real outputs, named for what they are | one PDF exists, plus two text exports that always have |
class HealthReportPreviewScreen extends ConsumerStatefulWidget {
  const HealthReportPreviewScreen({super.key, this.pet});

  /// Optional: the screen follows `activePetProvider` like every other record
  /// surface, and only uses this before the list has loaded.
  final Pet? pet;

  @override
  ConsumerState<HealthReportPreviewScreen> createState() =>
      _HealthReportPreviewScreenState();
}

/// The three things PawDoc can actually produce from a pet's record.
enum ReportKind {
  pdf('Health report (PDF)', 'Built on the server, premium-included',
      LucideIcons.fileText),
  text('Health summary (text)', 'The same record as plain text, free',
      LucideIcons.notebookPen),
  prep('Vet visit prep (text)', 'Your questions and notes for a visit, free',
      LucideIcons.stethoscope);

  const ReportKind(this.label, this.blurb, this.icon);

  final String label;
  final String blurb;
  final IconData icon;
}

/// Recent checks for the report (RLS-scoped), matching the Edge Function's
/// own select.
///
/// Public so a test can hand it rows: the preview's whole purpose is to render
/// the record, and a preview test that cannot supply one would only ever
/// exercise the error state.
final reportChecksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('analyses')
      .select('action, observation, created_at')
      .eq('pet_id', petId)
      .order('created_at', ascending: false)
      .limit(kPdfMaxRows);
  return (rows as List).cast<Map<String, dynamic>>();
});

final _reportEventsProvider = FutureProvider.autoDispose
    .family<List<HealthEvent>, String>((ref, petId) {
  return ref.watch(healthEventsRepositoryProvider).listForPet(petId);
});

class _HealthReportPreviewScreenState
    extends ConsumerState<HealthReportPreviewScreen> {
  ReportKind _kind = ReportKind.pdf;
  int _page = 0;
  double _zoom = 1.0;
  bool _busy = false;

  static const _zoomSteps = [0.75, 0.9, 1.0, 1.25, 1.5];

  void _zoomBy(int delta) {
    final i = _zoomSteps.indexOf(_zoom);
    final next = (i + delta).clamp(0, _zoomSteps.length - 1);
    setState(() => _zoom = _zoomSteps[next]);
  }

  // -------------------------------------------------------------------------

  Future<void> _exportPdf(Pet pet) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final profile = ref.read(userProfileProvider).asData?.value;
    await Analytics.pdfReportRequested(
        profile?.isPremium == true ? 'premium' : 'free');
    try {
      await ref
          .read(pdfReportServiceProvider)
          .generateAndShare(petId: pet.id!, petName: pet.name);
      await Analytics.pdfReportGenerated();
    } on PdfReportPaywallException {
      // GAP-E10: make the 402 actionable — surface Premium, not a dead end.
      messenger.showSnackBar(SnackBar(
        content: const Text('PDF health reports are part of PawDoc Premium.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'See plans',
          onPressed: () => navigator.push(MaterialPageRoute<void>(
              builder: (_) => const PremiumHomeScreen())),
        ),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not build the PDF. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText(Pet pet) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(healthReportServiceProvider).exportForPet(pet);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not prepare the summary. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pickKind() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'What to produce',
        children: [
          for (final k in ReportKind.values)
            HealthRecordRow(
              key: Key('report_kind_${k.name}'),
              leading: HealthGlyphDisc(
                  icon: k.icon,
                  tint: k == _kind
                      ? PawTone.of(context).accent
                      : HealthTone.muted),
              title: k.label,
              subtitle: k.blurb,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() {
                  _kind = k;
                  _page = 0;
                });
              },
            ),
        ],
      ),
    );
  }

  void _explainContents() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthSheet(
        title: 'What is in the file',
        scrollable: true,
        children: [
          for (final line in kReportIncludes)
            HealthDetailRow(
                icon: LucideIcons.check, label: 'Included', value: line),
          for (final line in kReportExcludes)
            HealthDetailRow(
                icon: LucideIcons.minus, label: 'Left out', value: line),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(activePetProvider) ?? widget.pet;
    if (pet == null) return const _NoPetYet();

    final isPremium = ref.watch(userProfileProvider).maybeWhen(
        data: (p) => p.isPremium, orElse: () => false);
    final checks = ref.watch(reportChecksProvider(pet.id!));
    final events = ref.watch(_reportEventsProvider(pet.id!));
    final loading = checks.isLoading || events.isLoading;
    final failed = checks.hasError || events.hasError;

    final preview = buildReportPreview(
      pet: pet,
      analyses: checks.asData?.value ?? const [],
      events: events.asData?.value ?? const [],
    );
    final pages = paginateReport(preview);
    final page = _page.clamp(0, pages.length - 1);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Health Report',
          icon: LucideIcons.fileText,
          subtitleLead: 'Exactly what the file will say',
          subtitle: ', before you send it.',
          actionsWidth: 96,
          actions: [
            HealthActionPill(
              key: const Key('report_contents'),
              label: 'Contents',
              icon: LucideIcons.listChecks,
              dense: true,
              onTap: _explainContents,
            ),
            const SizedBox(width: 6),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        footer: _ExportBar(
          kind: _kind,
          isPremium: isPremium,
          busy: _busy,
          onExport: () => switch (_kind) {
            ReportKind.pdf => _exportPdf(pet),
            ReportKind.text => _shareText(pet),
            ReportKind.prep => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => VetVisitPrepScreen(pet: pet))),
          },
          onShareText: () => _shareText(pet),
        ),
        children: [
          gap(4),
          _SelectorRow(
            pet: pet,
            kind: _kind,
            onPickPet: () => showPetSwitcher(context, ref),
            onPickKind: _pickKind,
          ),
          gap(10),
          if (_kind == ReportKind.pdf) ...[
            _Toolbar(
              page: page,
              pages: pages.length,
              zoom: _zoom,
              onPage: (p) => setState(() => _page = p),
              onZoom: _zoomBy,
            ),
            gap(10),
            if (failed)
              _PreviewProblem(
                message: 'The record could not be read, so there is nothing '
                    'to preview yet.',
                onRetry: () {
                  ref.invalidate(reportChecksProvider(pet.id!));
                  ref.invalidate(_reportEventsProvider(pet.id!));
                },
              )
            else
              _PaperPage(
                preview: preview,
                sections: pages[page],
                first: page == 0,
                last: page == pages.length - 1,
                pageNumber: page + 1,
                pageCount: pages.length,
                zoom: _zoom,
                loading: loading,
              ),
            if (pages.length > 1) ...[
              gap(10),
              _Thumbnails(
                count: pages.length,
                current: page,
                onSelect: (p) => setState(() => _page = p),
              ),
            ],
            gap(11),
            _WindowNote(
              onOpenTimeline: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const HealthHistoryScreen())),
            ),
            gap(11),
            if (!isPremium) ...[
              PremiumBand(
                key: const Key('report_premium_band'),
                icon: LucideIcons.fileText,
                title: 'The PDF is part of Premium',
                body: 'The preview above is the whole file — nothing is '
                    'hidden behind the plan. Sharing the same record as text '
                    'is free, and always will be.',
                ctaLabel: 'See plans & pricing',
                onCta: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PremiumHomeScreen())),
              ),
              gap(11),
            ],
            const _PrivacyCard(),
          ] else
            _TextOutputCard(kind: _kind),
          gap(16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selectors
// ---------------------------------------------------------------------------

class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.pet,
    required this.kind,
    required this.onPickPet,
    required this.onPickKind,
  });

  final Pet pet;
  final ReportKind kind;
  final VoidCallback onPickPet;
  final VoidCallback onPickKind;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 5:6 — the report-type value ("Health report (PDF)") is the longer
          // string of the two, and an even split truncates it.
          Flexible(
            flex: 5,
            child: HomeCard(
              radius: 16,
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
              onTap: onPickPet,
              child: Row(
                children: [
                  // The same call shape every other record surface uses —
                  // a bare LivingPetAvatar showed the species rig instead of
                  // Buddy's own photo on the device.
                  PetPortrait(
                    pet: pet,
                    size: 32,
                    livingAvatar: pet.photoKey == null
                        ? null
                        : LivingPetAvatar(
                            species: pet.species,
                            size: 32,
                            seed: pet.id,
                            photoKey: pet.photoKey,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pet',
                            style: TextStyle(
                                color: HealthTone.muted,
                                fontSize: 10,
                                height: 1.2)),
                        Text(petDisplayName(pet.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronDown,
                      size: 15, color: HealthTone.muted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            flex: 6,
            child: HomeCard(
              key: const Key('report_kind_picker'),
              radius: 16,
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
              onTap: onPickKind,
              child: Row(
                children: [
                  Icon(kind.icon, size: 17, color: t.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Report type',
                            style: TextStyle(
                                color: t.accent,
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w600)),
                        Text(kind.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronDown,
                      size: 15, color: HealthTone.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's page-and-zoom bar. Both controls are real: the page count
/// comes from [paginateReport] and the zoom scales the rendered page.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.page,
    required this.pages,
    required this.zoom,
    required this.onPage,
    required this.onZoom,
  });

  final int page;
  final int pages;
  final double zoom;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onZoom;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('report_toolbar'),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        children: [
          _ToolButton(
            fieldKey: const Key('report_prev_page'),
            icon: LucideIcons.chevronLeft,
            tooltip: 'Previous page',
            onTap: page > 0 ? () => onPage(page - 1) : null,
          ),
          Expanded(
            child: Text('${page + 1} / $pages',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
          _ToolButton(
            fieldKey: const Key('report_next_page'),
            icon: LucideIcons.chevronRight,
            tooltip: 'Next page',
            onTap: page < pages - 1 ? () => onPage(page + 1) : null,
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          _ToolButton(
            fieldKey: const Key('report_zoom_out'),
            icon: LucideIcons.minus,
            tooltip: 'Zoom out',
            onTap: () => onZoom(-1),
          ),
          SizedBox(
            width: 46,
            child: Text('${(zoom * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: HealthTone.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          _ToolButton(
            fieldKey: const Key('report_zoom_in'),
            icon: LucideIcons.plus,
            tooltip: 'Zoom in',
            onTap: () => onZoom(1),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.fieldKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Key fieldKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: ExcludeSemantics(
        child: InkWell(
          key: fieldKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon,
                size: 17,
                color: enabled ? Colors.white : Colors.white24),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------

/// One sheet of the report, drawn as paper.
///
/// White on white, because that is what prints. The reference renders its
/// document on the app's black canvas in lime and violet, which is a nice
/// picture and a poor preview: what a vet receives is black text on white, and
/// the preview should not be a pleasant surprise in either direction.
class _PaperPage extends StatelessWidget {
  const _PaperPage({
    required this.preview,
    required this.sections,
    required this.first,
    required this.last,
    required this.pageNumber,
    required this.pageCount,
    required this.zoom,
    required this.loading,
  });

  final ReportPreview preview;
  final List<ReportSection> sections;
  final bool first;
  final bool last;
  final int pageNumber;
  final int pageCount;
  final double zoom;
  final bool loading;

  static const _ink = Color(0xFF141414);
  static const _mutedInk = Color(0xFF5A5A5A);

  @override
  Widget build(BuildContext context) {
    final scale = zoom;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        key: const Key('report_page'),
        color: Colors.white,
        padding: EdgeInsets.all(18 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (first) ...[
              Text(preview.title,
                  style: TextStyle(
                      color: _ink,
                      fontSize: 19 * scale,
                      height: 1.2,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 3 * scale),
              Text(preview.subtitle,
                  style: TextStyle(
                      color: _mutedInk, fontSize: 11 * scale, height: 1.3)),
              SizedBox(height: 12 * scale),
              Container(height: 1, color: const Color(0xFFDDDDDD)),
              SizedBox(height: 12 * scale),
            ],
            if (loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 26 * scale),
                child: Text('Reading the record…',
                    style: TextStyle(
                        color: _mutedInk, fontSize: 11.5 * scale)),
              )
            else
              for (final s in sections) ...[
                Text(s.heading,
                    style: TextStyle(
                        color: _ink,
                        fontSize: 13 * scale,
                        height: 1.25,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 5 * scale),
                for (final line in s.lines)
                  Padding(
                    padding: EdgeInsets.only(bottom: 3 * scale),
                    child: Text(line,
                        style: TextStyle(
                            color: _ink,
                            fontSize: 11 * scale,
                            height: 1.35)),
                  ),
                SizedBox(height: 13 * scale),
              ],
            if (last) ...[
              Container(height: 1, color: const Color(0xFFDDDDDD)),
              SizedBox(height: 8 * scale),
              Text(preview.disclaimer,
                  key: const Key('report_disclaimer'),
                  style: TextStyle(
                      color: _mutedInk,
                      fontSize: 9.5 * scale,
                      height: 1.4)),
            ],
            SizedBox(height: 8 * scale),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Page $pageNumber of $pageCount',
                  style: TextStyle(
                      color: _mutedInk, fontSize: 9 * scale)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.count,
    required this.current,
    required this.onSelect,
  });

  final int count;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (_, i) => Semantics(
          button: true,
          selected: i == current,
          label: 'Page ${i + 1}',
          child: ExcludeSemantics(
            child: InkWell(
              key: Key('report_thumb_$i'),
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: i == current ? 1 : 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: i == current
                          ? t.accent
                          : Colors.white.withValues(alpha: 0.12),
                      width: i == current ? 1.6 : 1),
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Color(0xFF141414),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Around the page
// ---------------------------------------------------------------------------

/// The report covers 30 days. An owner about to hand it to a vet should know
/// that before they are standing in the room.
class _WindowNote extends StatelessWidget {
  const _WindowNote({required this.onOpenTimeline});

  final VoidCallback onOpenTimeline;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('report_window_note'),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      onTap: onOpenTimeline,
      child: Row(
        children: [
          const Icon(LucideIcons.calendarRange,
              size: 19, color: HealthTone.muted),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('The last 30 days',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('That is the window the report covers, and up to ten '
                    'rows in each section. The whole history stays in the '
                    'timeline.',
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 10.5, height: 1.3)),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 17, color: Colors.white54),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumHonestyNote(
      title: 'What is not in the file',
      lines: [
        'Your name, phone number, email address or where you live. The report '
            'carries the animal, not you — so forwarding it does not forward '
            'your contact details.',
        'Any statement that vaccinations are complete or an animal is '
            'protected. It lists what you recorded.',
        'Any severity, risk level, score or condition name.',
        'The PDF is built in memory and streamed to your share sheet. PawDoc '
            'never stores a copy.',
      ],
    );
  }
}

/// What the two text outputs look like — no paper, because there is none.
class _TextOutputCard extends StatelessWidget {
  const _TextOutputCard({required this.kind});

  final ReportKind kind;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('report_text_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kind.icon, size: 20, color: t.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(kind.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
              ),
              const PremiumChip(label: 'FREE'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            switch (kind) {
              ReportKind.text =>
                'Plain text, handed to whichever app you pick — messages, '
                    'email, notes. It carries the pet, the most recent AI '
                    'check and the recent events, each labelled with where it '
                    'came from.',
              ReportKind.prep =>
                'The prep pack pulls in your reasons for the visit, what you '
                    'have noticed, what to bring and your questions, on top of '
                    'the record. Open it to fill those in first.',
              ReportKind.pdf => '',
            },
            style: const TextStyle(
                color: HealthTone.dim, fontSize: 11.5, height: 1.45),
          ),
          const SizedBox(height: 10),
          const Text(
            'Nothing is uploaded. The text goes straight to the app you '
            'choose.',
            style:
                TextStyle(color: HealthTone.faint, fontSize: 10.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// The reference's four-button footer, reduced to what exists.
class _ExportBar extends StatelessWidget {
  const _ExportBar({
    required this.kind,
    required this.isPremium,
    required this.busy,
    required this.onExport,
    required this.onShareText,
  });

  final ReportKind kind;
  final bool isPremium;
  final bool busy;
  final VoidCallback onExport;
  final VoidCallback onShareText;

  @override
  Widget build(BuildContext context) {
    final pdf = kind == ReportKind.pdf;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (pdf) ...[
              // 3:5 rather than 1:2 — "Share as text" ellipsised to
              // "Share as t…" beside the primary CTA.
              Expanded(
                flex: 3,
                child: HealthActionPill(
                  key: const Key('report_share_text'),
                  label: 'Share text',
                  icon: LucideIcons.share2,
                  color: HealthTone.muted,
                  dense: true,
                  onTap: busy ? null : onShareText,
                ),
              ),
              const SizedBox(width: 9),
            ],
            Expanded(
              flex: 5,
              child: HealthPrimaryCta(
                key: const Key('report_export'),
                label: busy
                    ? 'Working…'
                    : switch (kind) {
                        ReportKind.pdf =>
                          isPremium ? 'Export PDF' : 'Export PDF · Premium',
                        ReportKind.text => 'Share the summary',
                        ReportKind.prep => 'Open vet visit prep',
                      },
                icon: pdf && !isPremium ? LucideIcons.lock : null,
                trailingIcon: busy ? null : LucideIcons.chevronRight,
                enabled: !busy,
                onTap: onExport,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Save, print and email are offered by your device’s share sheet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: HealthTone.faint, fontSize: 10, height: 1.3),
        ),
      ],
    );
  }
}

class _PreviewProblem extends StatelessWidget {
  const _PreviewProblem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('report_problem'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 22),
      child: Column(
        children: [
          const Icon(LucideIcons.wifiOff, size: 24, color: HealthTone.muted),
          const SizedBox(height: 9),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.35)),
          const SizedBox(height: 11),
          HealthActionPill(
              label: 'Try again', icon: LucideIcons.refreshCw, onTap: onRetry),
        ],
      ),
    );
  }
}

class _NoPetYet extends StatelessWidget {
  const _NoPetYet();

  @override
  Widget build(BuildContext context) {
    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: const PetModuleAppBar(
          title: 'Health Report',
          icon: LucideIcons.fileText,
          subtitle: 'Add a pet and the report has something to say.',
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(30),
          HomeCard(
            radius: 18,
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
            child: Column(
              children: const [
                Icon(LucideIcons.pawPrint, size: 26, color: HealthTone.muted),
                SizedBox(height: 10),
                Text('No pet on this account yet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                    'A report is built from one pet’s record. Add a pet from '
                    'the Pets tab and this fills itself in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

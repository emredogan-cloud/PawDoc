import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../account/user_profile.dart';
import '../analysis/result_screen.dart';
import '../analytics/analytics.dart';
import '../core/action_labels.dart';
import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../export/health_report_service.dart';
import '../home/home_sections.dart';
import '../memories/memory_photo.dart';
import '../models/analysis_result.dart';
import '../monetization/paywall_screen.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_switcher.dart';
import '../prep/vet_visit_prep_screen.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'health_event_form_screen.dart';
import 'health_record_detail.dart';
import 'health_sections.dart';
import 'pdf_report_service.dart';
import 'timeline.dart';

/// The pet's health record, rebuilt against mockup `health_timeline`.
///
/// Hero pet card with the Care Score, the type rail, the counted statistics
/// strip, the dashed timeline rail with one card per record, and the pinned
/// "Add Event" footer over the app's bottom navigation.
///
/// **Copy departures from the mockup, and why** (layout reproduced in each
/// case):
///
/// | Mockup | Shipped | Reason |
/// |---|---|---|
/// | "Health Score · 92 · Excellent" | "Care Score", record completeness | D-2 — a number that reads as a verdict on an animal's health, over nothing |
/// | "AI Skin Analysis" | "AI Health Check" | naming the body system the model looked at is a step toward naming a condition |
/// | chip "Low Risk" | the action-ladder value | a risk level is not something the product renders |
/// | "Mild redness detected on Buddy's paw. Likely caused by licking." | the stored observation only | never assert a cause |
/// | "✓ All parameters normal" | the owner's own note | an all-clear the app did not read and cannot vouch for |
class HealthHistoryScreen extends ConsumerStatefulWidget {
  const HealthHistoryScreen({this.embedded = false, super.key});

  /// True when the screen is the shell's Health tab, which already draws the
  /// bar. Every mockup in this batch puts the navigation on the page, so the
  /// screen owns one — but rendering it inside the shell stacks two.
  final bool embedded;

  @override
  ConsumerState<HealthHistoryScreen> createState() =>
      _HealthHistoryScreenState();
}

class _HealthHistoryScreenState extends ConsumerState<HealthHistoryScreen> {
  String _filter = 'all';

  static const _filters = [
    HealthFilter('all', 'All Events', LucideIcons.layoutGrid),
    HealthFilter('analysis', 'AI Analyses', LucideIcons.sparkles),
    HealthFilter('vet_visit', 'Vet Visits', LucideIcons.stethoscope),
    HealthFilter('medication', 'Medications', LucideIcons.pill),
    HealthFilter('vaccination', 'Vaccines', LucideIcons.syringe),
    HealthFilter('lab_result', 'Labs', LucideIcons.flaskConical),
    HealthFilter('weight', 'Weight', LucideIcons.scale),
    HealthFilter('custom', 'Notes', LucideIcons.notebookPen),
  ];

  // -------------------------------------------------------------------------
  // Actions (logic unchanged from the previous screen; only re-homed)
  // -------------------------------------------------------------------------

  Future<void> _shareMarkdown(Pet pet) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(healthReportServiceProvider).exportForPet(pet);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not prepare the report. Please try again.')));
    }
  }

  Future<void> _exportPdf(String petId, String petName) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final profile = ref.read(userProfileProvider).asData?.value;
    await Analytics.pdfReportRequested(
        profile?.isPremium == true ? 'premium' : 'free');
    try {
      await ref
          .read(pdfReportServiceProvider)
          .generateAndShare(petId: petId, petName: petName);
      await Analytics.pdfReportGenerated();
    } on PdfReportPaywallException {
      // GAP-E10: make the 402 actionable — surface the paywall, not a dead end.
      messenger.showSnackBar(SnackBar(
        content: const Text('PDF Health Reports are part of PawDoc Premium.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Upgrade',
          onPressed: () => navigator
              .push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
        ),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not generate the PDF. Please try again.')));
    }
  }

  Future<void> _logEvent(Pet pet, {String? type}) async {
    final messenger = ScaffoldMessenger.of(context);
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthEventFormScreen(
            petId: pet.id!, petName: pet.name, initialType: type),
      ),
    );
    ref.invalidate(healthTimelineProvider(pet.id!));
    if (logged == true) {
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(LucideIcons.pawPrint, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text("Logged to ${petDisplayName(pet.name)}'s record")),
        ]),
      ));
    }
  }

  /// Reopens a stored analysis. `full_response` is the frozen contract payload,
  /// so the same screen renders it — no second inference, no re-derivation.
  void _openResult(TimelineItem item, Pet pet) {
    final payload = item.payload;
    if (payload == null) {
      _toast('That result is no longer available.');
      return;
    }
    try {
      final result = AnalysisResult.fromJson(payload);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: result,
          analysisId: item.id,
          petId: pet.id,
          petName: pet.name,
          petSpecies: pet.species,
          petPhotoKey: pet.photoKey,
          generatedAt: item.date,
        ),
      ));
    } catch (_) {
      _toast('That result could not be reopened.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openMenu(Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(children: [
        HealthRecordRow(
          key: const Key('open_vet_prep'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.clipboardList, tint: HealthTone.info),
          title: 'Vet visit prep',
          subtitle: 'Build a pack to take with you',
          chevron: false,
          onTap: () {
            Navigator.pop(sheetContext);
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VetVisitPrepScreen(pet: pet)));
          },
        ),
        HealthRecordRow(
          key: const Key('export_health_report'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.share2, tint: HealthTone.teal),
          title: 'Share report',
          subtitle: 'Send the record as text',
          chevron: false,
          onTap: () {
            Navigator.pop(sheetContext);
            _shareMarkdown(pet);
          },
        ),
        HealthRecordRow(
          key: const Key('generate_pdf_report'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.fileText, tint: HealthTone.violet),
          title: 'Export PDF',
          subtitle: 'A printable health report',
          chevron: false,
          onTap: () {
            Navigator.pop(sheetContext);
            _exportPdf(pet.id!, pet.name);
          },
        ),
        HealthRecordRow(
          key: const Key('open_reminders'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.bellRing, tint: HealthTone.gold),
          title: 'Reminders',
          subtitle: 'Vaccines, medication, re-checks',
          chevron: false,
          onTap: () {
            Navigator.pop(sheetContext);
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersScreen()));
          },
        ),
      ]),
    );
  }

  // -------------------------------------------------------------------------

  bool _matches(TimelineItem item) {
    if (_filter == 'all') return true;
    if (_filter == 'analysis') return item.kind == TimelineKind.analysis;
    return item.eventType == _filter;
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(activePetProvider);
    if (pet == null) return _NoPetYet(embedded: widget.embedded);

    final async = ref.watch(healthTimelineProvider(pet.id!));
    final all = async.value ?? const <TimelineItem>[];
    final visible = all.where(_matches).toList(growable: false);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Health Timeline',
          subtitleLead: petDisplayPossessive(pet.name),
          subtitle: ' health journey',
          actions: [
            HealthCircleButton(
              key: const Key('history_actions_menu'),
              icon: LucideIcons.slidersHorizontal,
              tooltip: 'Report & reminders',
              color: PawTone.of(context).accent,
              onTap: () => _openMenu(pet),
            ),
          ],
        ),
        onRefresh: () async {
          ref.invalidate(healthTimelineProvider(pet.id!));
          await ref.read(healthTimelineProvider(pet.id!).future);
        },
        bottomNav: widget.embedded ? null : const PawNavBar(detached: true),
        footer: HealthPrimaryCta(
          key: const Key('log_event_fab'),
          label: 'Add Event',
          onTap: () => _logEvent(pet),
        ),
        children: [
          gap(2),
          PetModuleHeaderCard(
            portrait: _portrait(pet, 52),
            name: petDisplayName(pet.name),
            meta: petMetaLine(pet),
            onSwitch: () => showPetSwitcher(context, ref),
            onViewProfile: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
            ),
            trailing: _CareScoreDial(pet: pet, items: all),
          ),
          gap(11),
          HealthBleed(
            child: HealthFilterChips(
              filters: _filters,
              selected: _filter,
              onSelect: (id) => setState(() => _filter = id),
            ),
          ),
          gap(11),
          HealthStatTiles(
            grouped: true,
            stats: _stats(all),
          ),
          gap(6),
          ...switch (async) {
            AsyncError(:final error) => [
                gap(22),
                _Notice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load the record',
                  body: friendlyLoadError(error, noun: 'history'),
                ),
              ],
            AsyncLoading() when all.isEmpty => [
                gap(24),
                const Center(child: CircularProgressIndicator()),
              ],
            _ when all.isEmpty => [
                gap(16),
                _EmptyRecord(petName: pet.name, onLog: () => _logEvent(pet)),
              ],
            _ when visible.isEmpty => [
                gap(18),
                _Notice(
                  icon: LucideIcons.listFilter,
                  title: 'Nothing filed here yet',
                  body: 'No ${_labelFor(_filter).toLowerCase()} in '
                      "${petDisplayPossessive(pet.name)} record so far.",
                ),
              ],
            _ => _rail(visible, pet),
          },
          gap(10),
          HealthAddCard(
            key: const Key('timeline_add_card'),
            icon: LucideIcons.calendarPlus,
            title: 'Add new health event',
            subtitle:
                'Keep ${petDisplayPossessive(pet.name)} health record up to date.',
            onTap: () => _logEvent(pet),
          ),
          gap(8),
        ],
      ),
    );
  }

  String _labelFor(String id) =>
      _filters.firstWhere((f) => f.id == id, orElse: () => _filters.first).label;

  List<HealthStat> _stats(List<TimelineItem> items) {
    int countOf(String type) =>
        items.where((i) => i.eventType == type).length;
    return [
      HealthStat(
        icon: LucideIcons.calendarDays,
        value: '${items.length}',
        label: 'Events',
      ),
      HealthStat(
        icon: LucideIcons.stethoscope,
        value: '${countOf('vet_visit')}',
        label: 'Vet visits',
      ),
      HealthStat(
        icon: LucideIcons.pill,
        value: '${countOf('medication')}',
        label: 'Medicines',
      ),
      HealthStat(
        icon: LucideIcons.sparkles,
        value:
            '${items.where((i) => i.kind == TimelineKind.analysis).length}',
        label: 'AI checks',
      ),
    ];
  }

  /// The dashed rail with a node per record, grouped by day.
  List<Widget> _rail(List<TimelineItem> items, Pet pet) {
    final out = <Widget>[];
    String? bucket;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final label = _dayLabel(item.date);
      if (label != bucket) {
        out.add(Padding(
          // Clears the rail, so a date never sits on the dashed line.
          padding: const EdgeInsets.only(left: 46),
          child: HealthGroupLabel(label: label, accent: label == 'Today'),
        ));
        bucket = label;
      }
      out.add(_TimelineNode(
        item: item,
        isLast: i == items.length - 1,
        card: _card(item, pet),
      ));
    }
    return out;
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return shortDate(d);
  }

  /// A clock time today, `Aug 6` this year, `Aug 6, 2025` before that.
  ///
  /// The year is dropped inside the current one because the card has to fit a
  /// title, a ladder chip, the stamp and a chevron beside a 62dp photo in
  /// 221 points, and "Aug 6, 2026" is what pushed the title into an ellipsis.
  ///
  /// A health event's `event_date` is a DATE, so its time is midnight — and
  /// stamping a visit filed this afternoon "12:00 AM" is a fabricated detail.
  /// Manual records print the time the owner entered, or nothing when the
  /// group label above already says which day it was.
  static String _stamp(TimelineItem item) {
    final d = item.date;
    final today = _dayLabel(d) == 'Today';
    if (item.kind == TimelineKind.healthEvent) {
      final entered = (item.payload?['time'] as String?)?.trim();
      if (entered != null && entered.isNotEmpty) return entered;
      if (today || _dayLabel(d) == 'Yesterday') return '';
      return _dateStamp(d);
    }
    if (today) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      return '$h:${d.minute.toString().padLeft(2, '0')} '
          '${d.hour < 12 ? 'AM' : 'PM'}';
    }
    return _dateStamp(d);
  }

  static String _dateStamp(DateTime d) {
    final full = shortDate(d);
    return d.year == DateTime.now().year
        ? full.substring(0, full.lastIndexOf(','))
        : full;
  }

  Widget _card(TimelineItem item, Pet pet) {
    if (item.kind == TimelineKind.analysis) {
      return _AnalysisCard(
        item: item,
        stamp: _stamp(item),
        onOpen: () => _openResult(item, pet),
      );
    }
    return _EventCard(
      item: item,
      stamp: _stamp(item),
      onOpen: () => showHealthRecordDetail(
        context,
        ref,
        item: item,
        pet: pet,
        onChanged: () => ref.invalidate(healthTimelineProvider(pet.id!)),
      ),
    );
  }

  Widget _portrait(Pet pet, double size) => PetPortrait(
        pet: pet,
        size: size,
        livingAvatar: pet.photoKey == null
            ? null
            : LivingPetAvatar(
                species: pet.species,
                size: size,
                seed: pet.id,
                photoKey: pet.photoKey,
              ),
      );
}

/// `Golden Retriever · 3y 2m · 28kg` — the meta line every record header prints.
String petMetaLine(Pet pet) => [
      if (pet.breed?.trim().isNotEmpty == true)
        pet.breed!.trim()
      else
        speciesName(pet.species),
      ?petAgeLabel(pet.birthDate),
      if (pet.weightKg != null) '${_kg(pet.weightKg!)}kg',
    ].join(' · ');

String _kg(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// ---------------------------------------------------------------------------
// The rail
// ---------------------------------------------------------------------------

/// One record on the dashed rail: a circled glyph on the line, the card beside
/// it.
class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.item,
    required this.isLast,
    required this.card,
  });

  final TimelineItem item;
  final bool isLast;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final tint = timelineTint(context, item);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                const SizedBox(height: 10),
                HealthGlyphDisc(
                    icon: timelineIcon(item), tint: tint, size: 36),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          painter: _DashedRailPainter(
                              PawTone.of(context).accent.withValues(alpha: 0.45)),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRailPainter extends CustomPainter {
  const _DashedRailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    var y = 2.0;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 5).clamp(0, size.height)),
          paint);
      y += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRailPainter old) => old.color != color;
}

/// The glyph and tint a record is drawn with.
///
/// An analysis takes the **action ladder's** own hue: that is the one place on
/// this screen where colour carries meaning, and it is the meaning the ladder
/// already owns. Every other tint is decorative and stays clear of the four
/// safety-locked values.
IconData timelineIcon(TimelineItem item) {
  if (item.kind == TimelineKind.analysis) return LucideIcons.sparkles;
  return switch (item.eventType) {
    'vaccination' => LucideIcons.syringe,
    'vet_visit' => LucideIcons.stethoscope,
    'medication' => LucideIcons.pill,
    'lab_result' => LucideIcons.flaskConical,
    'weight' => LucideIcons.scale,
    _ => LucideIcons.notebookPen,
  };
}

Color timelineTint(BuildContext context, TimelineItem item) {
  if (item.kind == TimelineKind.analysis) {
    return actionColor(item.action ?? '');
  }
  return switch (item.eventType) {
    'vaccination' => PawTone.of(context).accent,
    'vet_visit' => HealthTone.teal,
    'medication' => HealthTone.violet,
    'lab_result' => HealthTone.info,
    'weight' => HealthTone.gold,
    _ => HealthTone.muted,
  };
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// A past AI check.
///
/// The mockup titles this "AI Skin Analysis" and chips it "Low Risk". Neither
/// ships: naming the body system the model looked at is a step toward naming a
/// condition, and a risk level is not something the product renders. The chip
/// carries the action-ladder value, which is the record's actual conclusion.
class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.item,
    required this.stamp,
    required this.onOpen,
  });

  final TimelineItem item;
  final String stamp;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final tint = actionColor(item.action ?? '');
    return HomeCard(
      radius: 14,
      padding: const EdgeInsets.all(10),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageKey != null) ...[
                _CheckedPhoto(storageKey: item.imageKey!),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Flexible(
                        child: Text('AI Health Check',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: HealthPill(
                            label: actionLabel(item.action ?? ''), tint: tint),
                      ),
                      const SizedBox(width: 6),
                      Text(stamp,
                          style: const TextStyle(
                              color: HealthTone.faint, fontSize: 10.5)),
                      const Icon(LucideIcons.chevronRight,
                          size: 15, color: Colors.white54),
                    ]),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(item.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11.5,
                              height: 1.3)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Both halves shrink. Beside a 62dp photo the card's action row has
          // barely 220 points, and at a large text scale the pill and the
          // marker together overflow it.
          // Flex factors rather than a Spacer. A loose Flexible beside a
          // Spacer splits the free space evenly, which squeezed "View Result"
          // into "View R…" even with room to spare; weighted shares let each
          // side take what it needs and shrink only when the row is genuinely
          // short (which the em-square test font makes it).
          Row(children: [
            Flexible(
              flex: 5,
              child: _CardPill(
                icon: LucideIcons.sparkles,
                label: 'View Result',
                tint: t.accent,
                onTap: onOpen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.bookmarkCheck,
                      size: 13, color: HealthTone.faint),
                  const SizedBox(width: 5),
                  const Flexible(
                    child: Text('Saved to record',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: HealthTone.faint, fontSize: 10.5)),
                  ),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// The photo the check was run on, with the mockup's "AI" badge.
class _CheckedPhoto extends StatelessWidget {
  const _CheckedPhoto({required this.storageKey});

  final String storageKey;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        children: [
          Positioned.fill(
            child: MemoryPhoto(
              storageKey: storageKey,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent,
              ),
              child: const Center(
                child: Text('AI',
                    style: TextStyle(
                        color: Color(0xFF06110A),
                        fontSize: 8,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A manually-filed record.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.item,
    required this.stamp,
    required this.onOpen,
  });

  final TimelineItem item;
  final String stamp;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final action = switch (item.eventType) {
      'vet_visit' => ('Visit Summary', LucideIcons.fileText),
      'lab_result' => ('View Result', LucideIcons.flaskConical),
      'weight' => ('View Trend', LucideIcons.trendingUp),
      _ => ('View Details', LucideIcons.list),
    };
    return HomeCard(
      radius: 14,
      padding: const EdgeInsets.all(10),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w700)),
            ),
            if (stamp.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(stamp,
                  style: const TextStyle(
                      color: HealthTone.faint, fontSize: 10.5)),
            ],
            const Icon(LucideIcons.chevronRight,
                size: 15, color: Colors.white54),
          ]),
          if (item.subtitle != null) ...[
            const SizedBox(height: 3),
            Text(item.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.3)),
          ],
          const SizedBox(height: 7),
          Row(children: [
            if (item.detail != null)
              Expanded(
                child: Text(item.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 11)),
              )
            else
              const Spacer(),
            const SizedBox(width: 6),
            _CardPill(
              icon: action.$2,
              label: action.$1,
              tint: t.accent,
              onTap: onOpen,
            ),
          ]),
        ],
      ),
    );
  }
}

/// The bordered lozenge the cards hang their action on.
class _CardPill extends StatelessWidget {
  const _CardPill({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: tint.withValues(alpha: 0.10),
          border: Border.all(color: tint.withValues(alpha: 0.40)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: tint, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The Care Score dial
// ---------------------------------------------------------------------------

/// **D-2.** The mockup labels this dial "Health Score · 92 · Excellent". A
/// number that reads as a verdict on an animal's health, with nothing behind
/// it, is exactly the reliance the product must not invite. The dial is
/// computed from how complete the pet's *record* is and captioned as such.
class _CareScoreDial extends ConsumerWidget {
  const _CareScoreDial({required this.pet, required this.items});

  final Pet pet;
  final List<TimelineItem> items;

  static String band(int score) {
    if (score >= 95) return 'Complete';
    if (score >= 70) return 'Well kept';
    if (score >= 45) return 'Filling in';
    return 'Just started';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final hasReminder = ref
            .watch(remindersForPetProvider(pet.id!))
            .value
            ?.isNotEmpty ==
        true;
    final score = careScore(
      pet,
      hasCheck: items.any((i) => i.kind == TimelineKind.analysis),
      hasReminder: hasReminder,
    );
    final newest = items.isEmpty ? null : items.first.date;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(LucideIcons.heartPulse, size: 13, color: t.accent),
          const SizedBox(width: 5),
          const Flexible(
            child: Text('Care Score',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: HealthTone.muted, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$score',
                      key: const Key('timeline_care_score'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.05,
                          fontWeight: FontWeight.w800)),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(band(score),
                      style: TextStyle(
                          color: t.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(t.accent),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Container(
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: t.accent),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
                newest == null
                    ? 'Record completeness'
                    : 'Last entry ${_HealthHistoryScreenState._dayLabel(newest).toLowerCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: HealthTone.faint, fontSize: 10)),
          ),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _NoPetYet extends StatelessWidget {
  const _NoPetYet({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const PetModuleAppBar(
          title: 'Health Timeline',
          subtitleLead: 'PawDoc',
          subtitle: ' health record',
        ),
        bottomNavigationBar:
            embedded ? null : const PawNavBar(detached: true),
        body: Padding(
          padding: kRecordPadding,
          child: Center(
            child: HealthAddCard(
              title: 'Add a pet to start a record',
              subtitle: 'Every check, visit and vaccine files itself here.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PetFormScreen()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecord extends StatelessWidget {
  const _EmptyRecord({required this.petName, required this.onLog});

  final String petName;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: [
          Icon(LucideIcons.calendarHeart, size: 30, color: t.accent),
          const SizedBox(height: 12),
          Text("${petDisplayPossessive(petName)} health story starts here",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Run a check or file a visit — everything you record helps spot '
              'changes early, and makes the next vet appointment easier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 26, color: HealthTone.muted),
          const SizedBox(height: 11),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}

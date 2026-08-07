import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../analysis/analysis_service.dart';
import '../core/action_labels.dart';
import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart';
import '../health/timeline.dart';
import '../health/vaccination_manager_screen.dart';
import '../home/home_sections.dart';
import '../reminders/reminder.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'active_pet.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pet_profile_screen.dart';
import 'pet_statistics_screen.dart';
import 'pets_repository.dart';

/// Every pet on the account, rebuilt against mockup `manage_multiple_pets`.
///
/// Header with Add Pet, search, sort and the grid/list toggle, the four
/// counted statistics, one card per pet with its five actions, and the family
/// invite footer — over the app's bottom navigation.
///
/// ## What the mockup claims, and what ships
///
/// | Mockup | Shipped | Why |
/// |---|---|---|
/// | "Family Health · Excellent" | records on file, counted | the app has examined no animal; "Excellent" over three pets is a verdict on all of them at once |
/// | "Health Score · 92 · Excellent" per pet | the Care Score and its record band | **D-2** |
/// | "Blood Type: DEA 1.1 +" / "N/A" | dropped from the card | no column, and "N/A" beside a real value on the pet above reads as a *measured* absence |
/// | "Friendly · Playful · Good with kids" | one *Soon* pill, in the chips' place | no column for a trait |
/// | "Primary Pet" | "Active" — the pet the rest of the app is scoped to | the app has an active pet, not a primary one, and the difference is what every other screen is showing |
///
/// Search, sort and both layouts are real and client-side over the loaded
/// list. Every per-card action switches the active pet first, because the
/// modules it opens are scoped to it — tapping "Records" on the second pet and
/// landing on the first one's timeline would be a quiet lie.
class PetsListScreen extends ConsumerStatefulWidget {
  const PetsListScreen({this.embedded = false, super.key});

  /// True when the screen is the shell's Pets tab, which already draws the
  /// bar. The mockup puts the navigation on the page, so the screen owns one —
  /// but rendering it inside the shell stacks two.
  final bool embedded;

  @override
  ConsumerState<PetsListScreen> createState() => _PetsListScreenState();
}

/// How the list is ordered.
enum PetSort {
  name('Name (A–Z)', LucideIcons.arrowDownAZ),
  added('Recently added', LucideIcons.clock),
  species('Species', LucideIcons.pawPrint),
  records('Most records', LucideIcons.fileText);

  const PetSort(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Case-insensitive search over the fields an owner would type. Pure, so it is
/// unit-testable and works on the already-loaded list without a round trip.
List<Pet> filterPets(List<Pet> pets, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return pets;
  return pets
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.breed?.toLowerCase().contains(q) ?? false) ||
          speciesName(p.species).toLowerCase().contains(q))
      .toList(growable: false);
}

/// Ordering. [recordCounts] is consulted only by [PetSort.records].
List<Pet> sortPets(List<Pet> pets, PetSort sort,
    {Map<String, int> recordCounts = const {}}) {
  final out = [...pets];
  switch (sort) {
    case PetSort.name:
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case PetSort.added:
      // The repository already returns `order('created_at')` ascending, so the
      // most recent is the tail.
      return out.reversed.toList(growable: false);
    case PetSort.species:
      out.sort((a, b) {
        final s = speciesName(a.species).compareTo(speciesName(b.species));
        return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case PetSort.records:
      out.sort((a, b) =>
          (recordCounts[b.id] ?? 0).compareTo(recordCounts[a.id] ?? 0));
  }
  return out;
}

class _PetsListScreenState extends ConsumerState<PetsListScreen> {
  final _search = TextEditingController();
  String _query = '';
  PetSort _sort = PetSort.name;
  bool _grid = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _push(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => screen));

  /// Switches the active pet *before* opening a module. Everything downstream
  /// reads `activePetProvider`, so opening the vaccination manager for the
  /// second pet without this would show the first one's record.
  void _openFor(Pet pet, Widget screen) {
    if (pet.id != null) {
      ref.read(activePetIdProvider.notifier).select(pet.id!);
    }
    _push(screen);
  }

  Future<void> _add() async {
    await _pushForm();
  }

  Future<void> _pushForm({Pet? pet}) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)));
    ref.invalidate(petsListProvider);
  }

  void _openSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Sort pets by',
        children: [
          for (final s in PetSort.values)
            HealthRecordRow(
              key: Key('pet_sort_${s.name}'),
              leading: HealthGlyphDisc(
                icon: s.icon,
                tint: s == _sort
                    ? PawTone.of(context).accent
                    : HealthTone.info,
                size: 36,
              ),
              title: s.label,
              subtitle: s == _sort ? 'Current' : null,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _sort = s);
              },
            ),
        ],
      ),
    );
  }

  void _openMore(Pet pet, bool isActive) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: petDisplayName(pet.name),
        children: [
          if (!isActive)
            HealthRecordRow(
              key: const Key('pet_more_activate'),
              leading: HealthGlyphDisc(
                  icon: LucideIcons.star,
                  tint: PawTone.of(context).accent,
                  size: 36),
              title: 'Make this the active pet',
              subtitle: 'Home, Health and the Assistant follow the active pet',
              onTap: () {
                Navigator.pop(sheetContext);
                if (pet.id != null) {
                  ref.read(activePetIdProvider.notifier).select(pet.id!);
                }
              },
            ),
          HealthRecordRow(
            key: const Key('pet_more_edit'),
            leading: const HealthGlyphDisc(
                icon: LucideIcons.pencil, tint: HealthTone.info, size: 36),
            title: 'Edit profile',
            subtitle: 'Name, breed, birthday, photo',
            onTap: () {
              Navigator.pop(sheetContext);
              _pushForm(pet: pet);
            },
          ),
          HealthRecordRow(
            key: const Key('pet_more_vaccines'),
            leading: const HealthGlyphDisc(
                icon: LucideIcons.syringe, tint: HealthTone.teal, size: 36),
            title: 'Vaccination manager',
            subtitle: 'What is on file, and what is coming up',
            onTap: () {
              Navigator.pop(sheetContext);
              _openFor(pet, const VaccinationManagerScreen());
            },
          ),
          HealthRecordRow(
            key: const Key('pet_more_delete'),
            leading: const HealthGlyphDisc(
                icon: LucideIcons.trash2, tint: HealthTone.gold, size: 36),
            title: 'Remove pet',
            subtitle: 'Past records are kept',
            onTap: () {
              Navigator.pop(sheetContext);
              _confirmDelete(pet);
            },
          ),
        ],
      ),
    );
  }

  /// Soft delete — `is_active = false`, so every past analysis and health
  /// record survives. The dialog says so, because "delete" and "hide, keeping
  /// the record" are different promises.
  Future<void> _confirmDelete(Pet pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${petDisplayName(pet.name)}?'),
        content: Text('${petDisplayName(pet.name)} disappears from the app. '
            'Past health records and AI checks are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              key: const Key('pets_delete_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || pet.id == null) return;
    await ref.read(petsRepositoryProvider).softDelete(pet.id!);
    ref.invalidate(petsListProvider);
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(petsListProvider);
    final all = async.value ?? const <Pet>[];
    final activeId = ref.watch(activePetProvider)?.id;

    // Counted per pet, from the same providers the modules read.
    //
    // `counting` is true until every one of them has landed. Rendering a bare
    // 0 in the meantime says "no records" about a pet that has eighteen, and
    // the number then jumps — a dash is honest for the half-second it lasts.
    final recordCounts = <String, int>{};
    var reminderCount = 0;
    var upcoming = 0;
    var counting = false;
    final soon = DateTime.now().add(const Duration(days: 30));
    for (final pet in all) {
      if (pet.id == null) continue;
      final timeline = ref.watch(healthTimelineProvider(pet.id!));
      final reminderAsync = ref.watch(remindersForPetProvider(pet.id!));
      if (!timeline.hasValue || !reminderAsync.hasValue) counting = true;
      final items = timeline.value ?? const <TimelineItem>[];
      recordCounts[pet.id!] = items.length;
      final reminders = reminderAsync.value ?? const <Reminder>[];
      reminderCount += reminders.length;
      upcoming += reminders
          .where((r) => !r.isPastDue && r.dueDate.isBefore(soon))
          .length;
    }
    final records =
        recordCounts.values.fold<int>(0, (sum, n) => sum + n);
    String count(int n) => counting ? '—' : '$n';
    String? note(int n, String empty, String some) =>
        counting ? null : (n == 0 ? empty : some);

    final visible =
        sortPets(filterPets(all, _query), _sort, recordCounts: recordCounts);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pawPrint,
          title: 'My Pets',
          subtitle: 'Manage all your furry family members',
          actionsWidth: 108,
          onBack: widget.embedded ? () {} : null,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: HealthActionPill(
                key: const Key('pets_add'),
                label: 'Add Pet',
                icon: LucideIcons.plus,
                dense: true,
                onTap: _add,
              ),
            ),
          ],
        ),
        onRefresh: () async {
          ref.invalidate(petsListProvider);
          await ref.read(petsListProvider.future);
        },
        bottomNav: widget.embedded ? null : const PawNavBar(detached: true),
        children: [
          gap(2),
          _Toolbar(
            controller: _search,
            onQuery: (q) => setState(() => _query = q),
            onSort: _openSort,
            grid: _grid,
            onLayout: (g) => setState(() => _grid = g),
          ),
          gap(11),
          HealthStatTiles(
            layout: HealthStatLayout.stacked,
            stats: [
              HealthStat(
                icon: LucideIcons.pawPrint,
                value: '${all.length}',
                label: 'Total pets',
              ),
              // The mockup's "Family Health · Excellent". The app has examined
              // no animal; what it can count is what has been filed.
              HealthStat(
                icon: LucideIcons.fileText,
                value: count(records),
                label: 'Records on file',
                caption: note(records, 'None yet', 'Statistics'),
                onTap: () => _push(const PetStatisticsScreen()),
              ),
              HealthStat(
                icon: LucideIcons.bell,
                value: count(reminderCount),
                label: 'Reminders',
                caption: note(reminderCount, 'None set', 'View all'),
                onTap: () => _push(const RemindersScreen()),
              ),
              HealthStat(
                icon: LucideIcons.calendarDays,
                value: count(upcoming),
                label: 'Due in 30 days',
                caption: note(upcoming, 'Nothing due', 'View'),
                onTap: () => _push(const RemindersScreen()),
              ),
            ],
          ),
          gap(11),
          ...switch (async) {
            AsyncError(:final error) => [
                _Notice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load your pets',
                  body: friendlyLoadError(error, noun: 'pets'),
                ),
              ],
            AsyncLoading() when all.isEmpty => [
                const Center(child: CircularProgressIndicator()),
              ],
            _ when all.isEmpty => [
                HealthAddCard(
                  key: const Key('pets_empty'),
                  title: 'No pets yet',
                  subtitle: 'Everything in PawDoc — records, reminders, '
                      'checks — lives per pet. Add a pet to begin.',
                  onTap: _add,
                ),
              ],
            _ when visible.isEmpty => [
                const _EmptyLine(
                  key: Key('pets_no_match'),
                  icon: LucideIcons.search,
                  text: 'No pet matches that. Try a name, a breed or a '
                      'species.',
                ),
              ],
            _ when _grid => [
                _PetGrid(
                  pets: visible,
                  activeId: activeId,
                  onOpen: (p) => _openFor(p, PetProfileScreen(pet: p)),
                  onMore: (p) => _openMore(p, p.id == activeId),
                ),
              ],
            _ => [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) gap(9),
                  _PetCard(
                    pet: visible[i],
                    isActive: visible[i].id == activeId,
                    records: recordCounts[visible[i].id] ?? 0,
                    onProfile: () =>
                        _openFor(visible[i], PetProfileScreen(pet: visible[i])),
                    onRecords: () =>
                        _openFor(visible[i], const HealthHistoryScreen()),
                    onReminders: () =>
                        _openFor(visible[i], const RemindersScreen()),
                    onHealth: () => _openFor(
                        visible[i], const VaccinationManagerScreen()),
                    onMore: () =>
                        _openMore(visible[i], visible[i].id == activeId),
                    onTraits: () => _soon('Personality traits'),
                  ),
                ],
              ],
          },
          gap(11),
          _InviteFamilyCard(onTap: () => _soon('Sharing pets with your family')),
          gap(8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onQuery,
    required this.onSort,
    required this.grid,
    required this.onLayout,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final VoidCallback onSort;
  final bool grid;
  final ValueChanged<bool> onLayout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: HealthSearchField(
            fieldKey: const Key('pets_search_field'),
            controller: controller,
            onChanged: onQuery,
            hint: 'Search pets…',
            // Not autofocused: the field is always on the page here, and
            // stealing the keyboard on arrival would hide the list.
            autofocus: false,
          ),
        ),
        const SizedBox(width: 8),
        _ToolButton(
          fieldKey: const Key('pets_sort'),
          icon: LucideIcons.arrowUpDown,
          label: 'Sort',
          onTap: onSort,
        ),
        const SizedBox(width: 8),
        _LayoutToggle(grid: grid, onChanged: onLayout),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HealthTone.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: fieldKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.grid, required this.onChanged});

  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    Widget half(bool isGrid, IconData icon, String tooltip, Key key) {
      final on = isGrid == grid;
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: on,
          label: tooltip,
          child: InkWell(
            key: key,
            onTap: () => onChanged(isGrid),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: on ? t.accent.withValues(alpha: 0.16) : null,
                border: on
                    ? Border.all(color: t.accent.withValues(alpha: 0.70))
                    : null,
              ),
              child: Icon(icon,
                  size: 17, color: on ? t.accent : Colors.white60),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        half(true, LucideIcons.layoutGrid, 'Grid', const Key('pets_grid')),
        half(false, LucideIcons.list, 'List', const Key('pets_list')),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// The pet card
// ---------------------------------------------------------------------------

class _PetCard extends ConsumerWidget {
  const _PetCard({
    required this.pet,
    required this.isActive,
    required this.records,
    required this.onProfile,
    required this.onRecords,
    required this.onReminders,
    required this.onHealth,
    required this.onMore,
    required this.onTraits,
  });

  final Pet pet;
  final bool isActive;
  final int records;
  final VoidCallback onProfile;
  final VoidCallback onRecords;
  final VoidCallback onReminders;
  final VoidCallback onHealth;
  final VoidCallback onMore;
  final VoidCallback onTraits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final age = petAgeLabel(pet.birthDate);
    final hasReminder = pet.id == null
        ? false
        : (ref.watch(remindersForPetProvider(pet.id!)).value?.isNotEmpty ??
            false);
    final hasCheck = pet.id == null
        ? false
        : (ref.watch(healthTimelineProvider(pet.id!)).value ??
                const <TimelineItem>[])
            .any((i) => i.kind == TimelineKind.analysis);
    final score =
        careScore(pet, hasCheck: hasCheck, hasReminder: hasReminder);

    return HomeCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 11, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardPortrait(pet: pet, onTap: onProfile),
                const SizedBox(width: 11),
                // Weighted 6:4 rather than two bare Flexibles — an even split
                // squeezes a name that had room, and a fixed score box
                // overflows the row under the em-square test font.
                Flexible(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Weighted shares, and **one** chip on this line. Two
                      // chips plus a name in a ~147dp column does not fit at
                      // readable type: the device clipped "Active" to "A…" and
                      // the test font overflowed the row by 76px. The mockup
                      // only ever draws one chip here, so the F-4 last-check
                      // pill gets its own line below the meta instead.
                      Row(children: [
                        Flexible(
                          flex: 5,
                          child: Text(petDisplayName(pet.name),
                              key: Key('pet_name_${pet.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          // The mockup's "Primary Pet". The app has an *active*
                          // pet — the one Home, Health and the Assistant are
                          // scoped to — and saying "primary" would describe a
                          // relationship the app does not model.
                          Flexible(
                            flex: 4,
                            child: HealthPill(
                              key: const Key('pet_active_chip'),
                              label: 'Active',
                              tint: t.accent,
                              icon: LucideIcons.star,
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      // Species first, then breed: "Labrador" alone is
                      // ambiguous, and this line is the identity row Phase J
                      // pinned. The mockup drops the species; keeping it costs
                      // one word and answers "of what?".
                      _Meta(text: [
                        speciesName(pet.species),
                        if (pet.breed?.trim().isNotEmpty == true)
                          pet.breed!.trim(),
                        if (pet.sex == 'male')
                          'Male'
                        else if (pet.sex == 'female')
                          'Female',
                      ].join(' · ')),
                      _Meta(text: [
                        if (age != null)
                          pet.birthDate == null
                              ? '$age old'
                              : '$age old (${shortDate(pet.birthDate!)})'
                        else
                          'No birthday set',
                        if (pet.weightKg != null) '${_kg(pet.weightKg!)} kg',
                      ].join(' · ')),
                      _Meta(
                          text: records == 0
                              ? 'No records yet'
                              : '$records record${records == 1 ? '' : 's'} on '
                                  'file'),
                      // F-4: the last-check chip, fed by `latestTriageProvider`,
                      // which the analysis runner invalidates on completion so
                      // it cannot go stale. It carries the ladder's own
                      // safety-locked hue — the one place on this screen where
                      // colour means a triage level, because that is the
                      // meaning the ladder already owns. The mockup has no such
                      // chip; dropping it would take away the only per-pet
                      // health signal on the page.
                      ...switch (ref.watch(latestTriageProvider(pet.id!))) {
                        AsyncData(value: final triage?) => [
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: HealthPill(
                                key: ValueKey('last_check_chip_${pet.id}'),
                                label: actionLabel(triage.level),
                                tint: actionColor(triage.level),
                                icon: LucideIcons.activity,
                              ),
                            ),
                          ],
                        _ => const <Widget>[],
                      },
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 34,
                        child: HealthCircleButton(
                          key: Key('pet_more_${pet.id}'),
                          icon: LucideIcons.ellipsis,
                          tooltip: 'More for ${petDisplayName(pet.name)}',
                          size: 28,
                          onTap: onMore,
                        ),
                      ),
                      _MiniScore(score: score, onTap: onProfile),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              // The mockup tags each pet "Friendly · Playful · Good with
              // kids". No column for a trait, so the row keeps its place as an
              // invitation rather than three invented ones.
              child: HealthActionPill(
                key: Key('pet_traits_${pet.id}'),
                label: 'Add traits · Soon',
                icon: LucideIcons.smile,
                color: HealthTone.muted,
                onTap: onTraits,
              ),
            ),
          ),
          Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.06)),
          Row(
            children: [
              _CardAction(
                  fieldKey: Key('pet_action_profile_${pet.id}'),
                  icon: LucideIcons.user,
                  label: 'Profile',
                  onTap: onProfile),
              _divider(),
              _CardAction(
                  fieldKey: Key('pet_action_records_${pet.id}'),
                  icon: LucideIcons.fileText,
                  label: 'Records',
                  onTap: onRecords),
              _divider(),
              _CardAction(
                  fieldKey: Key('pet_action_reminders_${pet.id}'),
                  icon: LucideIcons.bell,
                  label: 'Reminders',
                  onTap: onReminders),
              _divider(),
              _CardAction(
                  fieldKey: Key('pet_action_health_${pet.id}'),
                  icon: LucideIcons.heartPulse,
                  label: 'Health',
                  onTap: onHealth),
              _divider(),
              _CardAction(
                  fieldKey: Key('pet_action_more_${pet.id}'),
                  icon: LucideIcons.ellipsis,
                  label: 'More',
                  onTap: onMore),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _divider() => Container(
        width: 1,
        height: 30,
        color: Colors.white.withValues(alpha: 0.06),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: HealthTone.muted, fontSize: 11.5, height: 1.3)),
      );
}

class _CardPortrait extends StatelessWidget {
  const _CardPortrait({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 78,
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PetPortrait(
                  pet: pet,
                  size: 78,
                  livingAvatar: pet.photoKey == null
                      ? null
                      : LivingPetAvatar(
                          species: pet.species,
                          size: 78,
                          seed: pet.id,
                          photoKey: pet.photoKey,
                        ),
                ),
              ),
            ),
            Positioned(
              right: 3,
              bottom: 3,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: t.accent,
                ),
                child: const Icon(LucideIcons.camera,
                    size: 12, color: Color(0xFF06110A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **D-2.** The mockup's per-pet "Health Score · 92 · Excellent".
class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.score, required this.onTap});

  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Flexible(
                child: Text('Care Score',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: HealthTone.muted, fontSize: 9.5, height: 1.2)),
              ),
              const SizedBox(width: 2),
              const Icon(LucideIcons.chevronRight,
                  size: 11, color: Colors.white54),
            ]),
            Row(children: [
              Icon(LucideIcons.shieldCheck, size: 14, color: t.accent),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$score',
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(careBand(score),
                  maxLines: 1,
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 9.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            key: fieldKey,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: t.accent),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid mode
// ---------------------------------------------------------------------------

class _PetGrid extends StatelessWidget {
  const _PetGrid({
    required this.pets,
    required this.activeId,
    required this.onOpen,
    required this.onMore,
  });

  final List<Pet> pets;
  final String? activeId;
  final ValueChanged<Pet> onOpen;
  final ValueChanged<Pet> onMore;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return GridView.count(
      key: const Key('pets_grid_view'),
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 9,
      mainAxisSpacing: 9,
      childAspectRatio: 0.82,
      children: [
        for (final pet in pets)
          HomeCard(
            key: Key('pet_tile_${pet.id}'),
            radius: 16,
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
            onTap: () => onOpen(pet),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: PetPortrait(
                        pet: pet,
                        size: 140,
                        livingAvatar: pet.photoKey == null
                            ? null
                            : LivingPetAvatar(
                                species: pet.species,
                                size: 140,
                                seed: pet.id,
                                photoKey: pet.photoKey,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(children: [
                  Flexible(
                    child: Text(petDisplayName(pet.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (pet.id == activeId) ...[
                    const SizedBox(width: 4),
                    Icon(LucideIcons.star, size: 12, color: t.accent),
                  ],
                ]),
                const SizedBox(height: 1),
                Text(
                  [
                    if (pet.breed?.trim().isNotEmpty == true)
                      pet.breed!.trim()
                    else
                      speciesName(pet.species),
                    ?petAgeLabel(pet.birthDate),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: HealthTone.muted, fontSize: 11, height: 1.25),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

String _kg(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _InviteFamilyCard extends StatelessWidget {
  const _InviteFamilyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HealthAddCard(
      key: const Key('pets_invite_family'),
      icon: LucideIcons.userPlus,
      title: 'Invite Family Members · Soon',
      subtitle: 'Share pet profiles and look after them together.',
      onTap: onTap,
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
      decoration: BoxDecoration(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: HealthTone.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

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

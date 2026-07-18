import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../core/dates.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import '../notifications/local_notifications.dart';
import '../reminders/reminder.dart';
import '../reminders/reminders_repository.dart';
import 'health_event.dart';
import 'health_events_repository.dart';
import 'timeline.dart';

/// Quick-add for a manual health event (vaccination, vet visit, medication,
/// weight, note). Inserts into `health_events` (RLS-scoped via the parent pet),
/// fires `health_event_logged`, then refreshes the timeline so the new entry
/// appears immediately.
class HealthEventFormScreen extends ConsumerStatefulWidget {
  const HealthEventFormScreen({super.key, required this.petId, required this.petName});

  final String petId;
  final String petName;

  @override
  ConsumerState<HealthEventFormScreen> createState() => _HealthEventFormScreenState();
}

class _HealthEventFormScreenState extends ConsumerState<HealthEventFormScreen> {
  String _type = kHealthEventTypes.first;
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  final _weight = TextEditingController();
  // E7: structured vaccination — name + optional next-due (auto-reminder).
  final _vaccineName = TextEditingController();
  DateTime? _vaccineNextDue;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _notes.dispose();
    _weight.dispose();
    _vaccineName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    Map<String, dynamic>? metadata;
    if (_type == 'weight') {
      final kg = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
      if (kg != null) metadata = {'weight_kg': kg};
    }
    if (_type == 'vaccination') {
      final name = _vaccineName.text.trim();
      metadata = {
        if (name.isNotEmpty) 'vaccine_name': name,
        if (_vaccineNextDue != null)
          'next_due':
              _vaccineNextDue!.toIso8601String().split('T').first,
      };
      if (metadata.isEmpty) metadata = null;
    }
    final event = HealthEvent(
      petId: widget.petId,
      eventType: _type,
      eventDate: _date,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      metadata: metadata,
    );
    try {
      await ref.read(healthEventsRepositoryProvider).create(event);
      // E7: a vaccination with a next-due date auto-creates the reminder (and
      // its on-device notification) — the record drives the retention spine.
      if (_type == 'vaccination' && _vaccineNextDue != null) {
        final label = _vaccineName.text.trim().isEmpty
            ? 'Vaccine due'
            : 'Vaccine: ${_vaccineName.text.trim()}';
        try {
          await ref.read(localNotificationsProvider).ensurePermission();
          await ref.read(remindersRepositoryProvider).create(
                Reminder(
                    petId: widget.petId,
                    reminderType: label,
                    dueDate: _vaccineNextDue!),
                petName: widget.petName,
              );
          await Analytics.reminderSet('vaccination_next_due');
        } catch (_) {
          // The event saved; a reminder hiccup must not fail the flow.
        }
      }
      await Analytics.healthEventLogged(_type);
      ref.invalidate(healthTimelineProvider(widget.petId));
      if (!mounted) return;
      // M3 (#16): one 300ms check-morph beat on the button before closing —
      // completion feel without delaying navigation meaningfully; skipped
      // entirely under reduce-motion.
      if (!reduceMotion(context)) {
        setState(() => _saved = true);
        await Future<void>.delayed(const Duration(milliseconds: 320));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the event. Please try again.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Log event · ${petDisplayName(widget.petName)}',
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink50),
          ),
          iconTheme: const IconThemeData(color: AppColors.ink50),
        ),
        // ── Save CTA pinned at the bottom (matches mockups; always in-tree
        // so find.byKey('event_save_button') resolves in tests without scrolling)
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s8,
            AppSpace.s16,
            MediaQuery.of(context).padding.bottom + AppSpace.s16,
          ),
          child: SizedBox(
            width: double.infinity,
            child: PawPrimaryButton(
              key: const Key('event_save_button'),
              onPressed: (_saving || _saved) ? null : _save,
              icon: Icons.save_alt_rounded,
              child: AnimatedSwitcher(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: _saved
                    ? const Row(
                        key: ValueKey('saved'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Saved'),
                        ],
                      )
                    : Text(_saving ? 'Saving…' : 'Save event',
                        key: ValueKey(_saving)),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s16),
          children: [
            // Subtitle
            Text(
              'Keep your pet\'s health history up to date',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.ink300),
            ),
            const SizedBox(height: AppSpace.s20),

            // ── Type selector ──────────────────────────────────────────────
            Text(
              'Type',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpace.s12),
            _TypeGrid(
              selected: _type,
              onSelected: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppSpace.s20),

            // ── Vaccination tip card (screen 21) ───────────────────────────
            if (_type == 'vaccination') ...[
              _VaccinationTipCard(theme: theme),
              const SizedBox(height: AppSpace.s20),
            ],

            // ── Date row ──────────────────────────────────────────────────
            Text(
              'Date',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpace.s8),
            PawCard(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(now.year - 20),
                  lastDate: now,
                );
                if (picked != null) setState(() => _date = picked);
              },
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16, vertical: AppSpace.s12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 20, color: PawPalette.mint),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Text(
                      shortDate(_date),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.ink50),
                    ),
                  ),
                  const Icon(Icons.calendar_month_outlined,
                      size: 18, color: AppColors.ink300),
                ],
              ),
            ),

            // ── Weight field (weight type only) ───────────────────────────
            if (_type == 'weight') ...[
              const SizedBox(height: AppSpace.s16),
              _DarkTextField(
                fieldKey: const Key('event_weight_field'),
                controller: _weight,
                labelText: 'Weight (kg)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],

            // ── Vaccine + Next due (vaccination type only) ────────────────
            if (_type == 'vaccination') ...[
              const SizedBox(height: AppSpace.s16),
              Text(
                'Vaccine',
                style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.ink50, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpace.s8),
              _DarkTextField(
                fieldKey: const Key('event_vaccine_name_field'),
                controller: _vaccineName,
                labelText: 'Vaccine name (e.g. Rabies, DHPP)',
                prefixIcon: Icons.edit_outlined,
              ),
              const SizedBox(height: AppSpace.s16),
              Text(
                'Next due (optional)',
                style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.ink50, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpace.s8),
              PawCard(
                key: const Key('event_vaccine_next_due'),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _vaccineNextDue ??
                        now.add(const Duration(days: 365)),
                    firstDate: now,
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) {
                    setState(() => _vaccineNextDue = picked);
                  }
                },
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16, vertical: AppSpace.s12),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 20, color: PawPalette.mint),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Text(
                        _vaccineNextDue == null
                            ? 'Select next due date — sets a reminder'
                            : 'Next due: ${_vaccineNextDue!.toIso8601String().split('T').first} (reminder will be set)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: _vaccineNextDue == null
                                ? AppColors.ink300
                                : AppColors.ink50),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppColors.ink300),
                  ],
                ),
              ),
            ],

            // ── Notes ─────────────────────────────────────────────────────
            const SizedBox(height: AppSpace.s20),
            Text(
              'Notes (optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpace.s8),
            _NotesField(controller: _notes),

            // ── Tip card (generic: shown when not vaccination) ─────────────
            if (_type != 'vaccination') ...[
              const SizedBox(height: AppSpace.s16),
              _GenericTipCard(theme: theme),
            ],

            const SizedBox(height: AppSpace.s8),
          ],
        ),
      ),
    );
  }

}

// ── Private sub-widgets ──────────────────────────────────────────────────────

/// 2-column selectable grid of event-type tiles.
class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpace.s8,
      mainAxisSpacing: AppSpace.s8,
      childAspectRatio: 2.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final t in kHealthEventTypes)
          _TypeTile(
            type: t,
            isSelected: selected == t,
            onTap: () => onSelected(t),
          ),
      ],
    );
  }
}

/// Single selectable event-type tile: mint border when selected.
class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final String type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _healthEventIcon(type);
    final label = healthEventLabel(type);
    final sublabel = _sublabel(type);

    final borderColor =
        isSelected ? PawPalette.mint : Colors.white.withValues(alpha: 0.07);
    final bgColor = isSelected
        ? PawPalette.teal.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.045);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12, vertical: AppSpace.s8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PawPalette.teal.withValues(alpha: isSelected ? 0.28 : 0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon,
                  size: 18,
                  color: isSelected ? PawPalette.mint : AppColors.ink300),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected ? PawPalette.mint : AppColors.ink50,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sublabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.ink300, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sublabel(String type) => switch (type) {
        'vaccination' => 'Track vaccines',
        'vet_visit' => 'Checkups & exams',
        'medication' => 'Medicine & dosage',
        'weight' => 'Track weight changes',
        _ => 'General notes & others',
      };
}

/// Tip card shown only for vaccination (screen 21) with the dog+shield art.
class _VaccinationTipCard extends StatelessWidget {
  const _VaccinationTipCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return PawCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PawPalette.teal.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined,
                size: 26, color: PawPalette.mint),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vaccinations help protect your pet from serious diseases and keep them happy and healthy.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.ink300),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  'Learn more',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: PawPalette.mint, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic tip card at the bottom (screen 17).
class _GenericTipCard extends StatelessWidget {
  const _GenericTipCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return PawCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s8),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: PawPalette.mint),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              'Tip: Adding details helps you and your vet understand your pet\'s health better.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.ink300),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark-styled text field matching the new teal-green world (border radius,
/// surface tint, mint focus). Used for weight and vaccine name inputs.
class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.fieldKey,
    required this.controller,
    required this.labelText,
    this.keyboardType,
    this.prefixIcon,
  });

  final Key? fieldKey;
  final TextEditingController? controller;
  final String labelText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.ink50),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppColors.ink300),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.ink300, size: 20)
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.045),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
              color: PawPalette.mint, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

/// Notes textarea with a 0/500 character counter.
class _NotesField extends StatefulWidget {
  const _NotesField({required this.controller});
  final TextEditingController controller;

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _count = widget.controller.text.length);

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextField(
          key: const Key('event_notes_field'),
          controller: widget.controller,
          maxLines: 5,
          maxLength: 500,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              const SizedBox.shrink(),
          style: const TextStyle(color: AppColors.ink50),
          decoration: InputDecoration(
            hintText: 'Add any details about this event…',
            hintStyle: const TextStyle(color: AppColors.ink300),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: AppSpace.s12, top: AppSpace.s12),
              child: Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.ink300),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 0),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.045),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.07)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: PawPalette.mint, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        Positioned(
          bottom: AppSpace.s8,
          right: AppSpace.s12,
          child: Text(
            '$_count/500',
            style: const TextStyle(
                color: AppColors.ink300, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// Top-level helper so _TypeTile can call it without accessing private state.
IconData _healthEventIcon(String type) => switch (type) {
      'vaccination' => Icons.vaccines_outlined,
      'vet_visit' => Icons.local_hospital_outlined,
      'medication' => Icons.medication_outlined,
      'weight' => Icons.monitor_weight_outlined,
      _ => Icons.note_alt_outlined,
    };

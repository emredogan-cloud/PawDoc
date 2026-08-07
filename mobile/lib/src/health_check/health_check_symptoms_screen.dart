import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../analysis/analysis_runner.dart';
import '../emergency/emergency_help_screen.dart';
import '../emergency/emergency_keywords.dart';
import '../home/home_sections.dart';
import '../pets/pet.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import '../theme/ui_assets.dart';
import 'health_check_chrome.dart';

/// One selectable observation. The label is what the **owner** can see, never
/// a condition — the whole grid is deliberately phrased that way.
typedef SymptomOption = ({String key, String label, IconData fallback});

/// The twelve the mockup draws, then the rest behind "Show more".
const _commonSymptoms = <SymptomOption>[
  (key: 'skinIrritation', label: 'Skin irritation\nor redness', fallback: LucideIcons.sparkle),
  (key: 'itching', label: 'Itching\nor scratching', fallback: LucideIcons.hand),
  (key: 'earProblem', label: 'Ear problems\n(head shaking)', fallback: LucideIcons.ear),
  (key: 'eyeDischarge', label: 'Eye discharge\nor redness', fallback: LucideIcons.eye),
  (key: 'coughing', label: 'Coughing', fallback: LucideIcons.wind),
  (key: 'sneezing', label: 'Sneezing', fallback: LucideIcons.wind),
  (key: 'vomiting', label: 'Vomiting', fallback: LucideIcons.circleAlert),
  (key: 'diarrhea', label: 'Diarrhea', fallback: LucideIcons.droplets),
  (key: 'appetiteLoss', label: 'Loss of appetite', fallback: LucideIcons.utensils),
  (key: 'lethargy', label: 'Lethargy\nor tiredness', fallback: LucideIcons.moon),
  (key: 'limping', label: 'Limping\nor lameness', fallback: LucideIcons.bone),
  (key: 'bloating', label: 'Bloating', fallback: LucideIcons.circle),
];

const _moreSymptoms = <SymptomOption>[
  (key: 'breathingDifficulty', label: 'Breathing\ndifficulty', fallback: LucideIcons.wind),
  (key: 'bleeding', label: 'Bleeding', fallback: LucideIcons.droplet),
  (key: 'swelling', label: 'Swelling', fallback: LucideIcons.circleDot),
  (key: 'excessiveThirst', label: 'Excessive thirst', fallback: LucideIcons.cupSoda),
  (key: 'urinationChange', label: 'Urination\nchanges', fallback: LucideIcons.droplets),
  (key: 'weightLoss', label: 'Weight loss', fallback: LucideIcons.trendingDown),
  (key: 'hairLoss', label: 'Hair loss', fallback: LucideIcons.scissors),
  (key: 'badBreath', label: 'Bad breath', fallback: LucideIcons.wind),
  (key: 'behaviourChange', label: 'Behaviour\nchanges', fallback: LucideIcons.brain),
  (key: 'disorientation', label: 'Disorientation', fallback: LucideIcons.compass),
  (key: 'painResponse', label: 'Pain response', fallback: LucideIcons.zap),
  (key: 'seizure', label: 'Seizure', fallback: LucideIcons.activity),
];

/// Step 3 of the AI Health Check (mockup `symptom_selection`).
///
/// **Safety.** The mockup's deck says the details help the AI *"understand your
/// pet's condition better"*. The owner reports observations; the product never
/// asserts a condition, and the copy must not imply one is being established.
/// Everything else — the grid, the search, the onset and notes rows — is the
/// mockup as drawn.
///
/// The offline emergency router runs on the assembled description before any
/// network call, exactly as the text path does: a keyword match lands on the
/// red help screen instantly, and a dead zone can never turn "my dog is
/// choking" into a spinner.
class HealthCheckSymptomsScreen extends ConsumerStatefulWidget {
  const HealthCheckSymptomsScreen({
    required this.pet,
    required this.isPremium,
    this.imageStorageKey,
    super.key,
  });

  final Pet pet;
  final bool isPremium;
  final String? imageStorageKey;

  @override
  ConsumerState<HealthCheckSymptomsScreen> createState() =>
      _HealthCheckSymptomsScreenState();
}

class _HealthCheckSymptomsScreenState
    extends ConsumerState<HealthCheckSymptomsScreen> {
  final _selected = <String>{};
  final _search = TextEditingController();
  final _notes = TextEditingController();
  bool _showMore = false;
  String? _onset;

  static const _onsets = [
    'Today',
    'Yesterday',
    'A few days ago',
    'Over a week ago',
  ];

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<SymptomOption> get _visible {
    final all = [..._commonSymptoms, if (_showMore) ..._moreSymptoms];
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      ..._commonSymptoms,
      ..._moreSymptoms,
    ].where((o) => o.label.toLowerCase().replaceAll('\n', ' ').contains(q)).toList();
  }

  /// What the pipeline receives: the owner's own words, assembled.
  String _describe() {
    final labels = [
      ..._commonSymptoms,
      ..._moreSymptoms,
    ].where((o) => _selected.contains(o.key)).map((o) => o.label.replaceAll('\n', ' '));
    final parts = <String>[
      if (labels.isNotEmpty) 'Observed: ${labels.join(', ')}.',
      if (_onset != null) 'First noticed: $_onset.',
      if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
    ];
    return parts.join(' ');
  }

  Future<void> _continue() async {
    final description = _describe();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick at least one thing you have noticed, or add a '
              'note.')));
      return;
    }

    // OFFLINE EMERGENCY ROUTER — client-side, before any network call.
    final locale = Localizations.maybeLocaleOf(context)?.languageCode;
    final matched = matchEmergencyKeyword(description,
        species: widget.pet.species, locale: locale);
    if (matched != null) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EmergencyHelpScreen(matchedKeyword: matched)));
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnalysisRunnerScreen(
        petId: widget.pet.id!,
        petName: widget.pet.name,
        petSpecies: widget.pet.species,
        inputType: widget.imageStorageKey == null ? 'text' : 'photo',
        textDescription: description,
        imageStorageKey: widget.imageStorageKey,
        isPremium: widget.isPremium,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HealthCheckScaffold(
      body: [
        const HealthCheckSteps(current: 2, steps: healthCheckSteps4),
        const SizedBox(height: AppSpace.s24),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'What seems to be '),
            TextSpan(text: 'wrong?', style: TextStyle(color: t.accent)),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 6),
                child:
                    Icon(LucideIcons.sparkles, size: 20, color: Colors.white),
              ),
            ),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: AppSpace.s12),
        // The mockup says these details help the AI understand your pet's
        // "condition". The owner reports what they can see; no condition is
        // being established here or anywhere else.
        const Text(
            'Select all that apply. This helps our AI understand what you are '
            'seeing.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF9BA5A0), fontSize: 14, height: 1.4)),
        const SizedBox(height: AppSpace.s16),
        HomeCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PetThumb(pet: widget.pet, hasPhoto: widget.imageStorageKey != null),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Analyzing for '),
                            TextSpan(
                                text: widget.pet.name,
                                style: TextStyle(color: t.accent)),
                          ]),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10160F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.info, size: 16, color: t.accent),
                              const SizedBox(width: 7),
                              const Expanded(
                                child: Text(
                                    'These details are used only for this '
                                    'health check and are never stored with '
                                    'your photo.',
                                    style: TextStyle(
                                        color: Color(0xFFB8C2BB),
                                        fontSize: 12,
                                        height: 1.35)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s16),
              TextField(
                key: const Key('symptom_search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF10160F),
                  hintText: 'Search symptoms…',
                  hintStyle:
                      const TextStyle(color: Color(0xFF6C766F), fontSize: 14),
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 18, color: Color(0xFF8A948D)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              Row(children: [
                Icon(LucideIcons.stethoscope, size: 17, color: t.accent),
                const SizedBox(width: 7),
                Text(
                    _search.text.trim().isEmpty
                        ? 'Common Symptoms'
                        : 'Matching symptoms',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: AppSpace.s12),
              LayoutBuilder(builder: (context, c) {
                const gap = 8.0;
                final w = (c.maxWidth - gap * 3) / 4;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final o in _visible)
                      SizedBox(
                        width: w,
                        // Fixed height: `Wrap` sizes each child on its own, so
                        // a two-line label next to a three-line one gave the
                        // mockup's even grid ragged rows.
                        height: 104,
                        child: _SymptomTile(
                          option: o,
                          selected: _selected.contains(o.key),
                          onTap: () => setState(() => _selected.contains(o.key)
                              ? _selected.remove(o.key)
                              : _selected.add(o.key)),
                        ),
                      ),
                  ],
                );
              }),
              if (_search.text.trim().isEmpty) ...[
                const SizedBox(height: AppSpace.s12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('symptom_show_more'),
                    onPressed: () => setState(() => _showMore = !_showMore),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            _showMore
                                ? 'Show fewer symptoms'
                                : 'Show more symptoms',
                            style: const TextStyle(
                                color: Color(0xFFB8C2BB), fontSize: 14.5)),
                        const SizedBox(width: 6),
                        Icon(
                            _showMore
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 18,
                            color: const Color(0xFFB8C2BB)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        HomeCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(LucideIcons.notebookPen, size: 17, color: t.accent),
                const SizedBox(width: 7),
                const Text('Additional Information (Optional)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: AppSpace.s12),
              _DetailRow(
                icon: LucideIcons.calendarDays,
                label: 'When did you first notice this?',
                value: _onset ?? 'Select',
                onTap: _pickOnset,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: LucideIcons.fileText,
                label: 'Any additional notes?',
                value: _notes.text.trim().isEmpty ? 'Add notes' : 'Edit',
                onTap: _editNotes,
              ),
              if (_notes.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_notes.text.trim(),
                    style: const TextStyle(
                        color: Color(0xFF9BA5A0), fontSize: 13, height: 1.35)),
              ],
            ],
          ),
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PawPrimaryButton(
            key: const Key('health_check_symptoms_continue'),
            onPressed: _continue,
            child: const Text('Continue'),
          ),
          const SizedBox(height: AppSpace.s12),
          const HealthCheckDisclaimer(),
        ],
      ),
    );
  }

  Future<void> _pickOnset() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0A0F0B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpace.s12),
            for (final o in _onsets)
              ListTile(
                title: Text(o, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(sheet).pop(o),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _onset = picked);
  }

  Future<void> _editNotes() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0F0B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Anything else you have noticed?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpace.s12),
                TextField(
                  key: const Key('symptom_notes'),
                  controller: _notes,
                  maxLines: 4,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF10160F),
                    hintText: 'In your own words…',
                    hintStyle: const TextStyle(color: Color(0xFF6C766F)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                PawPrimaryButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _PetThumb extends StatelessWidget {
  const _PetThumb({required this.pet, required this.hasPhoto});

  final Pet pet;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: 108,
      height: 118,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                AppAssets.species(pet.species),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF141B14)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.pencil, size: 13, color: t.accent),
                  const SizedBox(width: 5),
                  Text(hasPhoto ? 'Edit Photo' : 'No photo',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SymptomTile extends StatelessWidget {
  const _SymptomTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SymptomOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final asset = UiAssets.symptom(option.key);
    return Semantics(
      button: true,
      selected: selected,
      label: option.label.replaceAll('\n', ' '),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? t.accent.withValues(alpha: 0.07)
                      : const Color(0xFF10160F),
                  border: Border.all(
                    color: selected
                        ? t.accent
                        : Colors.white.withValues(alpha: 0.08),
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: t.accent.withValues(alpha: 0.26),
                              blurRadius: 16,
                              spreadRadius: -4)
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 30,
                      child: asset == null
                          ? Icon(option.fallback, size: 24, color: t.accent)
                          : Image.asset(
                              asset,
                              height: 28,
                              color: t.accent,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) => Icon(option.fallback,
                                  size: 24, color: t.accent),
                            ),
                    ),
                    const SizedBox(height: 7),
                    Flexible(
                      child: Text(option.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              height: 1.2,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: t.accent),
                    child: const Icon(LucideIcons.check,
                        size: 13, color: Color(0xFF06140A)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Material(
      color: const Color(0xFF10160F),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
              ),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF8A948D), fontSize: 13.5)),
              const Icon(LucideIcons.chevronRight,
                  size: 17, color: Color(0xFF8A948D)),
            ],
          ),
        ),
      ),
    );
  }
}

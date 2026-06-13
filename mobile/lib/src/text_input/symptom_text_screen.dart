import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/motion.dart';
import '../core/pet_display.dart';
import '../theme/design_tokens.dart';

/// Text symptom input with character guidance. Phase 1.2 stops at producing the
/// input text — it pops the trimmed description back to the caller (the AI call
/// is wired in Phase 1.4). No AI logic here.
///
/// Phase G polish: example chips that seed the field, and an animated
/// "Looks good." affirmation (reduce-motion-gated). The min-character gate and
/// the popped value are unchanged.
class SymptomTextScreen extends StatefulWidget {
  const SymptomTextScreen({super.key, this.petName});

  final String? petName;

  static const int minChars = 12;
  static const int maxChars = 1000;
  // GAP-E16 safety net: a short message naming a critical sign must NEVER be
  // blocked by the min-length gate (the server still runs the authoritative
  // hardcoded emergency override). Stems catch variants — "choking",
  // "he's choking", "can't breathe".
  static const List<String> emergencyHints = [
    'chok', 'breath', 'seizur', 'convuls', 'collaps', 'unconscious',
    'not moving', 'bloat', 'blue gum', 'pale gum', 'bleeding', 'blood',
    'poison', 'hit by', "won't wake", 'wont wake', 'limp body', 'gasping',
  ];
  static const List<String> examples = [
    'Vomiting',
    'Diarrhea',
    'Limping',
    'Not eating',
    'Lethargic',
  ];

  @override
  State<SymptomTextScreen> createState() => _SymptomTextScreenState();
}

class _SymptomTextScreenState extends State<SymptomTextScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addExample(String word) {
    final current = _controller.text.trim();
    _controller.text =
        current.isEmpty ? word : '$current, ${word.toLowerCase()}';
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final len = _controller.text.trim().length;
    // GAP-E16: never block a short emergency phrase ("choking" = 7 chars).
    final looksEmergency = SymptomTextScreen.emergencyHints
        .any(_controller.text.toLowerCase().contains);
    final tooShort = len < SymptomTextScreen.minChars && !looksEmergency;
    final who = petDisplayName(widget.petName);

    return Scaffold(
      appBar: AppBar(title: const Text('Describe what you see')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What’s going on with $who? Include when it started, any changes in '
              'eating, energy, or behavior, and anything unusual you’ve noticed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final ex in SymptomTextScreen.examples)
                  ActionChip(
                    label: Text(ex),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: () => _addExample(ex),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            TextField(
              key: const Key('symptom_text_field'),
              controller: _controller,
              maxLines: 6,
              maxLength: SymptomTextScreen.maxChars,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                hintText: 'e.g. Since this morning she’s been very tired and hasn’t eaten…',
              ),
            ),
            tooShort
                ? Text(
                    'Add a little more detail (at least ${SymptomTextScreen.minChars} characters).',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                : _looksGood(),
            const Spacer(),
            AppButton(
              key: const Key('symptom_continue_button'),
              onPressed: tooShort
                  ? null
                  : () => Navigator.of(context).pop(_controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _looksGood() {
    final scheme = Theme.of(context).colorScheme;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
        const SizedBox(width: AppSpace.s4),
        Text('Looks good.', style: TextStyle(color: scheme.primary)),
      ],
    );
    if (reduceMotion(context)) return row;
    return row
        .animate()
        .fadeIn(duration: AppMotion.micro)
        .slideY(begin: 0.4, end: 0, duration: AppMotion.standard, curve: AppMotion.emphasized);
  }
}

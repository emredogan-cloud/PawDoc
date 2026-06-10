import 'package:flutter/material.dart';

import '../core/pet_display.dart';

/// Text symptom input with character guidance. Phase 1.2 stops at producing the
/// input text — it pops the trimmed description back to the caller (the AI call
/// is wired in Phase 1.4). No AI logic here.
class SymptomTextScreen extends StatefulWidget {
  const SymptomTextScreen({super.key, this.petName});

  final String? petName;

  static const int minChars = 20;
  static const int maxChars = 1000;

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

  @override
  Widget build(BuildContext context) {
    final len = _controller.text.trim().length;
    final tooShort = len < SymptomTextScreen.minChars;
    final who = petDisplayName(widget.petName);

    return Scaffold(
      appBar: AppBar(title: const Text('Describe what you see')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What’s going on with $who? Include when it started, any changes in '
              'eating, energy, or behavior, and anything unusual you’ve noticed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('symptom_text_field'),
              controller: _controller,
              maxLines: 6,
              maxLength: SymptomTextScreen.maxChars,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. Since this morning she’s been very tired and hasn’t eaten…',
              ),
            ),
            Text(
              tooShort
                  ? 'Add a little more detail (at least ${SymptomTextScreen.minChars} characters).'
                  : 'Looks good.',
              style: TextStyle(
                color: tooShort
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const Spacer(),
            FilledButton(
              key: const Key('symptom_continue_button'),
              onPressed: tooShort ? null : () => Navigator.of(context).pop(_controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

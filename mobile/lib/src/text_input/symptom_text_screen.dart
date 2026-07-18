import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_image.dart';
import '../core/connectivity.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../theme/app_theme.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// Text symptom input with character guidance. Phase 1.2 stops at producing the
/// input text — it pops the trimmed description back to the caller (the AI call
/// is wired in Phase 1.4). No AI logic here.
///
/// Phase G polish: example chips that seed the field, and an animated
/// "Looks good." affirmation (reduce-motion-gated). The min-character gate and
/// the popped value are unchanged.
///
/// NEW UI translation (2026-06-12): restyled to the teal-green world design
/// per mockup 16. All logic (TextEditingController, char-gating, chip insertion,
/// Navigator.pop value) is PRESERVED EXACTLY.
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
  bool _helperExpanded = false;

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
    final theme = Theme.of(context);

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Describe what you see',
            style: TextStyle(color: AppColors.ink50, fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: AppColors.ink50),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s16, vertical: AppSpace.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // QA-06: surface offline BEFORE the user types and
                      // submits into a spinner (the emergency router still
                      // works fully offline).
                      const OfflineBanner(),
                      // ── Hero row: headline + puppy illustration ──────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AppColors.ink50,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                children: [
                                  const TextSpan(text: 'The more details,\n'),
                                  TextSpan(
                                    text: 'the better we can help',
                                    style: TextStyle(
                                      color: PawPalette.mint,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.s8),
                          AppImage(
                            AppAssets.cameraGuidance,
                            height: 96,
                            fallback: const Icon(
                              Icons.pets_rounded,
                              size: 64,
                              color: PawPalette.mint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        "Include when it started, any changes in eating, energy, or "
                        "behavior, and anything unusual you've noticed.",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.ink300),
                      ),
                      const SizedBox(height: AppSpace.s16),

                      // ── Chips ─────────────────────────────────────────────
                      Text(
                        'Common issues (tap any that apply)',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: AppColors.ink300),
                      ),
                      const SizedBox(height: AppSpace.s8),
                      Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: [
                          for (final ex in SymptomTextScreen.examples)
                            _SymptomChip(
                              label: ex,
                              onPressed: () => _addExample(ex),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s16),

                      // ── Text field ────────────────────────────────────────
                      PawCard(
                        padding: EdgeInsets.zero,
                        radius: AppRadius.md,
                        child: TextField(
                          key: const Key('symptom_text_field'),
                          controller: _controller,
                          maxLines: 6,
                          maxLength: SymptomTextScreen.maxChars,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.ink50),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.all(AppSpace.s16),
                            hintText: 'Tell us in your own words…',
                            hintStyle: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.ink300),
                            counterStyle: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.ink300),
                          ),
                        ),
                      ),

                      // ── Validation feedback ───────────────────────────────
                      const SizedBox(height: AppSpace.s4),
                      tooShort
                          ? Text(
                              'Add a little more detail (at least ${SymptomTextScreen.minChars} characters).',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12),
                            )
                          : _looksGood(),
                      const SizedBox(height: AppSpace.s16),

                      // ── Helper expand ─────────────────────────────────────
                      _HelperExpander(
                        expanded: _helperExpanded,
                        onToggle: () =>
                            setState(() => _helperExpanded = !_helperExpanded),
                        petName: who,
                      ),
                      const SizedBox(height: AppSpace.s12),

                      // ── Privacy card ──────────────────────────────────────
                      PawCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s16,
                            vertical: AppSpace.s12),
                        radius: AppRadius.md,
                        child: Row(
                          children: [
                            const Icon(Icons.shield_rounded,
                                size: 20, color: PawPalette.mint),
                            const SizedBox(width: AppSpace.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your privacy is our priority.',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: AppColors.ink50),
                                  ),
                                  Text(
                                    'What you share is encrypted and secure.',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: AppColors.ink300),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.lock_rounded,
                                size: 16, color: AppColors.ink300),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.s24),
                    ],
                  ),
                ),
              ),

              // ── CTA pinned to bottom ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s16),
                child: PawPrimaryButton(
                  key: const Key('symptom_continue_button'),
                  onPressed: tooShort
                      ? null
                      : () => Navigator.of(context).pop(_controller.text.trim()),
                  icon: Icons.auto_awesome_rounded,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
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
        .slideY(
            begin: 0.4,
            end: 0,
            duration: AppMotion.standard,
            curve: AppMotion.emphasized);
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

/// Teal-outlined chip in the new design language. Tap-to-insert only.
class _SymptomChip extends StatelessWidget {
  const _SymptomChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
                color: PawPalette.mint.withValues(alpha: 0.45), width: 1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12, vertical: AppSpace.s8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 14, color: PawPalette.mint),
                const SizedBox(width: AppSpace.s4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.ink50,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable "Not sure what to include?" helper block.
class _HelperExpander extends StatelessWidget {
  const _HelperExpander({
    required this.expanded,
    required this.onToggle,
    required this.petName,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String petName;

  static const List<String> _prompts = [
    'When did it start?',
    "What's different from normal?",
    'Has anything helped or made it worse?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PawCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16, vertical: AppSpace.s12),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded,
                      size: 18, color: PawPalette.mint),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Not sure what to include?',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: AppColors.ink50),
                        ),
                        Text(
                          'Try these helpful prompts.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.ink300),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.ink300,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.07)),
            for (final prompt in _prompts)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16, vertical: AppSpace.s8),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: AppColors.ink300),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        prompt,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.ink50),
                      ),
                    ),
                    // These are things to think about and answer in your own
                    // words — not snippets to insert, so no "+" affordance
                    // (RC UX: the icon implied a tap action that did nothing).
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

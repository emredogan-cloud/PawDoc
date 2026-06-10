import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'breed_insights.dart';

/// A tappable card showing a rotating, breed-specific wellness tip for the
/// active pet. Rotates daily; tap to cycle to the next tip. Informational only —
/// never a diagnosis (see breed_insights.dart). Give it a per-pet [Key] so the
/// content resets cleanly when the user switches pets.
class BreedInsightCard extends StatefulWidget {
  const BreedInsightCard({super.key, required this.species, this.breed});

  final String species;
  final String? breed;

  @override
  State<BreedInsightCard> createState() => _BreedInsightCardState();
}

class _BreedInsightCardState extends State<BreedInsightCard> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final insight =
        rotatingInsight(breed: widget.breed, species: widget.species, offset: _offset);
    final scheme = Theme.of(context).colorScheme;
    final hasBreed = widget.breed != null && widget.breed!.trim().isNotEmpty;
    return Card(
      color: scheme.secondaryContainer,
      child: InkWell(
        key: const Key('breed_insight_card'),
        borderRadius: AppRadius.brMd,
        onTap: () => setState(() => _offset++),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.refresh, size: 18, color: scheme.onSecondaryContainer),
                ],
              ),
              const SizedBox(height: 8),
              Text(insight.body),
              const SizedBox(height: 4),
              Text(
                hasBreed ? 'For ${widget.breed}' : 'General ${widget.species} tip',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

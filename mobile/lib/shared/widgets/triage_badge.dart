/// Visual representation of a triage level: a color, a label, and an icon.
/// Always paired together — color alone is not a sufficient signal.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/analysis_result.dart';

class TriageBadge extends StatelessWidget {
  const TriageBadge({super.key, required this.level, this.large = false});

  final TriageLevel level;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = _color(level);
    final icon = _icon(level);
    final label = level.displayName.toUpperCase();

    final padding = large
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final spacing = large ? 12.0 : 6.0;
    final iconSize = large ? 28.0 : 18.0;
    final textStyle =
        (large
                ? Theme.of(context).textTheme.titleLarge
                : Theme.of(context).textTheme.labelLarge)
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(large ? 16 : 10),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: iconSize),
            SizedBox(width: spacing),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }

  static Color _color(TriageLevel level) => switch (level) {
    TriageLevel.emergency => AppTheme.triageEmergency,
    TriageLevel.monitor => AppTheme.triageMonitor,
    TriageLevel.normal => AppTheme.triageNormal,
  };

  static IconData _icon(TriageLevel level) => switch (level) {
    TriageLevel.emergency => Icons.warning_amber_rounded,
    TriageLevel.monitor => Icons.visibility_outlined,
    TriageLevel.normal => Icons.check_circle_outline,
  };
}

/// Canonical disclaimer copy + a small widget that renders it.
///
/// The AI service returns its own `disclaimer_text` on every analysis
/// (Phase 1B + 1C). That value is the authoritative source. The fallback
/// here is for:
///   - the capture screen, which renders before any analysis exists
///   - the result screen's safety net when `disclaimer_text` is empty
///
/// Wording is matched verbatim to the AI service's Pydantic default at
/// `ai-service/app/models/schemas.py::AnalysisResult.disclaimer_text`.
/// If you change one, change both — they are deliberately identical.
library;

import 'package:flutter/material.dart';

/// The canonical disclaimer copy. Used wherever the API-supplied
/// disclaimer is unavailable.
const String kCanonicalDisclaimer =
    'PawDoc provides triage guidance, not a veterinary diagnosis. Always '
    'consult a licensed veterinarian for medical decisions.';

/// Small Text widget that renders the disclaimer with consistent
/// styling (muted, body-small). Pass an explicit [text] to override the
/// canonical copy (e.g., when the API has supplied a region-specific
/// variant).
class DisclaimerCaption extends StatelessWidget {
  const DisclaimerCaption({
    super.key,
    this.text,
    this.textAlign = TextAlign.center,
  });

  final String? text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      (text == null || text!.isEmpty) ? kCanonicalDisclaimer : text!,
      textAlign: textAlign,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

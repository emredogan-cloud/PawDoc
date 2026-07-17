/// M0 fix F-3 — display-side localization for dynamic `AnalysisResult` values
/// on the EMERGENCY screen. The wire contract is FROZEN and stays English
/// (docs/contracts/ANALYSIS_RESULT.md); only presentation is localized here.
///
/// Safety rule: anything we cannot confidently map passes through VERBATIM.
/// Never hide, soften, or reword clinical content on a mixed-language miss.
library;

import '../../l10n/app_localizations.dart';

/// The exact emergency-override template from ai-service/app/safety.py:
/// `f"Emergency indicator detected: '{matched_keyword}'."` — the keyword is
/// already in the user's locale (the keyword lists are per-locale).
final _emergencyIndicatorTemplate =
    RegExp(r"^Emergency indicator detected: '(.+)'\.?$");

/// Localizes the server's templated emergency observation; any other
/// concern text (free-form AI output) is returned unchanged.
String localizedPrimaryConcern(AppLocalizations l, String concern) {
  final match = _emergencyIndicatorTemplate.firstMatch(concern.trim());
  if (match != null) return l.emergencyIndicatorDetected(match.group(1)!);
  return concern;
}

/// Localizes the contract's urgency_timeframe enum-ish values
/// (immediately | within 24 hours | routine); unknown values pass through.
String localizedUrgency(AppLocalizations l, String timeframe) {
  switch (timeframe.trim().toLowerCase()) {
    case 'immediately':
      return l.urgencyImmediately;
    case 'within 24 hours':
      return l.urgencyWithin24Hours;
    case 'routine':
      return l.urgencyRoutine;
  }
  return timeframe;
}

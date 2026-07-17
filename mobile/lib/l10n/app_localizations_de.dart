// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'PawDoc';

  @override
  String get emergencyTitle => 'Das könnte ein Notfall sein';

  @override
  String emergencyRecommendedPrefix(String timeframe) {
    return 'Empfohlen: $timeframe.';
  }

  @override
  String emergencyIndicatorDetected(String indicator) {
    return 'Notfall-Anzeichen erkannt: \'$indicator\'.';
  }

  @override
  String get urgencyImmediately => 'sofort';

  @override
  String get urgencyWithin24Hours => 'innerhalb von 24 Stunden';

  @override
  String get urgencyRoutine => 'routinemäßig';

  @override
  String get emergencyFindVet => 'Sofort einen Notfall-Tierarzt finden';

  @override
  String get emergencyDisclaimer =>
      'PawDoc liefert Informationen, keine Diagnose. Im Notfall sofort einen Tierarzt kontaktieren.';

  @override
  String get resultDisclaimer =>
      'PawDoc liefert Informationen, keine tierärztliche Diagnose. Wenden Sie sich im Zweifel an Ihren Tierarzt.';

  @override
  String get emergencyAcknowledge => 'Mir ist klar, dass dies dringend ist';

  @override
  String get actionContinue => 'Weiter';
}

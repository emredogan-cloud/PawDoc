// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PawDoc';

  @override
  String get emergencyTitle => 'This may be an emergency';

  @override
  String emergencyRecommendedPrefix(String timeframe) {
    return 'Recommended: $timeframe.';
  }

  @override
  String get emergencyFindVet => 'Find an emergency vet now';

  @override
  String get emergencyDisclaimer =>
      'PawDoc provides information, not a diagnosis. In an emergency, contact a veterinarian immediately.';

  @override
  String get emergencyAcknowledge => 'I understand this needs urgent attention';

  @override
  String get actionContinue => 'Continue';

  @override
  String get telehealthTitle => 'Talk to a vet now';

  @override
  String get telehealthSubtitle =>
      'On-demand video consult with a licensed vet.';

  @override
  String get telehealthCta => 'Consult a vet';
}

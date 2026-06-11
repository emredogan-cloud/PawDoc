import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Application name.
  ///
  /// In en, this message translates to:
  /// **'PawDoc'**
  String get appTitle;

  /// Emergency result screen heading (CR #11 safety-critical).
  ///
  /// In en, this message translates to:
  /// **'This may be an emergency'**
  String get emergencyTitle;

  /// Recommended urgency timeframe line on the emergency screen.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {timeframe}.'**
  String emergencyRecommendedPrefix(String timeframe);

  /// M0 F-3: localized wrapper for the server's emergency-override primary_concern template. The quoted indicator is the matched keyword (already in the user's locale — safety.py keyword lists are per-locale) and is never altered.
  ///
  /// In en, this message translates to:
  /// **'Emergency indicator detected: \'{indicator}\'.'**
  String emergencyIndicatorDetected(String indicator);

  /// M0 F-3: display value for the wire urgency_timeframe 'immediately' (contract stays English on the wire).
  ///
  /// In en, this message translates to:
  /// **'immediately'**
  String get urgencyImmediately;

  /// M0 F-3: display value for the wire urgency_timeframe 'within 24 hours'.
  ///
  /// In en, this message translates to:
  /// **'within 24 hours'**
  String get urgencyWithin24Hours;

  /// M0 F-3: display value for the wire urgency_timeframe 'routine'.
  ///
  /// In en, this message translates to:
  /// **'routine'**
  String get urgencyRoutine;

  /// Primary CTA on the emergency screen — safety-critical.
  ///
  /// In en, this message translates to:
  /// **'Find an emergency vet now'**
  String get emergencyFindVet;

  /// Server-injected disclaimer line on EMERGENCY (always shown when required).
  ///
  /// In en, this message translates to:
  /// **'PawDoc provides information, not a diagnosis. In an emergency, contact a veterinarian immediately.'**
  String get emergencyDisclaimer;

  /// Acknowledgment checkbox label.
  ///
  /// In en, this message translates to:
  /// **'I understand this needs urgent attention'**
  String get emergencyAcknowledge;

  /// Generic Continue button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// Telehealth CTA title (Airvet-style affiliate).
  ///
  /// In en, this message translates to:
  /// **'Talk to a vet now'**
  String get telehealthTitle;

  /// Telehealth CTA subtitle.
  ///
  /// In en, this message translates to:
  /// **'On-demand video consult with a licensed vet.'**
  String get telehealthSubtitle;

  /// Telehealth button label.
  ///
  /// In en, this message translates to:
  /// **'Consult a vet'**
  String get telehealthCta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

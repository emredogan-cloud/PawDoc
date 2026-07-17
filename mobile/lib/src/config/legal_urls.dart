import 'package:url_launcher/url_launcher.dart';

/// Central registry of PawDoc's public legal pages (the legal portal hosted on
/// AWS S3 + CloudFront). One source of truth so every entry point — sign-in,
/// settings, paywall, referral, delete-account, and the result/disclaimer
/// screens — links to the same canonical documents.
///
/// The base URL is overridable at build time so the founder can switch to the
/// final custom domain without touching code:
///   flutter build ... --dart-define=LEGAL_BASE_URL=https://pawdoc.app
///
/// The default points at the deployed CloudFront portal so links work out of
/// the box in dev and beta builds.
class LegalUrls {
  const LegalUrls._();

  static const String base = String.fromEnvironment(
    'LEGAL_BASE_URL',
    defaultValue: 'https://d1klm6zb1x23me.cloudfront.net',
  );

  static String _u(String slug) => '$base/$slug';

  static String get home => base;
  static String get privacy => _u('privacy');
  static String get terms => _u('terms');
  static String get vetDisclaimer => _u('disclaimer');
  static String get emergency => _u('emergency');
  static String get aiTransparency => _u('ai-transparency');
  static String get acceptableUse => _u('acceptable-use');
  static String get subscriptions => _u('subscriptions');
  static String get referrals => _u('referrals');
  static String get deletion => _u('deletion');
  static String get dataRetention => _u('data-retention');
  static String get cookies => _u('cookies');
  static String get gdpr => _u('gdpr');
  static String get ccpa => _u('ccpa');
  static String get children => _u('children');
  static String get contact => _u('contact');

  /// Opens a legal page in the external browser. Returns false on failure
  /// (never throws) so callers can wire it directly to a tap handler.
  static Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

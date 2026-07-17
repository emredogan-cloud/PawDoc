import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// G8 — one tap from Account to the store's subscription management page.
/// The single biggest subscription ticket class ("how do I cancel?") ends
/// here. Prefers RevenueCat's managementURL (deep-links the exact store
/// account that purchased); falls back to the platform's subscriptions page.
Future<void> openManageSubscription() async {
  String? url;
  try {
    final info = await Purchases.getCustomerInfo();
    url = info.managementURL;
  } catch (_) {}
  url ??= !kIsWeb && Platform.isIOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Mobile mirror of the `public.users` row. The mobile only reads its own
/// row; subscription fields are display-only and the source of truth is
/// always the server.
library;

import 'package:flutter/foundation.dart';

enum SubscriptionStatus {
  free,
  trial,
  premium,
  family;

  String get displayName => switch (this) {
    SubscriptionStatus.free => 'Free',
    SubscriptionStatus.trial => 'Trial',
    SubscriptionStatus.premium => 'Premium',
    SubscriptionStatus.family => 'Family',
  };

  static SubscriptionStatus tryParse(String? raw) {
    return switch (raw?.toLowerCase()) {
      'trial' => SubscriptionStatus.trial,
      'premium' => SubscriptionStatus.premium,
      'family' => SubscriptionStatus.family,
      _ => SubscriptionStatus.free,
    };
  }
}

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    required this.subscriptionStatus,
    required this.freeAnalysesUsedThisMonth,
    required this.preferredLocale,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      subscriptionStatus: SubscriptionStatus.tryParse(
        json['subscription_status'] as String?,
      ),
      freeAnalysesUsedThisMonth:
          (json['free_analyses_used_this_month'] as num?)?.toInt() ?? 0,
      preferredLocale: json['preferred_locale'] as String? ?? 'en',
    );
  }

  final String id;
  final String? email;
  final SubscriptionStatus subscriptionStatus;
  final int freeAnalysesUsedThisMonth;
  final String preferredLocale;

  bool get isPaying => subscriptionStatus != SubscriptionStatus.free;
}

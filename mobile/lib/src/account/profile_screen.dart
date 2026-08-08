import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../monetization/premium_home_screen.dart';
import '../monetization/subscription_state.dart';
import '../theme/paw_ui.dart';
import 'account_identity.dart';
import 'account_management_screen.dart';
import 'account_sections.dart';
import 'ai_transparency_screen.dart';
import 'manage_subscription.dart';
import 'notifications_settings_screen.dart';
import 'privacy_security_screen.dart';
import 'user_profile.dart';

/// `profile`, rebuilt against its reference.
///
/// Replaces the old `AccountScreen` as the app's account home — the reference
/// set calls this surface Profile and reaches it from the same place, and
/// keeping two account roots would leave the Subscription row, the analytics
/// consent and the delete path in one place and everything else in the other.
/// Every capability the old screen had is still reachable: subscription here,
/// notifications and privacy and AI transparency through the shortcut grid,
/// sign-out and delete through Account Management.
///
/// ## The reference's identity block, line by line
///
/// The header prints a photo, "Emre Doğan" with a blue verified tick, an email,
/// a phone number, "İstanbul, Türkiye", and "Joined on May 12, 2024". Below it,
/// six editable rows repeat four of those and add a date of birth.
///
/// PawDoc stores the email, the identity provider and the creation date. It has
/// never asked for a phone number, a location or a date of birth, and the
/// client cannot write `public.users` at all — `20260527030000_referrals.sql`
/// revokes UPDATE from `authenticated` except for one dead push column. So:
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | "Emre Doğan" + a verified badge | the provider's name, else the email's local part | no name is collected, and nothing about an owner is verified |
/// | "+90 555 123 45 67" | *(gone)* | no phone column exists, in any table |
/// | "İstanbul, Türkiye" | *(gone)* | no location is stored; walks read coordinates on-device and never send them |
/// | "Date of Birth · May 15, 2002" | *(gone)* | never collected |
/// | "Joined on May 12, 2024" | "Member since" + the month and year, from `auth.users.created_at` | real |
/// | "Language · English (US)" | the language the app resolved, marked as following the device | there is no in-app language picker; `preferred_locale` is not client-writable |
/// | "About You · I am a… Pet Parent / My goal / Bio" | "What PawDoc never asks for" | there is no profile table to hold a bio; the honest version of this block is the list of things the product does not collect |
/// | "3 Pets · 48 Health Records · 12 Vet Visits · 7 Vaccinations · 24 Reminders" | five live counts, em dash when unreadable | real counts, and a dash rather than a zero when the read failed |
/// | "Appearance · App theme" | AI transparency | PawDoc ships one theme; there is no picker to open |
/// | "We use industry-leading security to protect your information" | what RLS actually guarantees | an unfalsifiable marketing claim replaced with the mechanism |
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(accountIdentityProvider);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'My Profile',
          icon: LucideIcons.circleUser,
          subtitle: 'Your account, your settings, your ',
          subtitleTrail: 'data.',
          actionsWidth: 56,
          actions: [
            HealthCircleButton(
              key: const Key('profile_open_account'),
              icon: LucideIcons.settings,
              tooltip: 'Account management',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AccountManagementScreen())),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        onRefresh: () async {
          ref.invalidate(accountSummaryProvider);
          ref.invalidate(userProfileProvider);
          ref.invalidate(subscriptionSnapshotProvider);
        },
        children: identity == null
            ? [gap(24), const _SignedOut()]
            : [
                gap(6),
                _Header(identity: identity),
                gap(16),
                _AccountInformation(identity: identity),
                gap(16),
                const _NotCollected(),
                gap(16),
                const _Shortcuts(),
                gap(14),
                const _DataCallout(),
                gap(10),
              ],
      ),
    );
  }
}

/// Signed out mid-session (a token revocation, or the delete cascade landing
/// while this screen is open). The router redirects on the auth event; this is
/// the frame before it does, and it must not be a crash or a blank.
class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) => const AccountHero(
        icon: LucideIcons.userRound,
        title: 'You are signed out',
        body: 'Sign in again to see your pets, your records and your '
            'reminders. Emergency help never needs an account.',
      );
}

class _Header extends ConsumerWidget {
  const _Header({required this.identity});

  final AccountIdentity identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountIdentityCard(
      identity: identity,
      trailing: const AccountPlanBlock(),
      footer: const _SummaryStrip(),
    );
  }
}

/// The plan block, shared verbatim by `profile` and `account_management`.
///
/// Public so both screens render one implementation: the reference draws the
/// same card on both, and two copies is how they end up disagreeing about
/// whether the subscription renews.
class AccountPlanBlock extends ConsumerWidget {
  const AccountPlanBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final snapshot = ref.watch(subscriptionSnapshotProvider);

    // hasError BEFORE isLoading: Riverpod 3 retries a failed provider and puts
    // it back into `loading` while retaining the error, so checking loading
    // first hides the failure branch forever.
    final isPremium = profile.hasValue ? profile.requireValue.isPremium : false;
    final snap = snapshot.value;

    String? renewal;
    if (isPremium && snap != null && snap.readable && snap.renewsAt != null) {
      renewal = snap.willRenew
          ? 'Renews ${shortDateLabel(snap.renewsAt!)}'
          : 'Access until ${shortDateLabel(snap.renewsAt!)}';
    }

    return AccountPlanCard(
      premium: isPremium,
      planName: isPremium ? 'PawDoc Premium' : 'PawDoc Free',
      status: isPremium
          ? (snap?.inTrial == true ? 'Store trial' : 'Active')
          : 'Everything safety-critical included',
      renewalLabel: renewal,
      actionLabel: isPremium ? 'Manage plan' : 'See Premium',
      // Never inert, even while the profile is loading or has failed: the row
      // that used to fall through to a tap-less fallback is exactly the device
      // bug `account_subscription_tile_test` exists for.
      onAction: () async {
        if (!isPremium) {
          await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PremiumHomeScreen()));
          return;
        }
        await openManageSubscription();
      },
    );
  }
}

/// `Aug 8, 2026` for the plan card. Local to this module so the settings
/// surfaces are not coupled to the record module's date helpers.
String shortDateLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _SummaryStrip extends ConsumerWidget {
  const _SummaryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary =
        ref.watch(accountSummaryProvider).value ?? AccountSummary.unknown;

    // An em dash, never a zero. "0 Health Records" asserts the account is
    // empty; the read may simply have failed, and on the settings screen those
    // two look identical to a user who has 48 of them.
    String n(int? v) => v == null ? '—' : '$v';

    return HealthStatTiles(
      key: const Key('profile_summary_strip'),
      grouped: true,
      layout: HealthStatLayout.stacked,
      stats: [
        HealthStat(
            icon: LucideIcons.pawPrint, value: n(summary.pets), label: 'Pets'),
        HealthStat(
            icon: LucideIcons.clipboardList,
            value: n(summary.healthRecords),
            label: 'Records'),
        HealthStat(
            icon: LucideIcons.syringe,
            value: n(summary.vaccinationRecords),
            label: 'Vaccines'),
        HealthStat(
            icon: LucideIcons.bellRing,
            value: n(summary.reminders),
            label: 'Reminders'),
        HealthStat(
            icon: LucideIcons.images,
            value: n(summary.journalEntries),
            label: 'Journal'),
      ],
    );
  }
}

class _AccountInformation extends StatelessWidget {
  const _AccountInformation({required this.identity});

  final AccountIdentity identity;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AccountGroup(
      title: 'Account information',
      caption: 'Everything PawDoc holds about you, as the account holder.',
      children: [
        AccountFactRow(
          icon: LucideIcons.mail,
          title: 'Email',
          subtitle: identity.email.isEmpty
              ? 'A guest session has no email address. Add one from Account '
                  'management to keep your records if you change device.'
              : 'The address you sign in with.',
          value: identity.email.isEmpty ? 'None' : identity.email,
        ),
        AccountFactRow(
          icon: LucideIcons.keyRound,
          title: 'Sign-in method',
          subtitle: 'How this account authenticates.',
          value: identity.providerLabel,
        ),
        if (identity.createdAt != null)
          AccountFactRow(
            icon: LucideIcons.calendarDays,
            title: 'Member since',
            subtitle: 'When the account was created.',
            value: shortDateLabel(identity.createdAt!),
          ),
        AccountFactRow(
          icon: LucideIcons.globe,
          title: 'Language',
          subtitle: 'PawDoc follows your device language, and falls back to '
              'English where it has no translation.',
          value: locale.languageCode.toUpperCase(),
        ),
      ],
    );
  }
}

/// The honest counterpart to the reference's "About You".
///
/// The reference collects a role, a goal and a bio, and prints a phone number,
/// a city and a date of birth in the header. None of that exists. Listing what
/// is *not* asked for turns the gap into the thing it actually is — a
/// deliberate data-minimisation choice — instead of four blank rows.
class _NotCollected extends StatelessWidget {
  const _NotCollected();

  @override
  Widget build(BuildContext context) {
    return AccountGroup(
      key: const Key('profile_not_collected'),
      title: 'What PawDoc never asks for',
      caption: 'A health record needs facts about your pet, not about you.',
      children: const [
        AccountFactRow(
          icon: LucideIcons.phone,
          title: 'Phone number',
          subtitle: 'PawDoc has no phone column and sends no SMS.',
          value: 'Not collected',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.mapPin,
          title: 'Your location',
          subtitle: 'Walk forecasts and nearby owners read your coordinates on '
              'the device. Only a coarse area code is stored, and only if you '
              'join the community.',
          value: 'Stays on device',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.cake,
          title: 'Date of birth',
          subtitle: 'Never asked, never stored.',
          value: 'Not collected',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.creditCard,
          title: 'Card details',
          subtitle: 'Purchases go through the app store. PawDoc never sees a '
              'card number.',
          value: 'Never seen',
          positive: false,
        ),
      ],
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    void go(BuildContext context, Widget screen) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(3, 0, 3, 8),
          child: Text('Settings',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
        ),
        AccountShortcutGrid(
          cells: [
            AccountCell(
              icon: LucideIcons.userCog,
              title: 'Account & plan',
              body: 'Sign-in, subscription, sign out, delete',
              onTap: () => go(context, const AccountManagementScreen()),
            ),
            AccountCell(
              icon: LucideIcons.bell,
              title: 'Notifications',
              body: 'Reminders and the daily walk nudge',
              onTap: () => go(context, const NotificationsSettingsScreen()),
            ),
            AccountCell(
              icon: LucideIcons.shieldCheck,
              title: 'Privacy & security',
              body: 'Analytics, community, export, delete',
              onTap: () => go(context, const PrivacySecurityScreen()),
            ),
            AccountCell(
              icon: LucideIcons.sparkles,
              title: 'AI transparency',
              body: 'What the model sees and what it cannot do',
              onTap: () => go(context, const AiTransparencyScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _DataCallout extends StatelessWidget {
  const _DataCallout();

  @override
  Widget build(BuildContext context) {
    return AccountCallout(
      icon: LucideIcons.shieldCheck,
      title: 'Your records are scoped to your account',
      // The reference says "We use industry-leading security to protect your
      // information", which is unfalsifiable. This names the mechanism instead:
      // row-level security on every user table, verified by scripts/test-rls.sh
      // in CI over the full migration set.
      body: 'Every table that holds your pets, records, reminders and photos is '
          'behind a row-level security policy keyed to your user id, and the '
          'app never holds storage credentials.',
      actions: [
        HealthActionPill(
          key: const Key('profile_open_privacy'),
          label: 'How your data is handled',
          icon: LucideIcons.chevronRight,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PrivacySecurityScreen())),
        ),
      ],
    );
  }
}

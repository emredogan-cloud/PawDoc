import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../auth/supabase_providers.dart';
import '../config/legal_urls.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../monetization/premium_home_screen.dart';
import '../monetization/subscription_state.dart';
import '../monetization/upgrade_benefits_screen.dart';
import '../notifications/local_notifications.dart';
import '../theme/paw_ui.dart';
import 'account_identity.dart';
import 'account_sections.dart';
import 'delete_account_screen.dart';
import 'manage_subscription.dart';
import 'privacy_security_screen.dart';
import 'profile_screen.dart' show AccountPlanBlock, shortDateLabel;
import 'user_profile.dart';

/// `account_management`, rebuilt against its reference.
///
/// This is the account *lifecycle* surface — authentication, plan, and the two
/// irreversible actions. Identity presentation and the summary counts stay on
/// `ProfileScreen`; the two screens share one header widget and one plan block
/// rather than each drawing their own.
///
/// ## What the reference sells that does not exist
///
/// | Reference row | Shipped | Why |
/// |---|---|---|
/// | "Personal Information · Name, email, phone, location and more · Edit" | Email + sign-in method + member since, read-only | there is no writable owner profile: `revoke update on public.users from authenticated` leaves one dead column granted |
/// | "Email Management · Manage" | the address, and how to move it | changing the sign-in address needs a verified round trip PawDoc has not built; the contact page is the real route |
/// | "Phone Number · Update" | *(gone)* | no phone number is stored, and no SMS is ever sent |
/// | "Time Zone · (GMT+3) Istanbul" | the device's IANA zone, read live | real, and it is the zone reminders are scheduled in — worth stating, not worth pretending is a setting |
/// | "Payment Method · Visa •••• 4242 · Update" | "Handled by the app store" | PawDoc never receives a payment instrument; RevenueCat exposes none |
/// | "Billing History · View invoices and payment history" | a link to the store's subscription page | there is no invoice PawDoc can render |
/// | "Manage Devices · 3 Active" | *(gone)*, replaced by "Sign out everywhere" | Supabase exposes no session list to a client; global sign-out is the real control that fake row was standing in front of |
/// | "Pause Subscription · Pause" | "Cancel any time in the store" | PawDoc implements no pause, and neither claims nor controls the store's |
/// | "Change Password · Update" | a reset link to the account address, email accounts only | real, and correctly absent on Google/Apple/guest sessions, which have no password |
/// | "Security Center" | Privacy & security | there is no separate security product |
/// | "We use industry-leading security" | what RLS and presigned uploads actually do | the mechanism, not the adjective |
class AccountManagementScreen extends ConsumerWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(accountIdentityProvider);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Account',
          icon: LucideIcons.userCog,
          subtitle: 'Your sign-in, your plan, your ',
          subtitleTrail: 'account.',
          actionsWidth: 56,
          actions: [
            HealthCircleButton(
              key: const Key('account_help'),
              icon: LucideIcons.circleHelp,
              tooltip: 'What lives where',
              onTap: () => _explain(context),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: identity == null
            ? [
                gap(24),
                const AccountHero(
                  icon: LucideIcons.userRound,
                  title: 'You are signed out',
                  body: 'Sign in again to manage this account.',
                ),
              ]
            : [
                gap(6),
                _Header(identity: identity),
                gap(16),
                _AccountSection(identity: identity),
                gap(16),
                const _PlanSection(),
                gap(16),
                _SecuritySection(identity: identity),
                gap(16),
                const _DangerSection(),
                gap(14),
                const _Callout(),
                gap(10),
              ],
      ),
    );
  }

  static void _explain(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'What lives where',
        scrollable: true,
        children: [
          HealthDetailRow(
            icon: LucideIcons.circleUser,
            label: 'Profile',
            value: 'Who you are on this account, and a count of what you have '
                'recorded.',
          ),
          HealthDetailRow(
            icon: LucideIcons.userCog,
            label: 'Account',
            value: 'Sign-in, the plan, signing out and deleting. The two '
                'actions that cannot be undone are both here.',
          ),
          HealthDetailRow(
            icon: LucideIcons.shieldCheck,
            label: 'Privacy & security',
            value: 'What is collected, who processes it, and the controls you '
                'can actually change.',
          ),
          HealthDetailRow(
            icon: LucideIcons.store,
            label: 'The app store',
            value: 'Payment, invoices, refunds and cancellation. PawDoc never '
                'receives your card details.',
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.identity});

  final AccountIdentity identity;

  @override
  Widget build(BuildContext context) => AccountIdentityCard(
        identity: identity,
        trailing: const AccountPlanBlock(),
      );
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.identity});

  final AccountIdentity identity;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AccountGroup(
      title: 'Account',
      children: [
        AccountFactRow(
          icon: LucideIcons.mail,
          title: 'Email',
          subtitle: identity.email.isEmpty
              ? 'This is a guest session. Sign in with an email or Google to '
                  'keep these records if you change device.'
              : 'The address this account signs in with.',
          value: identity.email.isEmpty ? 'None' : identity.email,
        ),
        AccountSettingRow(
          key: const Key('account_email_change'),
          icon: LucideIcons.atSign,
          title: 'Change your email',
          subtitle: 'Moving an account to a new address is done by hand for '
              'now — write to us and we will move it with your records.',
          value: 'Contact us',
          onTap: () => LegalUrls.open(LegalUrls.contact),
        ),
        AccountFactRow(
          icon: LucideIcons.keyRound,
          title: 'Sign-in method',
          subtitle: 'Set when the account was created and not changeable from '
              'the app.',
          value: identity.providerLabel,
        ),
        if (identity.createdAt != null)
          AccountFactRow(
            icon: LucideIcons.calendarDays,
            title: 'Member since',
            subtitle: 'When this account was created.',
            value: shortDateLabel(identity.createdAt!),
          ),
        AccountFactRow(
          icon: LucideIcons.globe,
          title: 'Language',
          subtitle: 'Follows your device. English and German are translated; '
              'anything else falls back to English.',
          value: locale.languageCode.toUpperCase(),
        ),
        const _TimeZoneRow(),
      ],
    );
  }
}

/// The device's IANA time zone, read live.
///
/// The reference presents "(GMT+3) Istanbul" as an editable setting. It is not
/// one — but it is not invented either: it is the zone
/// `LocalNotifications.initialize` sets on the scheduler, so it is exactly what
/// decides when a reminder arrives. Stating it (and what it is used for) is
/// more useful than a picker that could only ever be wrong.
class _TimeZoneRow extends StatefulWidget {
  const _TimeZoneRow();

  @override
  State<_TimeZoneRow> createState() => _TimeZoneRowState();
}

class _TimeZoneRowState extends State<_TimeZoneRow> {
  String? _zone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? name;
    try {
      name = await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      // Unknown zone: the scheduler keeps UTC, and so does this row.
    }
    if (mounted) setState(() => _zone = name);
  }

  @override
  Widget build(BuildContext context) {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return AccountFactRow(
      key: const Key('account_timezone'),
      icon: LucideIcons.clock,
      title: 'Time zone',
      subtitle: 'Follows your device. Reminders are scheduled at '
          '${LocalNotifications.reminderHour}:00 in this zone.',
      value: _zone ?? 'UTC$sign$hours:$minutes',
    );
  }
}

class _PlanSection extends ConsumerWidget {
  const _PlanSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final snapshot = ref.watch(subscriptionSnapshotProvider);
    final isPremium = profile.hasValue ? profile.requireValue.isPremium : false;
    final snap = snapshot.value;

    // Only a real, readable store answer produces a date. `readable: false`
    // means the SDK was never configured in this build — the honest readout is
    // that the plan could not be checked, never a plausible renewal date.
    final String planValue;
    if (!isPremium) {
      planValue = 'Free';
    } else if (snap != null && snap.readable && snap.renewsAt != null) {
      planValue = snap.willRenew
          ? 'Renews ${shortDateLabel(snap.renewsAt!)}'
          : 'Ends ${shortDateLabel(snap.renewsAt!)}';
    } else {
      planValue = 'Premium';
    }

    return AccountGroup(
      title: 'Plan',
      children: [
        AccountSettingRow(
          key: const Key('account_plan_row'),
          icon: isPremium ? LucideIcons.crown : LucideIcons.pawPrint,
          title: isPremium ? 'PawDoc Premium' : 'PawDoc Free',
          subtitle: isPremium
              ? 'Photo checks, assistant messages and journal entries are '
                  'uncapped, and the PDF report is included.'
              : 'Emergency help, symptom checks by text, records, reminders '
                  'and vet prep are all included at no cost.',
          value: planValue,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const UpgradeBenefitsScreen())),
        ),
        AccountSettingRow(
          key: const Key('account_manage_store'),
          icon: LucideIcons.store,
          title: isPremium ? 'Manage or cancel' : 'See Premium',
          subtitle: isPremium
              ? 'Subscriptions are changed and cancelled in the app store, not '
                  'here.'
              : 'What an upgrade changes, and what it does not.',
          value: isPremium ? 'Open store' : 'Compare',
          onTap: () async {
            if (isPremium) {
              await openManageSubscription();
              return;
            }
            if (!context.mounted) return;
            await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const PremiumHomeScreen()));
          },
        ),
        // Replaces "Payment Method · Visa •••• 4242" and "Billing History".
        // Neither is a thing PawDoc can render: RevenueCat reports entitlement,
        // never an instrument, and there is no invoice in any table.
        const AccountFactRow(
          key: Key('account_billing_fact'),
          icon: LucideIcons.creditCard,
          title: 'Payments and invoices',
          subtitle: 'Your card, your receipts and any refund are handled '
              'entirely by the app store. PawDoc never receives card details.',
          value: 'App store',
        ),
        AccountUnavailableRow(
          icon: LucideIcons.circlePause,
          title: 'Pause subscription',
          subtitle: 'PawDoc has no pause. If the store offers one for your '
              'subscription, it is offered there.',
          badge: 'Not built',
        ),
      ],
    );
  }
}

class _SecuritySection extends ConsumerWidget {
  const _SecuritySection({required this.identity});

  final AccountIdentity identity;

  Future<void> _sendReset(BuildContext context, WidgetRef ref) async {
    final email = identity.email;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send a password reset link?'),
        content: Text('We will email a link to $email. Opening it brings you '
            'back to PawDoc to set a new password.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send link')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    var sent = true;
    try {
      await ref.read(authControllerProvider).resetPassword(email);
    } catch (_) {
      sent = false;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent
          ? 'Reset link sent to $email. Check your spam folder too.'
          : 'Could not send the reset link just now. Please try again.'),
    ));
  }

  /// Revokes every refresh token for this account, everywhere.
  ///
  /// This is the real control the reference's "Manage Devices · 3 Active" row
  /// was standing in front of. A client cannot enumerate Supabase sessions, but
  /// it can end all of them, which is the thing a worried user actually wants.
  Future<void> _signOutEverywhere(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out on all devices?'),
        content: const Text(
            'Every phone and tablet signed in to this account will be signed '
            'out, including this one. Nothing is deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out everywhere')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signOut(scope: SignOutScope.global);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not sign out everywhere. Please try again.')));
    }
    // The auth listener drives the router's redirect to the gateway; this
    // screen is pushed above it, so unwind explicitly (the same lesson the
    // delete-account screen learned on device).
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountGroup(
      title: 'Security',
      children: [
        if (identity.hasPassword)
          AccountSettingRow(
            key: const Key('account_change_password'),
            icon: LucideIcons.keyRound,
            title: 'Change password',
            subtitle: 'We email a one-time link to your address rather than '
                'asking for the old password here.',
            value: 'Send link',
            onTap: () => _sendReset(context, ref),
          )
        else
          AccountFactRow(
            key: const Key('account_no_password'),
            icon: LucideIcons.keyRound,
            title: 'Password',
            subtitle: identity.isAnonymous
                ? 'A guest session has no password. Sign in with an email or '
                    'Google to secure these records.'
                : 'This account signs in through ${identity.providerLabel}, so '
                    'PawDoc holds no password for it. Manage it with that '
                    'provider.',
            value: 'None held',
          ),
        AccountSettingRow(
          key: const Key('account_sign_out_everywhere'),
          icon: LucideIcons.monitorSmartphone,
          title: 'Sign out everywhere',
          subtitle: 'Ends every session on every device, including this one. '
              'Nothing is deleted.',
          value: 'Sign out',
          onTap: () => _signOutEverywhere(context, ref),
        ),
        const AccountUnavailableRow(
          key: Key('account_2fa'),
          icon: LucideIcons.lockKeyhole,
          title: 'Two-factor authentication',
          subtitle: 'PawDoc has not built a second factor. Nothing in the app '
              'adds one today, so nothing here claims to.',
        ),
        const AccountUnavailableRow(
          key: Key('account_sessions'),
          icon: LucideIcons.smartphone,
          title: 'Active devices',
          subtitle: 'PawDoc cannot list where you are signed in. Sign out '
              'everywhere is the control that does exist.',
        ),
      ],
    );
  }
}

class _DangerSection extends ConsumerWidget {
  const _DangerSection();

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (yes != true) return;
    // The auth-state change drives the router's redirect; unwind the pushed
    // stack so this screen is not left sitting above it.
    await ref.read(authControllerProvider).signOut();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountGroup(
      title: 'Leaving',
      caption: 'Both of these end your session. Only one is permanent.',
      children: [
        AccountSettingRow(
          key: const Key('account_sign_out'),
          icon: LucideIcons.logOut,
          title: 'Sign out',
          subtitle: 'Signs out on this device only. Your records stay.',
          onTap: () => _confirmSignOut(context, ref),
        ),
        AccountSettingRow(
          key: const Key('account_delete'),
          icon: LucideIcons.trash2,
          title: 'Delete account',
          subtitle: 'Permanently removes your pets, records, reminders, photos '
              'and subscription record. This cannot be undone.',
          destructive: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const DeleteAccountScreen())),
        ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout();

  @override
  Widget build(BuildContext context) {
    return AccountCallout(
      icon: LucideIcons.shieldCheck,
      title: 'Your account, your data, your call',
      body: 'PawDoc holds the least it can: an email, a plan, and the records '
          'you chose to keep. Deleting the account removes all of it.',
      actions: [
        HealthActionPill(
          key: const Key('account_open_privacy'),
          label: 'Privacy & security',
          icon: LucideIcons.chevronRight,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PrivacySecurityScreen())),
        ),
        HealthActionPill(
          key: const Key('account_open_terms'),
          label: 'Terms',
          icon: LucideIcons.externalLink,
          onTap: () => LegalUrls.open(LegalUrls.terms),
        ),
      ],
    );
  }
}

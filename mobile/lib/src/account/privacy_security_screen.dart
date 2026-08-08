import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../community/community_home_screen.dart';
import '../community/community_repository.dart';
import '../config/legal_urls.dart';
import '../core/consent_prefs.dart';
import '../core/paw_nav_bar.dart';
import '../export/health_report_service.dart';
import '../health/health_sections.dart';
import '../pets/active_pet.dart';
import '../theme/paw_ui.dart';
import 'account_sections.dart';
import 'ai_transparency_screen.dart';
import 'delete_account_screen.dart';

/// `privacy_security`, rebuilt against its reference.
///
/// This is the screen the reference gets most wrong, and the one where getting
/// it wrong matters most: a security claim a user relies on and the product
/// does not implement is a lie with consequences, not a copy slip.
///
/// ## Every claim on the reference, adjudicated
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | "End-to-end Encryption" (hero chip **and** a Data Encryption tile) | *(gone)* — replaced by scoped access | PawDoc is **not** end-to-end encrypted and cannot be: the server decrypts a photo to moderate and analyse it. Transport is HTTPS and the providers encrypt at rest, which is ordinary, not end-to-end |
/// | "Secure Cloud Infrastructure" | the named services, and what each holds | an adjective replaced by the list |
/// | "We Never Sell Your Data" | who receives data, and why | a forward-looking promise belongs in the policy that is legally binding, not in a chip; the factual version is the recipient list |
/// | "Profile Visibility · Friends" | community membership, real state | PawDoc has no friends model and no visibility setting; community is opt-in or absent |
/// | "Data Sharing · Manage" | *(gone)* | there is no sharing switchboard to manage |
/// | "Third-Party Access · Manage" | the processor list, read-only | no third party holds an authorisation a user could revoke here |
/// | "Two-Factor Authentication ✅ **on**" | Not available | nothing in the app enrols a second factor. Drawing this switch already green is the single most dangerous element on the plate |
/// | "Biometric Unlock ✅ **on**" | Not available | there is no `local_auth` dependency; the app has no lock at all |
/// | "Login Alerts ✅ **on**" | Not available | no login is monitored and no alert is ever sent |
/// | "Active Sessions · 3 Active" | *(gone)* — Account carries "Sign out everywhere" | a client cannot enumerate Supabase sessions; the count would be invented |
/// | "Data Residency · stored securely in your region" | where it is stored, without a region promise | PawDoc runs one Supabase project and one R2 bucket; there is no per-user residency |
/// | "Compliance · We comply with GDPR, KVKK and global standards" | links to the published rights pages | a compliance assertion is the lawyer's to make on a page that is legally binding, not an app tile |
/// | "Data Retention · We retain data only as long as necessary" | what deletion actually removes | there is no implemented retention job; deletion is the real, cascading mechanism |
/// | "Download My Data · Download" | share a pet's record, and the rights page for a full export | the per-pet export is real and shipping; a whole-account archive is not built |
///
/// What is left is short, and all of it is true.
class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Privacy & Security',
          icon: LucideIcons.shieldCheck,
          subtitle: 'What is collected, and what you can ',
          subtitleTrail: 'change.',
          actionsWidth: 56,
          actions: [
            HealthCircleButton(
              key: const Key('privacy_policy_link'),
              icon: LucideIcons.fileText,
              tooltip: 'Privacy policy',
              onTap: () => LegalUrls.open(LegalUrls.privacy),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(6),
          const _Hero(),
          gap(16),
          const _Controls(),
          gap(16),
          const _Security(),
          gap(16),
          const _WhereItGoes(),
          gap(16),
          const _YourData(),
          gap(14),
          const _Callout(),
          gap(10),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => const AccountHero(
        icon: LucideIcons.shieldCheck,
        title: 'Your pet’s record is ',
        highlight: 'yours',
        body: 'PawDoc collects what a health record needs and not much else. '
            'Here is exactly what that means, and the parts you control.',
        assurances: [
          // Each chip restates something enforced in code, not a posture.
          AccountAssurance(
              icon: LucideIcons.lock, label: 'Scoped to your account'),
          AccountAssurance(
              icon: LucideIcons.mapPinOff, label: 'EXIF & GPS stripped'),
          AccountAssurance(
              icon: LucideIcons.chartNoAxesColumn, label: 'Analytics off by default'),
        ],
      );
}

// ---------------------------------------------------------------------------
// Controls that actually do something
// ---------------------------------------------------------------------------

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AccountGroup(
      title: 'Your controls',
      caption: 'Every switch here changes something real, right away.',
      children: [
        _AnalyticsConsentRow(),
        _CommunityRow(),
        _LocationRow(),
      ],
    );
  }
}

/// Live analytics consent (I2), carried over from the old account screen.
///
/// The privacy policy names CONSENT as the legal basis for product analytics,
/// so consent has to actually exist: off until an affirmative act, revocable,
/// and the running SDK is stopped the moment it is revoked rather than at the
/// next launch. The key is unchanged from the screen this replaces.
class _AnalyticsConsentRow extends StatefulWidget {
  const _AnalyticsConsentRow();

  @override
  State<_AnalyticsConsentRow> createState() => _AnalyticsConsentRowState();
}

class _AnalyticsConsentRowState extends State<_AnalyticsConsentRow> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    ConsentPrefs.analyticsEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<void> _set(bool v) async {
    setState(() => _enabled = v);
    await ConsentPrefs.setAnalyticsEnabled(v);
    try {
      if (v) {
        await Posthog().enable();
      } else {
        await Posthog().disable();
      }
    } catch (_) {
      // SDK not configured (no key, or consent was off at boot) — the stored
      // choice still governs the next launch.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountToggleRow(
      switchKey: const Key('analytics_consent_toggle'),
      icon: LucideIcons.chartNoAxesColumn,
      title: 'Usage analytics',
      subtitle: 'Anonymous events about which screens are used — never your '
          'photos, your notes or an analysis result. Off unless you turn it on.',
      value: _enabled ?? false,
      onChanged: _set,
    );
  }
}

/// Real community membership, read from `community_profiles`.
///
/// The reference's "Profile Visibility · Friends" implies a graded audience.
/// PawDoc's community is binary and opt-in: there is a row for you or there is
/// not, and leaving deletes it (connections, messages and proposals cascade in
/// the database).
class _CommunityRow extends ConsumerWidget {
  const _CommunityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myCommunityProfileProvider);
    final joined = profile.value != null;
    final discoverable = profile.value?.isDiscoverable ?? false;

    return AccountSettingRow(
      key: const Key('privacy_community_row'),
      icon: LucideIcons.users,
      title: 'Community presence',
      subtitle: joined
          ? (discoverable
              ? 'You are discoverable to other owners in your area. Leaving '
                  'the community deletes your profile and your connections.'
              : 'You are in the community but not discoverable nearby.')
          : 'You have not joined. Nothing about you is visible to other '
              'owners, and no area is stored.',
      value: profile.isLoading && !profile.hasValue
          ? '…'
          : (joined ? (discoverable ? 'Discoverable' : 'Joined') : 'Not joined'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const CommunityHomeScreen())),
    );
  }
}

/// Location. Genuinely device-only for walks; a coarse geohash cell only if the
/// user joined the community and chose to be discoverable.
class _LocationRow extends StatelessWidget {
  const _LocationRow();

  @override
  Widget build(BuildContext context) {
    return AccountSettingRow(
      key: const Key('privacy_location_row'),
      icon: LucideIcons.mapPin,
      title: 'Location access',
      subtitle: 'Walk forecasts read your coordinates on the device and send '
          'them to no PawDoc server. Only a coarse area cell is stored, and '
          'only if you joined the community. Granted and revoked in system '
          'settings.',
      value: 'System settings',
      onTap: openAppSettings,
    );
  }
}

// ---------------------------------------------------------------------------
// Security
// ---------------------------------------------------------------------------

class _Security extends StatelessWidget {
  const _Security();

  @override
  Widget build(BuildContext context) {
    return const AccountGroup(
      title: 'Security',
      caption: 'What protects the account today — and, plainly, what does not '
          'exist yet.',
      children: [
        AccountFactRow(
          icon: LucideIcons.lock,
          title: 'Row-level security on every table',
          subtitle: 'Pets, records, reminders, journal entries and chats are '
              'each behind a policy keyed to your user id, checked on read and '
              'on write. The suite runs those policies against the full '
              'migration set on every build.',
          value: 'Enforced',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.cloudUpload,
          title: 'The app holds no storage keys',
          subtitle: 'Photos upload through a short-lived signed URL issued per '
              'file. Extracting the app yields no credential that can read '
              'anyone’s images.',
          value: 'Enforced',
          positive: true,
        ),
        AccountUnavailableRow(
          key: Key('privacy_2fa'),
          icon: LucideIcons.lockKeyhole,
          title: 'Two-factor authentication',
          subtitle: 'Not built. No second factor protects this account, and '
              'nothing here pretends one does.',
        ),
        AccountUnavailableRow(
          key: Key('privacy_biometric'),
          icon: LucideIcons.fingerprint,
          title: 'Biometric app lock',
          subtitle: 'PawDoc does not lock itself behind Face ID or a '
              'fingerprint. Your device lock is the only lock.',
        ),
        AccountUnavailableRow(
          key: Key('privacy_login_alerts'),
          icon: LucideIcons.bellRing,
          title: 'Login alerts',
          subtitle: 'No sign-in is monitored and no alert is sent.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Where the data goes
// ---------------------------------------------------------------------------

/// Replaces the reference's "Data & Compliance" tiles.
///
/// Four unfalsifiable assertions (encryption, residency, compliance, retention)
/// become the concrete answer to the question they were gesturing at: who
/// receives your data, and what for.
class _WhereItGoes extends StatelessWidget {
  const _WhereItGoes();

  @override
  Widget build(BuildContext context) {
    return const AccountGroup(
      key: Key('privacy_processors'),
      title: 'Who your data reaches',
      caption: 'PawDoc runs on other companies’ infrastructure. These are all '
          'of them, and what each one gets.',
      children: [
        AccountFactRow(
          icon: LucideIcons.database,
          title: 'Supabase',
          subtitle: 'Your account, pets, records, reminders and journal text. '
              'Sign-in runs here too.',
          value: 'Database & auth',
          tint: AccountTone.info,
        ),
        AccountFactRow(
          icon: LucideIcons.image,
          title: 'Cloudflare R2',
          subtitle: 'Photos and videos you upload, in a folder namespaced to '
              'your account.',
          value: 'File storage',
          tint: AccountTone.info,
        ),
        AccountFactRow(
          icon: LucideIcons.sparkles,
          title: 'Google and Anthropic',
          subtitle: 'A health check sends what you wrote, the image, and your '
              'pet’s species, breed, age, sex and weight to the model that '
              'reads it. Your name, email and location are never part of it.',
          value: 'Analysis',
          tint: AccountTone.info,
        ),
        AccountFactRow(
          icon: LucideIcons.chartNoAxesColumn,
          title: 'PostHog',
          subtitle: 'Anonymous product events, and only while the analytics '
              'switch above is on.',
          value: 'Opt-in only',
          tint: AccountTone.info,
        ),
        AccountFactRow(
          icon: LucideIcons.bug,
          title: 'Sentry',
          subtitle: 'Crash and error reports, with personal fields stripped, so '
              'a failure on your phone becomes a fix.',
          value: 'Crash reports',
          tint: AccountTone.info,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Export and deletion
// ---------------------------------------------------------------------------

class _YourData extends ConsumerWidget {
  const _YourData();

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final pet = ref.read(activePetProvider);
    if (pet == null || pet.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a pet first — the export is a pet’s record.')));
      return;
    }
    try {
      await ref.read(healthReportServiceProvider).exportForPet(pet);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not build the record just now. Please try '
              'again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(activePetProvider);
    return AccountGroup(
      title: 'Your data',
      children: [
        AccountSettingRow(
          key: const Key('privacy_export_row'),
          icon: LucideIcons.share2,
          title: 'Share a pet’s record',
          subtitle: pet == null
              ? 'Add a pet and its full record can be shared as text through '
                  'your device share sheet.'
              : 'Builds ${pet.name}’s record — the latest check and the last '
                  'ten entries — and hands it to your share sheet.',
          value: 'Share',
          onTap: () => _export(context, ref),
        ),
        // The reference's "Download My Data · Download" implies a
        // whole-account archive. There is no such export; the rights page is
        // where a full copy is actually requested.
        AccountSettingRow(
          key: const Key('privacy_rights_row'),
          icon: LucideIcons.download,
          title: 'Request a full copy',
          subtitle: 'A one-tap archive of the entire account is not built. Your '
              'data rights, and how to ask for a copy, are on the rights page.',
          value: 'Your rights',
          onTap: () => LegalUrls.open(LegalUrls.gdpr),
        ),
        AccountSettingRow(
          key: const Key('account_delete'),
          icon: LucideIcons.trash2,
          title: 'Delete my account',
          subtitle: 'Removes the account and cascades every pet, record, '
              'reminder, journal entry, photo and chat with it. Permanent.',
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
      icon: LucideIcons.fileText,
      title: 'The binding version',
      body: 'This screen describes how PawDoc is built. The privacy policy is '
          'the document that commits us to it — including retention, your '
          'rights, and who to contact.',
      actions: [
        HealthActionPill(
          key: const Key('privacy_open_policy'),
          label: 'Privacy policy',
          icon: LucideIcons.externalLink,
          onTap: () => LegalUrls.open(LegalUrls.privacy),
        ),
        HealthActionPill(
          key: const Key('privacy_open_ai'),
          label: 'AI transparency',
          icon: LucideIcons.chevronRight,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const AiTransparencyScreen())),
        ),
        HealthActionPill(
          key: const Key('privacy_open_contact'),
          label: 'Contact',
          icon: LucideIcons.externalLink,
          onTap: () => LegalUrls.open(LegalUrls.contact),
        ),
      ],
    );
  }
}

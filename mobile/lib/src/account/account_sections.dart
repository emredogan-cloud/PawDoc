library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import 'account_identity.dart';

/// The building blocks the five settings surfaces are drawn from — `profile`,
/// `account_management`, `privacy_security`, `notifications` and
/// `ai_transparency`.
///
/// They share a skeleton the same way the six record mockups share
/// `health_sections`: an identity header, a plan card, grouped rows inside one
/// hairline-ruled card, a hero band with three assurance chips, a fact grid and
/// a closing call-out. Everything below is a slot; nothing is screen-specific.
///
/// The dependency runs **account → health → home**, never back.
///
/// ## The primitive this batch exists for
///
/// [AccountFactRow] and [AccountUnavailableRow] are the two shapes that carry
/// the whole batch's product-truth rule. Between them, these five references
/// draw **eighteen** controls over capabilities PawDoc does not have — Two-
/// Factor Authentication, Biometric Unlock, Login Alerts, "3 Active" sessions,
/// Profile Visibility, Third-Party Access, Data Sharing, Payment Method,
/// Billing History, Pause Subscription, Quiet Hours, SMS and Email delivery,
/// and four notification categories nothing can send. Several are drawn as
/// switches already flipped **on**, which is worse than a missing feature: it
/// tells a user their account is protected by something that is not there.
///
/// So a control on these screens is one of exactly three things — an
/// [AccountToggleRow]/[AccountSettingRow] wired to real state, an
/// [AccountFactRow] that states something true and is not tappable, or an
/// [AccountUnavailableRow] that says outright the capability does not exist
/// yet. There is no fourth shape, and in particular there is no switch whose
/// only effect is on itself.
// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// The greys and tints the settings surfaces use.
///
/// Reuses `HealthTone`'s text ramp so the two module families cannot drift a
/// point apart, and adds nothing from the action ladder's four safety-locked
/// hues — a red row here is destructive-action red, and it is only ever used
/// on Delete.
class AccountTone {
  const AccountTone._();

  static const Color muted = HealthTone.muted;
  static const Color dim = HealthTone.dim;
  static const Color faint = HealthTone.faint;

  /// Raised rows inside a card.
  static const Color raised = HealthTone.raised;

  /// The destructive accent. `emergencyDark` is the ladder's GET_HELP_NOW red
  /// and must not be borrowed for a settings row, so Delete uses the token the
  /// delete-account screen already ships.
  static const Color danger = Color(0xFFEF6B6B);

  /// Informational glyphs — provider names, transports, storage.
  static const Color info = HealthTone.info;
}

// ---------------------------------------------------------------------------
// 1 · identity
// ---------------------------------------------------------------------------

/// The avatar disc. Uses the identity provider's picture when one exists
/// (Google supplies `avatar_url`; PawDoc never asks for a photo of its user),
/// and falls back to initials — never to a stock face.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({required this.identity, this.size = 64, super.key});

  final AccountIdentity identity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final fallback = Center(
      child: Text(
        identity.initials,
        style: TextStyle(
          color: t.accent,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final url = identity.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.accent.withValues(alpha: 0.10),
        border: Border.all(color: t.accent.withValues(alpha: 0.45), width: 1.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url.isEmpty)
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              // Both states fall back to the initials rather than a spinner or
              // a broken-image box: offline is the normal case for a settings
              // screen opened on a plane.
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

/// The header card `profile` and `account_management` both open with: the
/// avatar, the headline, the email, and the facts underneath.
///
/// The reference prints a phone number, a city and a "Joined on" date beside
/// the email. Two of the three do not exist in any table PawDoc writes, so the
/// rows are the ones [AccountIdentity] can actually answer — how the account
/// signs in, and when it was created.
class AccountIdentityCard extends StatelessWidget {
  const AccountIdentityCard({
    required this.identity,
    this.trailing,
    this.footer,
    super.key,
  });

  final AccountIdentity identity;

  /// The plan block the references hang on the right. Given as a slot because
  /// it is the same widget on both screens but a different width.
  final Widget? trailing;

  /// The strip under the card — `profile`'s statistics, `account_management`'s
  /// four shortcuts.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, String)>[
      if (identity.email.isNotEmpty) (LucideIcons.mail, identity.email),
      (LucideIcons.keyRound, identity.providerLabel),
      if (identity.createdAt != null)
        (LucideIcons.calendarDays, 'Member since ${_monthYear(identity.createdAt!)}'),
    ];

    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stacks below 340dp of card width: the reference's side-by-side
          // portrait + plan block leaves the name ~90dp on a narrow handset,
          // which renders one word per line.
          LayoutBuilder(
            builder: (context, c) {
              final identityBlock = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AccountAvatar(identity: identity),
                  const SizedBox(width: 12),
                  Expanded(child: _identityText(context, facts)),
                ],
              );
              if (trailing == null) return identityBlock;
              if (c.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identityBlock,
                    const SizedBox(height: 11),
                    trailing!,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: identityBlock),
                  const SizedBox(width: 10),
                  Expanded(flex: 5, child: trailing!),
                ],
              );
            },
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }

  Widget _identityText(BuildContext context, List<(IconData, String)> facts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          identity.headline,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1.15,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        for (final (icon, text) in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Icon(icon, size: 12.5, color: AccountTone.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AccountTone.dim, fontSize: 11.5, height: 1.3)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';
}

/// The plan block both header cards carry.
///
/// The reference prints "PawDoc Premium · Active · Renews on May 24, 2027"
/// unconditionally. [renewalLabel] is null unless the store actually told us a
/// date, and the free state says what the plan is rather than pretending to be
/// a lapsed premium one.
class AccountPlanCard extends StatelessWidget {
  const AccountPlanCard({
    required this.planName,
    required this.status,
    required this.actionLabel,
    required this.onAction,
    this.renewalLabel,
    this.premium = false,
    super.key,
  });

  final String planName;
  final String status;
  final String? renewalLabel;
  final String actionLabel;
  final VoidCallback onAction;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: premium ? 0.42 : 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(premium ? LucideIcons.crown : LucideIcons.pawPrint,
                  size: 15, color: t.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(planName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.accent, fontSize: 11, fontWeight: FontWeight.w600)),
          if (renewalLabel != null) ...[
            const SizedBox(height: 5),
            Text(renewalLabel!,
                maxLines: 2,
                style: const TextStyle(
                    color: AccountTone.dim, fontSize: 10.5, height: 1.3)),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: HealthActionPill(
              key: const Key('account_subscription_tile'),
              label: actionLabel,
              icon: LucideIcons.chevronRight,
              onTap: onAction,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · the grouped card
// ---------------------------------------------------------------------------

/// A titled group of rows in one card, hairline-ruled between them — the shape
/// every one of these references files its settings under.
class AccountGroup extends StatelessWidget {
  const AccountGroup({
    required this.children,
    this.title,
    this.caption,
    this.padding = const EdgeInsets.fromLTRB(11, 3, 11, 3),
    super.key,
  });

  final List<Widget> children;
  final String? title;

  /// The line under the group heading. Used where a whole section needs a
  /// qualifier that would otherwise be repeated on every row.
  final String? caption;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 2),
            child: Text(title!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w700)),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 6),
              child: Text(caption!,
                  style: const TextStyle(
                      color: AccountTone.dim, fontSize: 11.5, height: 1.35)),
            )
          else
            const SizedBox(height: 6),
        ],
        HomeCard(
          radius: 16,
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: 0.06)),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The leading glyph on a settings row.
class _RowGlyph extends StatelessWidget {
  const _RowGlyph({required this.icon, required this.tint, this.dim = false});

  final IconData icon;
  final Color tint;
  final bool dim;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint.withValues(alpha: dim ? 0.05 : 0.12),
          border: Border.all(color: tint.withValues(alpha: dim ? 0.16 : 0.30)),
        ),
        child: Icon(icon, size: 16.5, color: tint),
      );
}

/// The base row: glyph, title, subtitle, an optional trailing widget.
///
/// Private on purpose — the three public row types below are the only shapes
/// these screens may use, so a screen cannot compose a fourth that looks
/// interactive without being wired to anything.
class _AccountRowBase extends StatelessWidget {
  const _AccountRowBase({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    this.trailing,
    this.onTap,
    this.dim = false,
    this.titleColor,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color tint;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dim;
  final Color? titleColor;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _RowGlyph(icon: icon, tint: tint, dim: dim),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: titleColor ??
                                  (dim ? AccountTone.muted : Colors.white),
                              fontSize: 13.5,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(
                          color: dim ? AccountTone.faint : AccountTone.dim,
                          fontSize: 11.5,
                          height: 1.35)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 9),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: body,
    );
  }
}

/// A row that goes somewhere. The only row shape that draws a chevron.
class AccountSettingRow extends StatelessWidget {
  const AccountSettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.tint,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// The lit value the references put before the chevron ("English (US)",
  /// "Manage", "Update"). Never a number the app cannot read.
  final String? value;

  final VoidCallback onTap;
  final Color? tint;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = destructive ? AccountTone.danger : (tint ?? t.accent);
    return _AccountRowBase(
      icon: icon,
      title: title,
      subtitle: subtitle,
      tint: c,
      titleColor: destructive ? AccountTone.danger : null,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: Text(value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          const Icon(LucideIcons.chevronRight, size: 16, color: Colors.white54),
        ],
      ),
    );
  }
}

/// A row that switches something real.
///
/// [onChanged] is required and non-null: a disabled switch belongs in
/// [AccountUnavailableRow], which explains itself, rather than here where it
/// would read as "temporarily off".
class AccountToggleRow extends StatelessWidget {
  const AccountToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.switchKey,
    this.subtitle,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key switchKey;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = tint ?? t.accent;
    return _AccountRowBase(
      icon: icon,
      title: title,
      subtitle: subtitle,
      tint: c,
      onTap: () => onChanged(!value),
      trailing: Semantics(
        toggled: value,
        label: title,
        child: ExcludeSemantics(
          child: Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF06110A),
            activeTrackColor: c,
          ),
        ),
      ),
    );
  }
}

/// A row that states a fact and is **not** tappable.
///
/// This is how the transports, the storage locations and the model names are
/// rendered: they are information, not settings, and a chevron on them would
/// promise a screen that does not exist.
class AccountFactRow extends StatelessWidget {
  const AccountFactRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.tint,
    this.positive,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// The right-hand readout ("On this device", "Not sent").
  final String? value;

  final Color? tint;

  /// Draws a tick or a bar beside [value]. `null` renders neither — for facts
  /// that are neither good nor bad, only true.
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = tint ?? t.accent;
    return _AccountRowBase(
      icon: icon,
      title: title,
      subtitle: subtitle,
      tint: c,
      trailing: value == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (positive != null) ...[
                    Icon(
                        positive! ? LucideIcons.circleCheck : LucideIcons.minus,
                        size: 13,
                        color: positive! ? c : AccountTone.faint),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(value!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: positive == false
                                ? AccountTone.faint
                                : AccountTone.muted,
                            fontSize: 11,
                            height: 1.25,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A capability the reference draws and PawDoc does not have.
///
/// Greyed, un-tappable, badged **Not available**, and — the part that matters —
/// carrying [subtitle] as a plain-English reason. "Two-Factor Authentication ·
/// Not available · PawDoc has not built a second factor yet" is honest. The
/// reference's already-flipped green switch is not.
///
/// The affordance is kept rather than deleted, per the same *Soon* convention
/// `entitlements.dart` uses: a user looking for the setting finds out where it
/// would be and what its status is, instead of concluding they missed it.
class AccountUnavailableRow extends StatelessWidget {
  const AccountUnavailableRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge = 'Not available',
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: false,
      child: _AccountRowBase(
        icon: icon,
        title: title,
        subtitle: subtitle,
        tint: AccountTone.faint,
        dim: true,
        badge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(badge,
              style: const TextStyle(
                  color: AccountTone.faint,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · the hero band
// ---------------------------------------------------------------------------

/// One assurance chip under a hero heading.
class AccountAssurance {
  const AccountAssurance({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The band every one of these references opens with: a large glyph, a
/// headline, a deck, and three short assurances.
///
/// The assurances are the most claim-dense two words on each screen — the
/// reference fills them with "End-to-end Encryption", "Vet-Verified" and
/// "We Never Sell Your Data" — so each one shipped here restates something the
/// repository enforces, and the screens' doc comments name what was dropped.
class AccountHero extends StatelessWidget {
  const AccountHero({
    required this.icon,
    required this.title,
    required this.body,
    this.assurances = const [],
    this.highlight,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<AccountAssurance> assurances;

  /// The word in [title] rendered in the accent, as the references light one
  /// word of each heading.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: 0.10),
                  border: Border.all(color: t.accent.withValues(alpha: 0.40)),
                  boxShadow: [
                    BoxShadow(
                        color: t.accent.withValues(alpha: 0.16),
                        blurRadius: 20,
                        spreadRadius: -6),
                  ],
                ),
                child: Icon(icon, size: 23, color: t.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: title),
                        if (highlight != null)
                          TextSpan(
                              text: highlight,
                              style: TextStyle(color: t.accent)),
                      ]),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(body,
                        style: const TextStyle(
                            color: AccountTone.dim,
                            fontSize: 12,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          if (assurances.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Wrap, not a Row: at 1.3× text scale three chips on one line
            // overflow a 393dp handset, and an assurance clipped in half is a
            // worse claim than one on a second line.
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                for (final a in assurances)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      color: t.accent.withValues(alpha: 0.07),
                      border:
                          Border.all(color: t.accent.withValues(alpha: 0.26)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a.icon, size: 12, color: t.accent),
                        const SizedBox(width: 5),
                        // Flexible, not a bare Text: `mainAxisSize.min` still
                        // lets the label take its natural width, and a `Wrap`
                        // hands each child the FULL line width as its maximum
                        // — so a chip wider than the line overflows rather
                        // than moving to the next run. Found at 1.3x scale on
                        // "Analytics off by default"; the chip wraps to two
                        // lines instead, which is what a pill in a Wrap should
                        // do anyway.
                        Flexible(
                          child: Text(a.label,
                              maxLines: 2,
                              style: TextStyle(
                                  color: t.accent,
                                  fontSize: 10.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · the fact grid + shortcut grid
// ---------------------------------------------------------------------------

/// One cell of [AccountFactGrid] / [AccountShortcutGrid].
class AccountCell {
  const AccountCell({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Color? tint;
}

/// The four-up grid `privacy_security` closes its "Data & Compliance" section
/// with and `profile` uses for "Security & Preferences".
///
/// [columns] is 2 by default. The references draw four across; at readable type
/// that gives each cell ~85dp, where "Notifications" alone takes three lines.
class AccountFactGrid extends StatelessWidget {
  const AccountFactGrid({
    required this.cells,
    this.columns = 2,
    super.key,
  });

  final List<AccountCell> cells;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <List<AccountCell>>[
      for (var i = 0; i < cells.length; i += columns)
        cells.sublist(i, (i + columns).clamp(0, cells.length)),
    ];
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 8),
                  Expanded(
                    child: c < rows[r].length
                        ? _GridCell(cell: rows[r][c])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// [AccountFactGrid] whose cells navigate — same shape, chevron affordance.
class AccountShortcutGrid extends StatelessWidget {
  const AccountShortcutGrid({required this.cells, this.columns = 2, super.key});

  final List<AccountCell> cells;
  final int columns;

  @override
  Widget build(BuildContext context) =>
      AccountFactGrid(cells: cells, columns: columns);
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.cell});

  final AccountCell cell;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final tint = cell.tint ?? t.accent;
    return HomeCard(
      radius: 15,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      onTap: cell.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.10),
                  border: Border.all(color: tint.withValues(alpha: 0.30)),
                ),
                child: Icon(cell.icon, size: 15, color: tint),
              ),
              if (cell.onTap != null) ...[
                const Spacer(),
                const Icon(LucideIcons.chevronRight,
                    size: 15, color: Colors.white38),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(cell.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(cell.body,
              style: const TextStyle(
                  color: AccountTone.dim, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5 · the numbered flow
// ---------------------------------------------------------------------------

/// One step of [AccountStepFlow].
class AccountStep {
  const AccountStep({
    required this.icon,
    required this.title,
    required this.body,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? tint;
}

/// The numbered "How it works" flow `ai_transparency` draws across four cards.
///
/// Vertical rather than the reference's horizontal rail: at readable type each
/// of four horizontal cards gets ~85dp, and the reference's own body copy runs
/// to three lines inside them. A vertical rail also lets a step carry more than
/// a fragment, which the safety steps need.
class AccountStepFlow extends StatelessWidget {
  const AccountStepFlow({required this.steps, super.key});

  final List<AccountStep> steps;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (steps[i].tint ?? t.accent)
                              .withValues(alpha: 0.12),
                          border: Border.all(
                              color: (steps[i].tint ?? t.accent)
                                  .withValues(alpha: 0.45)),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: steps[i].tint ?? t.accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.4,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(steps[i].icon,
                                  size: 14, color: steps[i].tint ?? t.accent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(steps[i].title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(steps[i].body,
                              style: const TextStyle(
                                  color: AccountTone.dim,
                                  fontSize: 11.5,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6 · the closing call-out
// ---------------------------------------------------------------------------

/// The bordered footer band each reference closes with — a glyph, two lines and
/// up to two actions.
class AccountCallout extends StatelessWidget {
  const AccountCallout({
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: t.accent.withValues(alpha: 0.05),
        border: Border.all(color: t.accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 21, color: t.accent),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: const TextStyle(
                            color: AccountTone.dim,
                            fontSize: 11.5,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

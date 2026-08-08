import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/ui_assets.dart';
import 'entitlements.dart';

/// The blocks the four monetization surfaces are drawn from.
///
/// `premium_home`, `subscription_plans`, `upgrade_benefits` and `usage_limits`
/// are four renderings of one thing — [kEntitlements] — so the hero, the
/// feature strip, the comparison table, the meter row and the closing band all
/// live here rather than four times over. The screens own the *state* (what
/// the store returned, what the account has used); this module owns the
/// presentation, and cannot state a benefit the catalogue does not carry.
///
/// ## The one visual departure that matters
///
/// All four references put **Premium** in the bottom navigation, where
/// `Emergency` lives (conflict C-7 / review V-24). The slot does not move:
/// these screens render the app's real `PawNavBar`, Premium is reached from
/// Profile and from contextual upsells, and the fastest route to
/// GET_HELP_NOW stays one tap from every screen.

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// The greys and the one warm tint the premium surfaces use.
///
/// **None of these may be one of the action ladder's four safety-locked hues.**
/// The references paint "2 left" and "1 left" pills in the MONITOR amber and
/// the EMERGENCY red — a quota chip in the same red as GET_HELP_NOW teaches
/// exactly the wrong reflex. Running low on photo checks is not an urgency
/// signal, so it gets a neutral warm tone that appears nowhere in triage.
/// `premium_tone_test.dart` pins the separation, as `HealthTone`,
/// `AssistantTone` and `WalkBand` are pinned.
class PremiumTone {
  const PremiumTone._();

  /// "Running low" — deliberately not `monitorDark` (#FFC233).
  static const Color low = Color(0xFFE9C46A);

  /// "Nothing left" — deliberately not `emergencyDark` (#FF5A52).
  static const Color spent = Color(0xFFC9A227);

  /// A locked or not-yet-built row.
  static const Color locked = Color(0xFF7F8A85);

  /// Every decorative tint above, for the guard test.
  static const List<Color> all = [low, spent, locked];
}

// ---------------------------------------------------------------------------
// 1 · chrome
// ---------------------------------------------------------------------------

/// The circled crown every premium reference opens with.
class PremiumCrest extends StatelessWidget {
  const PremiumCrest({this.size = 44, this.icon = LucideIcons.crown, super.key});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.accent.withValues(alpha: 0.10),
        border: Border.all(color: t.accent.withValues(alpha: 0.38)),
      ),
      child: Icon(icon, size: size * 0.47, color: t.accent),
    );
  }
}

/// A small state chip — `Soon`, `Locked`, `Included`, `Active`.
///
/// The references badge their feature cards `MOST POPULAR`, `EXCLUSIVE` and
/// `UNLIMITED`. Two of those are sales positioning with nothing behind them
/// (nothing measures popularity pre-launch, and nothing is exclusive to
/// anyone), so the badge slot carries a *state* instead of a superlative.
class PremiumChip extends StatelessWidget {
  const PremiumChip({
    required this.label,
    this.tint,
    this.icon,
    this.filled = false,
    super.key,
  });

  final String label;
  final Color? tint;
  final IconData? icon;

  /// The lit treatment the reference gives its lead badge.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? PawTone.of(context).accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.withValues(alpha: filled ? 1 : 0.40)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon,
              size: 10.5, color: filled ? const Color(0xFF06110A) : c),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                color: filled ? const Color(0xFF06110A) : c,
                fontSize: 9.5,
                height: 1.2,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// The chip a given entitlement deserves, or `null` when it needs none.
Widget? entitlementChip(Entitlement e) => switch (e.kind) {
      EntitlementKind.soon => const PremiumChip(
          label: 'SOON', tint: PremiumTone.locked, icon: LucideIcons.clock),
      EntitlementKind.premiumOnly =>
        const PremiumChip(label: 'PREMIUM', icon: LucideIcons.crown),
      EntitlementKind.metered => null,
      EntitlementKind.everyone => null,
    };

// ---------------------------------------------------------------------------
// 2 · the hero
// ---------------------------------------------------------------------------

/// The opening card: a two-line headline with its second half lit, a deck, a
/// primary CTA and a footnote — over the dog-and-cat halo plate.
///
/// ## Copy that did not survive the audit
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | "Premium tools made by vets." | *(gone)* | no veterinarian authored any part of this product |
/// | "Loved by pet parents." | *(gone)* | pre-launch; there are no customers to be loved by |
/// | "Cancel anytime. 7-day money-back guarantee." | "Cancel anytime in Google Play." | refunds are Google's, on Google's terms — PawDoc runs no refund programme |
class PremiumHeroCard extends StatelessWidget {
  const PremiumHeroCard({
    required this.headline,
    required this.headlineAccent,
    required this.deck,
    this.ctaLabel,
    this.onCta,
    this.footnote,
    this.footnoteIcon = LucideIcons.shieldCheck,
    this.chips = const [],
    super.key,
  });

  final String headline;

  /// The lit remainder of the headline — "for **your pet**".
  final String headlineAccent;
  final String deck;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? footnote;
  final IconData footnoteIcon;

  /// The two small assurances the reference sets under its deck.
  final List<({IconData icon, String title, String body})> chips;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 20,
      padding: EdgeInsets.zero,
      accent: t.accent.withValues(alpha: 0.30),
      glow: 0.10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 176dp, not 210: on the device the deck ran under the dog's
            // muzzle and the footnote finished on top of it.
            Positioned(
              right: -28,
              top: -10,
              bottom: -10,
              width: 176,
              child: IgnorePointer(
                // The plate is neon art rendered on solid black, and the card
                // is near-black — `screen` drops the ground out with no matte
                // line. A boxed portrait leaves a visible seam here.
                child: BlendMask(
                  blendMode: BlendMode.screen,
                  child: Image.asset(
                    UiAssets.onbHeroDogCatHalo,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 60% of the card: the plate occupies the right third, and
                  // copy running under it is unreadable on the device.
                  FractionallySizedBox(
                    widthFactor: 0.60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: headline),
                            TextSpan(
                                text: headlineAccent,
                                style: TextStyle(color: t.accent)),
                          ]),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.18,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 7),
                        Text(deck,
                            style: const TextStyle(
                                color: HealthTone.muted,
                                fontSize: 11.5,
                                height: 1.35)),
                      ],
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FractionallySizedBox(
                      widthFactor: 0.60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in chips)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: _HeroAssurance(
                                  icon: c.icon, title: c.title, body: c.body),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (ctaLabel != null) ...[
                    const SizedBox(height: 13),
                    FractionallySizedBox(
                      widthFactor: 0.62,
                      child: HealthPrimaryCta(
                        key: const Key('premium_hero_cta'),
                        label: ctaLabel!,
                        icon: null,
                        trailingIcon: LucideIcons.chevronRight,
                        onTap: onCta ?? () {},
                      ),
                    ),
                  ],
                  if (footnote != null) ...[
                    const SizedBox(height: 9),
                    FractionallySizedBox(
                      widthFactor: 0.62,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(footnoteIcon, size: 12, color: t.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(footnote!,
                                style: const TextStyle(
                                    color: HealthTone.dim,
                                    fontSize: 10.5,
                                    height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroAssurance extends StatelessWidget {
  const _HeroAssurance(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.accent.withValues(alpha: 0.10),
            border: Border.all(color: t.accent.withValues(alpha: 0.32)),
          ),
          child: Icon(icon, size: 13, color: t.accent),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700)),
              Text(body,
                  maxLines: 2,
                  style: const TextStyle(
                      color: HealthTone.dim, fontSize: 10, height: 1.25)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · the feature strip
// ---------------------------------------------------------------------------

/// The row of circled glyphs under the hero — one per entitlement, two lines
/// of label beneath.
///
/// The reference draws six across on a 393dp screen, which gives each label
/// 55dp. It scrolls here instead, so a label never has to ellipsise to fit a
/// count that was chosen for a picture.
class PremiumFeatureStrip extends StatelessWidget {
  const PremiumFeatureStrip({
    required this.entitlements,
    this.onTap,
    super.key,
  });

  final List<Entitlement> entitlements;
  final void Function(Entitlement)? onTap;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entitlements)
              _StripCell(
                  entitlement: e,
                  onTap: onTap == null ? null : () => onTap!(e)),
          ],
        ),
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({required this.entitlement, this.onTap});

  final Entitlement entitlement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final soon = entitlement.kind == EntitlementKind.soon;
    final tint = soon ? PremiumTone.locked : t.accent;
    return Semantics(
      button: onTap != null,
      label: entitlement.title,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 82,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: tint.withValues(alpha: 0.42)),
                    ),
                    child: Icon(entitlement.icon, size: 20, color: tint),
                  ),
                  const SizedBox(height: 7),
                  // Two lines, fixed: inside a fixed-height rail a Text
                  // reports its unwrapped height and a wrapping label is
                  // silently clipped. The *short* title, because 82dp is not
                  // enough for "Symptom checks by text" and the device showed
                  // it as "Symptom checks by t…".
                  SizedBox(
                    height: 28,
                    child: Text(
                      entitlement.short,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: soon ? HealthTone.faint : Colors.white,
                          fontSize: 10.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · feature cards
// ---------------------------------------------------------------------------

/// One card in the "Premium Features" grid: a state chip, a large glyph, the
/// title, the blurb and a footer that states what each plan gets.
class PremiumFeatureCard extends StatelessWidget {
  const PremiumFeatureCard({
    required this.entitlement,
    required this.isPremium,
    this.onTap,
    super.key,
  });

  final Entitlement entitlement;

  /// Changes the footer from a sales line to a state line.
  final bool isPremium;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final e = entitlement;
    final soon = e.kind == EntitlementKind.soon;
    final tint = soon ? PremiumTone.locked : t.accent;
    final chip = entitlementChip(e);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            child: chip ?? const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: tint.withValues(alpha: 0.09),
              border: Border.all(color: tint.withValues(alpha: 0.26)),
            ),
            child: Icon(e.icon, size: 25, color: tint),
          ),
          const SizedBox(height: 11),
          Text(e.title,
              style: TextStyle(
                  color: soon ? HealthTone.muted : Colors.white,
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(e.blurb,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 11, height: 1.35)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _footer(e, isPremium),
                  maxLines: 2,
                  style: TextStyle(
                      color: soon ? HealthTone.faint : tint,
                      fontSize: 10.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700),
                ),
              ),
              if (onTap != null)
                Icon(LucideIcons.chevronRight, size: 14, color: tint),
            ],
          ),
        ],
      ),
    );
  }

  static String _footer(Entitlement e, bool isPremium) => switch (e.kind) {
        EntitlementKind.soon => 'Not built yet',
        EntitlementKind.premiumOnly =>
          isPremium ? 'Included in your plan' : 'Premium · ${e.premiumValue}',
        EntitlementKind.metered => isPremium
            ? 'Unlimited on your plan'
            : '${e.freeValue} free · ${e.premiumValue} on Premium',
        EntitlementKind.everyone => 'Free for everyone · ${e.freeValue}',
      };
}

/// The two-column grid the reference lays its feature cards out in.
///
/// A `GridView` with a fixed aspect ratio clips a card whose blurb wraps to a
/// third line at large text; this measures each row instead.
class PremiumFeatureGrid extends StatelessWidget {
  const PremiumFeatureGrid({
    required this.entitlements,
    required this.isPremium,
    this.onTap,
    super.key,
  });

  final List<Entitlement> entitlements;
  final bool isPremium;
  final void Function(Entitlement)? onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Entitlement>>[
      for (var i = 0; i < entitlements.length; i += 2)
        entitlements.sublist(
            i, i + 2 > entitlements.length ? entitlements.length : i + 2),
    ];
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 11),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: 11),
                  Expanded(
                    child: c < rows[r].length
                        ? PremiumFeatureCard(
                            entitlement: rows[r][c],
                            isPremium: isPremium,
                            onTap: onTap == null
                                ? null
                                : () => onTap!(rows[r][c]),
                          )
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

// ---------------------------------------------------------------------------
// 5 · the comparison table
// ---------------------------------------------------------------------------

/// `upgrade_benefits`' "See the difference": a glyph, the capability, and what
/// each plan gets — with the Premium column lit down its full height.
class EntitlementCompareTable extends StatelessWidget {
  const EntitlementCompareTable({
    required this.entitlements,
    this.title = 'See the difference',
    this.highlight = true,
    super.key,
  });

  final List<Entitlement> entitlements;
  final String title;

  /// Draws the lit frame around the Premium column.
  final bool highlight;

  static const double _freeWidth = 74;
  static const double _premiumWidth = 88;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(
                width: _freeWidth,
                child: Text('Free',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: HealthTone.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              SizedBox(
                width: _premiumWidth,
                // Shrink-to-fit: the crown plus "Premium" is 15dp wider than
                // the column at the em-square test font, and a header that
                // clips is a header that stops naming its column. The widget
                // test found this before the device did.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.crown, size: 13, color: t.accent),
                      const SizedBox(width: 4),
                      Text('Premium',
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < entitlements.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06)),
            _CompareRow(
              entitlement: entitlements[i],
              highlight: highlight,
              first: i == 0,
              last: i == entitlements.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.entitlement,
    required this.highlight,
    required this.first,
    required this.last,
  });

  final Entitlement entitlement;
  final bool highlight;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final e = entitlement;
    final soon = e.kind == EntitlementKind.soon;
    final tint = soon ? PremiumTone.locked : t.accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint.withValues(alpha: 0.09),
                      border: Border.all(color: tint.withValues(alpha: 0.26)),
                    ),
                    child: Icon(e.icon, size: 15, color: tint),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.title,
                            style: TextStyle(
                                color: soon ? HealthTone.muted : Colors.white,
                                fontSize: 12.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(e.blurb,
                            style: const TextStyle(
                                color: HealthTone.dim,
                                fontSize: 10.5,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: EntitlementCompareTable._freeWidth,
            child: Center(child: _value(e.freeValue, HealthTone.muted)),
          ),
          Container(
            width: EntitlementCompareTable._premiumWidth,
            decoration: BoxDecoration(
              color:
                  highlight ? t.accent.withValues(alpha: 0.05) : null,
              border: highlight
                  ? Border(
                      left: BorderSide(
                          color: t.accent.withValues(alpha: 0.34)),
                      right: BorderSide(
                          color: t.accent.withValues(alpha: 0.34)),
                      top: first
                          ? BorderSide(
                              color: t.accent.withValues(alpha: 0.34))
                          : BorderSide.none,
                      bottom: last
                          ? BorderSide(
                              color: t.accent.withValues(alpha: 0.34))
                          : BorderSide.none,
                    )
                  : null,
            ),
            child: Center(
                child: _value(e.premiumValue, soon ? HealthTone.faint : tint)),
          ),
        ],
      ),
    );
  }

  /// A dash renders as a struck-through circle, a word renders as a word.
  /// The reference uses a green tick for "yes"; a tick beside "Unlimited"
  /// says less than the word does, so only the absent case gets a mark.
  Widget _value(String value, Color color) {
    if (value == '—') {
      return const Icon(LucideIcons.circleX,
          size: 16, color: PremiumTone.locked);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(value,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------------------
// 6 · usage meters
// ---------------------------------------------------------------------------

/// One row of `usage_limits`: the glyph, the capability, the count, the bar,
/// and the line that says when it rolls over.
///
/// A meter with `used == null` **draws no bar at all**. The reference fills a
/// bar for every row it lists, including four that count nothing; a bar is a
/// measurement, and drawing one without a measurement is the same class of
/// invention as a fabricated vital sign.
class UsageMeterRow extends StatelessWidget {
  const UsageMeterRow({required this.meter, this.onUpgrade, super.key});

  final UsageMeter meter;

  /// Offered on a locked row only.
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final m = meter;
    final tint = m.locked ? PremiumTone.locked : t.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.09),
                  border: Border.all(color: tint.withValues(alpha: 0.26)),
                ),
                child: Icon(m.icon, size: 18, color: tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(m.blurb,
                        style: const TextStyle(
                            color: HealthTone.dim,
                            fontSize: 10.5,
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Readout(meter: m, onUpgrade: onUpgrade),
            ],
          ),
          if (m.tracked && !m.unlimited) ...[
            const SizedBox(height: 10),
            _MeterBar(fraction: m.fraction, tint: _barTint(m, t.accent)),
          ],
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(m.resetsAt != null ? LucideIcons.clock : LucideIcons.info,
                  size: 11.5, color: HealthTone.faint),
              const SizedBox(width: 5),
              Expanded(
                child: Text(_caption(m),
                    style: const TextStyle(
                        color: HealthTone.faint,
                        fontSize: 10.5,
                        height: 1.3)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _barTint(UsageMeter m, Color accent) {
    if (m.exhausted) return PremiumTone.spent;
    final remaining = m.remaining;
    if (remaining != null && remaining <= 1) return PremiumTone.low;
    return accent;
  }

  static String _caption(UsageMeter m) {
    if (m.note != null) return m.note!;
    if (m.resetsAt != null) return 'Resets ${shortDate(m.resetsAt!)}';
    return 'No limit applies.';
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.meter, this.onUpgrade});

  final UsageMeter meter;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final m = meter;
    if (m.locked) {
      return PremiumChip(
        label: 'PREMIUM',
        icon: LucideIcons.lock,
        tint: PremiumTone.locked,
        key: Key('usage_locked_${m.id}'),
      );
    }
    if (!m.tracked) {
      return const PremiumChip(
          label: 'NOT METERED', tint: PremiumTone.locked);
    }
    final remaining = m.remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '${m.used}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w800)),
            TextSpan(
                text: m.unlimited ? '' : ' / ${m.limit}',
                style: const TextStyle(
                    color: HealthTone.muted, fontSize: 11.5, height: 1.2)),
          ]),
        ),
        const SizedBox(height: 2),
        if (m.unlimited)
          Text(m.window == null ? 'No limit' : 'Unlimited ${m.window}',
              style: TextStyle(
                  color: t.accent, fontSize: 10, fontWeight: FontWeight.w700))
        else
          Text(
              remaining == 0
                  ? 'none left'
                  : '$remaining left${m.window == null ? '' : ' ${m.window}'}',
              style: TextStyle(
                  color: UsageMeterRow._barTint(m, t.accent),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MeterBar extends StatelessWidget {
  const _MeterBar({required this.fraction, required this.tint});

  final double fraction;
  final Color tint;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 7,
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation<Color>(tint),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// 7 · closing blocks
// ---------------------------------------------------------------------------

/// The lit band the references close on — a glyph, a headline, a line of body
/// and a button.
class PremiumBand extends StatelessWidget {
  const PremiumBand({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    this.icon = LucideIcons.crown,
    this.footnote,
    super.key,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;
  final IconData icon;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      accent: t.accent.withValues(alpha: 0.28),
      glow: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumCrest(size: 38, icon: icon),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 14.5,
                            height: 1.2,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: const TextStyle(
                            color: HealthTone.dim,
                            fontSize: 11,
                            height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HealthPrimaryCta(
            label: ctaLabel,
            icon: null,
            trailingIcon: LucideIcons.chevronRight,
            onTap: onCta,
          ),
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(footnote!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: HealthTone.faint, fontSize: 10, height: 1.3)),
          ],
        ],
      ),
    );
  }
}

/// A question the user can open. The references print four on
/// `subscription_plans` and two on `usage_limits`; both sets are answered here
/// from the real billing and data-retention behaviour.
class PremiumFaq extends StatefulWidget {
  const PremiumFaq({required this.items, this.title, super.key});

  final List<({String question, String answer})> items;
  final String? title;

  @override
  State<PremiumFaq> createState() => _PremiumFaqState();
}

class _PremiumFaqState extends State<PremiumFaq> {
  final _open = <int>{};

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title != null) ...[
            Text(widget.title!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
          ],
          for (var i = 0; i < widget.items.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06)),
            InkWell(
              key: Key('faq_$i'),
              onTap: () => setState(
                  () => _open.contains(i) ? _open.remove(i) : _open.add(i)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(widget.items[i].question,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                            _open.contains(i)
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                            color: HealthTone.muted),
                      ],
                    ),
                    if (_open.contains(i)) ...[
                      const SizedBox(height: 7),
                      Text(widget.items[i].answer,
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11.5,
                              height: 1.4)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The card each of these screens carries in place of the reference's social
/// proof: what PawDoc will not claim, said plainly.
///
/// It exists because the alternative to a fabricated "4.9/5 from 10,000+
/// reviews" is not silence — an owner deciding whether to pay deserves to know
/// *why* the numbers are missing.
class PremiumHonestyNote extends StatelessWidget {
  const PremiumHonestyNote({
    required this.lines,
    this.title = 'What PawDoc does not claim',
    super.key,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck,
                  size: 15, color: HealthTone.muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(LucideIcons.minus,
                        size: 10, color: HealthTone.faint),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(line,
                        style: const TextStyle(
                            color: HealthTone.dim,
                            fontSize: 11,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

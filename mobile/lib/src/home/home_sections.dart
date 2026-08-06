import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../pets/pet.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';

/// The composed sections of the home dashboard (mockup `010-home-page`).
///
/// They live apart from `home_screen.dart` because that file already owns the
/// screen's data plumbing, navigation and the pet-switcher, and the mockup adds
/// eight more blocks on top. Everything here is presentation: the screen passes
/// data in and callbacks out.
///
/// **Safety.** The mockup's hero reads *"Buddy is doing great! / No health
/// issues detected"* — an all-clear headline over no evidence, which is the
/// single most dangerous sentence in the whole design set (CLAUDE.md rule 3;
/// `safety_copy_test` bans both phrasings outright). [PetHeroPanel] keeps the
/// mockup's exact shape and replaces the claim with what is actually known:
/// when the pet was last checked.

// ---------------------------------------------------------------------------
// Shared surface
// ---------------------------------------------------------------------------

/// The dark slab every block on this screen sits in.
///
/// Extracted because the mockup uses it eleven times: near-black fill, a
/// hairline that is barely there, and a generous radius.
class HomeCard extends StatelessWidget {
  const HomeCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.s16),
    this.radius = 18,
    this.onTap,
    this.accent,
    this.glow = 0,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Lights the border and adds a bloom — the mockup's "selected" treatment.
  final Color? accent;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final border = accent ?? Colors.white.withValues(alpha: 0.07);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0B),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: accent != null ? 1.4 : 1),
        boxShadow: glow > 0
            ? [
                BoxShadow(
                    color: (accent ?? t.accent).withValues(alpha: glow),
                    blurRadius: 22,
                    spreadRadius: -6)
              ]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// Section heading with an optional trailing link, as the mockup draws them
/// ("Today's Reminders … See All ›").
class HomeCardHeader extends StatelessWidget {
  const HomeCardHeader({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: t.accent),
        const SizedBox(width: 5),
        Expanded(
          child: Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w700)),
        ),
        ?trailing,
        if (actionLabel != null)
          // Constrained rather than padded: a bare TextButton here was a 42dp
          // target, and padding it out pushed the title off-centre.
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!,
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
                Icon(LucideIcons.chevronRight, size: 13, color: t.accent),
              ]),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1 · brand bar
// ---------------------------------------------------------------------------

/// Logo + wordmark, the pet switcher, notifications and the account avatar.
class HomeBrandBar extends StatelessWidget {
  const HomeBrandBar({
    required this.switcher,
    required this.onNotifications,
    required this.onAccount,
    this.hasNotifications = false,
    super.key,
  });

  final Widget switcher;
  final VoidCallback onNotifications;
  final VoidCallback onAccount;
  final bool hasNotifications;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      children: [
        Image.asset(
          AppAssets.logoMark,
          height: 23,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) =>
              Icon(LucideIcons.pawPrint, size: 22, color: t.accent),
        ),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Paw'),
            TextSpan(text: 'Doc', style: TextStyle(color: t.accent)),
          ]),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4),
        ),
        // Expanded, not Spacer + Flexible: the pill was getting whatever the
        // wordmark left over, which truncated a five-letter pet name.
        Expanded(child: Align(alignment: Alignment.centerRight, child: switcher)),
        const SizedBox(width: 2),
        _BarIcon(
          icon: LucideIcons.bell,
          onTap: onNotifications,
          badge: hasNotifications,
          tooltip: 'Reminders',
        ),
        const SizedBox(width: 2),
        Semantics(
          button: true,
          label: 'Account',
          child: IconButton(
            key: const Key('home_account_button'),
            tooltip: 'Account',
            onPressed: onAccount,
            icon: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.accent.withValues(alpha: 0.75), width: 1.6),
              ),
              child: Icon(LucideIcons.user, size: 17, color: t.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 22, color: Colors.white),
          if (badge)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent,
                  border: const Border.fromBorderSide(
                      BorderSide(color: Color(0xFF060A06), width: 1.4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · pet rail
// ---------------------------------------------------------------------------

/// The horizontal gallery of pets, plus the "Add Pet" tile.
class PetRail extends StatelessWidget {
  const PetRail({
    required this.pets,
    required this.activeId,
    required this.onSelect,
    required this.onAdd,
    required this.avatarBuilder,
    super.key,
  });

  final List<Pet> pets;
  final String? activeId;
  final ValueChanged<Pet> onSelect;
  final VoidCallback onAdd;

  /// Supplied by the screen so the rail does not need to know about photo keys
  /// or the living-avatar rig.
  final Widget Function(Pet pet, double size) avatarBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == pets.length) return _AddPetTile(onTap: onAdd);
          final pet = pets[i];
          return _PetRailCard(
            pet: pet,
            selected: pet.id == activeId,
            onTap: () => onSelect(pet),
            avatar: avatarBuilder(pet, 52),
          );
        },
      ),
    );
  }
}

class _PetRailCard extends StatelessWidget {
  const _PetRailCard({
    required this.pet,
    required this.selected,
    required this.onTap,
    required this.avatar,
  });

  final Pet pet;
  final bool selected;
  final VoidCallback onTap;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final subtitle = (pet.breed != null && pet.breed!.trim().isNotEmpty)
        ? pet.breed!.trim()
        : speciesName(pet.species);
    final meta = [
      if (petAgeLabel(pet.birthDate) != null) petAgeLabel(pet.birthDate)!,
      if (pet.sex != null && pet.sex!.isNotEmpty) _sexLabel(pet.sex!),
    ].join(' • ');

    return Semantics(
      button: true,
      selected: selected,
      label: pet.name,
      child: ExcludeSemantics(
        child: HomeCard(
          onTap: onTap,
          radius: 16,
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          accent: selected ? t.accent : null,
          glow: selected ? 0.22 : 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(width: 52, height: 52, child: avatar),
              ),
              const SizedBox(width: 9),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(pet.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, color: t.accent),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF9BA5A0), fontSize: 11.5)),
                  if (meta.isNotEmpty)
                    Text(meta,
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sexLabel(String sex) =>
      sex.isEmpty ? '' : sex[0].toUpperCase() + sex.substring(1);
}

class _AddPetTile extends StatelessWidget {
  const _AddPetTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('home_rail_add_pet'),
      onTap: onTap,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.plus, size: 24, color: Colors.white),
          SizedBox(height: 4),
          Text('Add Pet',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

/// A wellness metric, never a clinical one (owner decision **D-2**): the share
/// of the pet's *record* that is filled in. It says nothing about the animal's
/// health and every surface that renders it captions it so it cannot be read as
/// if it did.
///
/// Lives here rather than on the home screen because three surfaces draw the
/// same dial — home, the analysis result and the assistant — and a second
/// implementation of the same number is how two of them end up disagreeing.
int careScore(Pet pet, {required bool hasCheck, required bool hasReminder}) {
  var filled = 1; // a named pet is the first point
  if (pet.breed != null && pet.breed!.trim().isNotEmpty) filled++;
  if (pet.birthDate != null) filled++;
  if (pet.sex != null && pet.sex!.isNotEmpty) filled++;
  if (pet.photoKey != null) filled++;
  if (hasCheck) filled++;
  if (hasReminder) filled++;
  return (filled * 100 / 7).round();
}

/// `2y 2m`, the age the rail and the record card print. Null when unknown.
String? petAgeLabel(DateTime? birth) {
  if (birth == null) return null;
  final now = DateTime.now();
  var months = (now.year - birth.year) * 12 + now.month - birth.month;
  if (now.day < birth.day) months -= 1;
  if (months < 0) return null;
  return months < 12 ? '${months}m' : '${months ~/ 12}y ${months % 12}m';
}

/// The pet as the mockup draws it: their own photo when there is one, and the
/// photoreal species portrait when there is not.
///
/// Not the living-avatar rig — that draws the illustrated Paw Pal, which is
/// right for a 56dp chip and wrong for a hero the mockup fills with a
/// photograph.
class PetPortrait extends StatelessWidget {
  const PetPortrait({
    required this.pet,
    required this.size,
    this.livingAvatar,
    this.fit = BoxFit.cover,
    super.key,
  });

  final Pet pet;
  final double size;

  /// Supplied by the screen when the pet has an uploaded photo — resolving a
  /// storage key needs providers this file deliberately does not import.
  final Widget? livingAvatar;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (pet.photoKey != null && livingAvatar != null) {
      return SizedBox(width: size, height: size, child: livingAvatar);
    }
    return Image.asset(
      AppAssets.species(pet.species),
      width: size,
      height: size,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: Center(
            child: Text(speciesEmoji(pet.species),
                style: TextStyle(fontSize: size * 0.42))),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · greeting
// ---------------------------------------------------------------------------

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({required this.name, required this.petName, super.key});

  final String? name;
  final String petName;

  static String partOfDay(DateTime now) {
    if (now.hour < 12) return 'morning';
    if (now.hour < 18) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final who = (name == null || name!.trim().isEmpty) ? '' : ', ${name!.trim()}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good ${partOfDay(DateTime.now())}$who! 👋',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Here’s what’s happening with $petName today.',
                  style: const TextStyle(
                      color: Color(0xFF9BA5A0), fontSize: 13.5, height: 1.3)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 42,
          height: 38,
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(19),
              topRight: Radius.circular(19),
              bottomRight: Radius.circular(19),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: Icon(LucideIcons.heart, size: 19, color: t.accent),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · hero
// ---------------------------------------------------------------------------

/// The dashboard's centrepiece: the pet's status line, three at-a-glance
/// signals, the primary action, and the pet lit against a green bloom that
/// bleeds off the card's right edge.
///
/// **Safety.** The mockup titles this *"Buddy is doing great!"* over *"No
/// health issues detected"*. Both are all-clears the app has no basis for and
/// the contract forbids outright — a reassurance with no action is the shape a
/// false negative takes. The layout is reproduced exactly; the claim is
/// replaced by the record: what the last check was, and when.
class PetHeroPanel extends StatelessWidget {
  const PetHeroPanel({
    required this.title,
    required this.subtitle,
    required this.signals,
    required this.ctaLabel,
    required this.onCta,
    required this.art,
    this.ctaKey,
    super.key,
  });

  final String title;
  final String subtitle;

  /// (icon, label, value, available) — the three columns under the title.
  final List<(IconData, String, String, bool)> signals;
  final String ctaLabel;
  final VoidCallback onCta;
  final Widget art;
  final Key? ctaKey;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F0B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // The bloom the pet is lit by, anchored off the right edge.
          Positioned(
            right: -70,
            top: -40,
            bottom: -40,
            width: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    t.accent.withValues(alpha: 0.34),
                    t.accent.withValues(alpha: 0.10),
                    Colors.transparent,
                  ], stops: const [0.0, 0.5, 1.0]),
                ),
              ),
            ),
          ),
          Positioned(
            right: -12,
            top: 0,
            bottom: 0,
            child: IgnorePointer(child: art),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 134, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent.withValues(alpha: 0.12),
                      border:
                          Border.all(color: t.accent.withValues(alpha: 0.45)),
                    ),
                    child: Icon(LucideIcons.shieldCheck,
                        size: 21, color: t.accent),
                  ),
                  const SizedBox(width: 11),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                height: 1.2,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                color: Color(0xFF9BA5A0),
                                fontSize: 12.5,
                                height: 1.25)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpace.s16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < signals.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        _Signal(data: signals[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                SizedBox(
                  width: 236,
                  child: PawPrimaryButton(
                    key: ctaKey,
                    icon: LucideIcons.sparkles,
                    onPressed: onCta,
                    child: Text(ctaLabel),
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

class _Signal extends StatelessWidget {
  const _Signal({required this.data});

  final (IconData, String, String, bool) data;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final (icon, label, value, available) = data;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: available ? t.accent : t.accent.withValues(alpha: 0.45)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9BA5A0), fontSize: 10.5, height: 1.2)),
            const SizedBox(height: 1),
            Text(value,
                style: TextStyle(
                    color: available ? t.accent : const Color(0xFF6C766F),
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6 · reminders and timeline
// ---------------------------------------------------------------------------

/// The mockup's "Today's Reminders" list — an icon tile, two lines, a due
/// stamp, a chevron.
class HomeListCard extends StatelessWidget {
  const HomeListCard({
    required this.icon,
    required this.title,
    required this.rows,
    required this.emptyLabel,
    this.actionLabel,
    this.onAction,
    this.spine = false,
    super.key,
  });

  final IconData icon;
  final String title;

  /// (rowIcon, title, subtitle, trailing, tint, onTap)
  final List<(IconData, String, String, String, Color?, VoidCallback?)> rows;
  final String emptyLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Threads a connecting line down the left of the rows, as the timeline card
  /// draws it.
  final bool spine;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeCardHeader(
              icon: icon,
              title: title,
              actionLabel: actionLabel,
              onAction: onAction),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(emptyLabel,
                  style: const TextStyle(
                      color: Color(0xFF7F8A85), fontSize: 12, height: 1.3)),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _Row(data: rows[i], spine: spine, last: i == rows.length - 1),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.data, required this.spine, required this.last});

  final (IconData, String, String, String, Color?, VoidCallback?) data;
  final bool spine;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final (icon, title, subtitle, trailing, tint, onTap) = data;
    final c = tint ?? t.accent;
    final row = Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 7),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF10160F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: c.withValues(alpha: 0.12),
              border: Border.all(color: c.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 16, color: c),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF7F8A85), fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(trailing,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w600)),
          if (onTap != null)
            const Icon(LucideIcons.chevronRight,
                size: 15, color: Color(0xFF7F8A85)),
        ],
      ),
    );

    final tappable = onTap == null
        ? row
        : Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: row),
          );
    if (!spine) return tappable;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: last ? null : 0,
                  height: last ? 20 : null,
                  child:
                      Container(width: 1.4, color: Colors.white.withValues(alpha: 0.10)),
                ),
                Positioned(
                  top: 16,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: t.accent),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: tappable),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5 · quick actions
// ---------------------------------------------------------------------------

/// The four tiles under the hero: glyph, title, caption.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({required this.items, super.key});

  /// (key, icon, title, caption, onTap, tint)
  final List<(Key, IconData, String, String, VoidCallback, Color?)> items;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        // Four across at 393dp gives ~84dp a tile, which is what the mockup
        // draws; below that they wrap to two rows rather than clipping.
        final perRow = c.maxWidth >= 360 ? 4 : 2;
        final width = (c.maxWidth - (perRow - 1) * 8) / perRow;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (key, icon, title, caption, onTap, tint) in items)
              SizedBox(
                width: width,
                child: HomeCard(
                  key: key,
                  onTap: onTap,
                  radius: 16,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 12),
                  child: Column(
                    children: [
                      Icon(icon, size: 24, color: tint ?? t.accent),
                      const SizedBox(height: 7),
                      Text(title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(caption,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                              color: Color(0xFF7F8A85),
                              fontSize: 9.5,
                              height: 1.2)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 8 · stat strip
// ---------------------------------------------------------------------------

/// The three-cell strip that closes the mockup: a score ring, the last
/// check-up, and the next reminder.
///
/// **D-2.** The mockup labels the ring "Health Score / 92 / Excellent". A
/// number that reads as a verdict on an animal's health, with nothing behind
/// it, is exactly the reliance the product must not invite — so the ring is
/// computed from how complete the pet's *record* is and captioned as such. It
/// is a wellness metric, never a clinical one.
class HomeStatStrip extends StatelessWidget {
  const HomeStatStrip({
    required this.score,
    required this.scoreCaption,
    required this.lastCheckup,
    required this.lastCheckupCaption,
    required this.nextReminder,
    required this.nextReminderCaption,
    super.key,
  });

  final int score;
  final String scoreCaption;
  final String lastCheckup;
  final String lastCheckupCaption;
  final String nextReminder;
  final String nextReminderCaption;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    Widget divider() => Container(
        width: 1,
        height: 96,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.white.withValues(alpha: 0.06));

    return HomeCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 34,
              child: _Cell(
                icon: LucideIcons.heart,
                label: 'Care Score',
                child: Row(children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(t.accent),
                      ),
                      Text('$score',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(scoreCaption,
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
            divider(),
            Expanded(
              flex: 33,
              child: _Cell(
                icon: LucideIcons.stethoscope,
                label: 'Last Checkup',
                child: _ValueBlock(
                  icon: LucideIcons.clock,
                  value: lastCheckup,
                  caption: lastCheckupCaption,
                ),
              ),
            ),
            divider(),
            Expanded(
              flex: 33,
              child: _Cell(
                icon: LucideIcons.bell,
                label: 'Next Reminder',
                iconColor: const Color(0xFFE9C46A),
                child: _ValueBlock(
                  icon: LucideIcons.bellRing,
                  value: nextReminder,
                  caption: nextReminderCaption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.icon,
    required this.label,
    required this.child,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 15, color: iconColor ?? t.accent),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({
    required this.icon,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: const Color(0xFF9BA5A0)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 3),
        Text(caption,
            maxLines: 2,
            style: const TextStyle(
                color: Color(0xFF7F8A85), fontSize: 11, height: 1.25)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';

/// The building blocks the pet-record surfaces are drawn from.
///
/// Six mockups share one skeleton — `health_timeline`, `add_health_record`,
/// `weight_tracking`, `medication_tracker`, `vaccination_manager` and the
/// assistant's `conversation_history`: the same header, the same pet card, the
/// same filter rail, the same statistic tiles, the same record row, the same
/// educational footer. They live here rather than in six screen files for the
/// reason `home_sections.dart` and `result_sections.dart` exist — the screens
/// own the data and the safety rules, and the mockups add presentation on top.
///
/// The dependency runs **assistant → health**, never back: `assistant_screen`
/// already imports this module's timeline and event form, so
/// `conversation_history_screen` importing these primitives adds no cycle.
///
/// ## Safety
///
/// Three of these mockups grade an animal's health in a way the product cannot
/// support, and every one of those claims is replaced here while the layout is
/// reproduced exactly:
///
/// * `vaccination_manager` prints **"Protection Status · Excellent · Fully
///   protected"**. The app knows which records an owner has typed in. It does
///   not know whether an animal is immune — records are partial, schedules are
///   regional, and vaccines can fail. [HealthStatusBadge] states the *record*.
/// * `medication_tracker` prints **"Medication Adherence · 96% · Excellent"**
///   over nothing. Adherence here is computed from doses the owner actually
///   ticked off, and reads as a statement about the routine, never about the
///   animal.
/// * `weight_tracking` bands every entry **"Ideal"** against an ideal range the
///   app invented. Ideal weight is a body-condition judgement a vet makes; the
///   band ships as the owner's own target, entered by them, or not at all.
///
/// And `health_timeline`'s "Health Score · 92 · Excellent" is the Care Score
/// under owner decision D-2 — record completeness, captioned as such.

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// The greys and decorative tints the record surfaces use.
///
/// **None of these may be one of the action ladder's four safety-locked hues**
/// (`emergencyDark`, `monitorDark`, `actionBookVisit`, `actionWatch`). The
/// mockups tint medication forms and vaccine classes freely, and two of their
/// choices land on the ladder's amber and red — a red pill glyph beside a
/// medicine name reads as a severity signal. `health_tone_test.dart` pins the
/// separation, exactly as `AssistantTone` is pinned for the message actions.
class HealthTone {
  const HealthTone._();

  // Text ramp (the same values `home_sections` and `assistant_sections` use;
  // duplicated rather than imported so this module depends on neither).
  static const Color muted = Color(0xFF9BA5A0);
  static const Color dim = Color(0xFF8A948D);
  static const Color faint = Color(0xFF7F8A85);

  /// Raised rows inside a card.
  static const Color raised = Color(0xFF10160F);

  /// Card fill, matching [HomeCard].
  static const Color card = Color(0xFF0A0F0B);

  // Decorative tints.
  /// Chewables, and the "non-core" vaccine class.
  static const Color violet = Color(0xFFC084FC);

  /// Tablets, lab work, informational glyphs. Distinct from `actionBookVisit`.
  static const Color info = Color(0xFF4FC3F7);

  /// Liquids and oral suspensions. Warm, and deliberately not the MONITOR amber.
  static const Color gold = Color(0xFFE9C46A);

  /// Topicals. `coral400Dark` is documented in `design_tokens.dart` as warmth
  /// only, never status.
  static const Color coral = AppColors.coral400Dark;

  /// Teal for lifestyle/optional classes.
  static const Color teal = Color(0xFF5EEAD4);

  /// Every decorative tint above, for the guard test.
  static const List<Color> all = [violet, info, gold, coral, teal];
}

// ---------------------------------------------------------------------------
// 1 · chrome
// ---------------------------------------------------------------------------

/// A circled icon button — the affordance every record mockup puts in its
/// header. Drawn at [size] with the tap target padded out to 48dp regardless,
/// because the mockups draw these at ~30dp and a 30dp target is not tappable.
class HealthCircleButton extends StatelessWidget {
  const HealthCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.size = 34,
    this.badge = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  /// The notification dot `medication_tracker` puts on its bell.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF101610),
                      border: Border.all(color: c.withValues(alpha: 0.28)),
                    ),
                    child: Icon(icon, size: size * 0.47, color: c),
                  ),
                  if (badge)
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PawTone.of(context).accent,
                          border: const Border.fromBorderSide(
                              BorderSide(color: Color(0xFF000608), width: 1.4)),
                        ),
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

/// The record surfaces' header: a circled back button, a centred title with an
/// optional leading glyph, circled actions on the right, and a two-tone
/// subtitle underneath ("**Buddy's** health journey", the possessive in lime).
class PetModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PetModuleAppBar({
    required this.title,
    required this.subtitle,
    this.subtitleLead,
    this.subtitleTrail,
    this.icon,
    this.actions = const [],
    this.actionsWidth,
    this.onBack,
    super.key,
  });

  final String title;

  /// The remainder of the subtitle, after [subtitleLead].
  final String subtitle;

  /// Rendered in the accent before [subtitle] — every mockup lights the pet's
  /// name (or the product's) and greys the rest.
  final String? subtitleLead;

  /// Rendered in the accent *after* [subtitle]. `reminder_detail` and
  /// `pet_profile` put the lit name at the end of the sentence ("Never miss
  /// what matters for **Buddy**", "All about **Buddy**") rather than the start.
  final String? subtitleTrail;

  final IconData? icon;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// How much room to keep clear on the right. Defaults to 48dp per action,
  /// which is right for circled buttons; a screen whose action is a wider
  /// lozenge ("Edit") passes its own so a long title can never sit under it.
  final double? actionsWidth;

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 74,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 0, 9, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: HealthCircleButton(
                        key: const Key('module_back'),
                        icon: LucideIcons.chevronLeft,
                        tooltip: 'Back',
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    // Padded past both slots so a long title can never sit
                    // under a button.
                    Padding(
                      padding: EdgeInsets.only(
                        left: 48,
                        right: actionsWidth ??
                            (actions.isEmpty ? 48 : actions.length * 48.0),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 19, color: t.accent),
                              const SizedBox(width: 7),
                            ],
                            Flexible(
                              child: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      height: 1.1,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              // Shrink-to-fit: the subtitle carries the pet's name, and a name
              // long enough to ellipsise would cut the sentence in half.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(children: [
                    if (subtitleLead != null)
                      TextSpan(
                        text: subtitleLead,
                        style: TextStyle(
                            color: t.accent, fontWeight: FontWeight.w600),
                      ),
                    TextSpan(text: subtitle),
                    if (subtitleTrail != null)
                      TextSpan(
                        text: subtitleTrail,
                        style: TextStyle(
                            color: t.accent, fontWeight: FontWeight.w600),
                      ),
                  ]),
                  maxLines: 1,
                  style: const TextStyle(
                      color: HealthTone.muted, fontSize: 12.5, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered icon+label lozenge — the small secondary button the mockups use
/// wherever a tap is offered beside a heading or in the app bar: "Edit",
/// "View Calendar", "View All", "View Clinic".
///
/// Extracted from [HealthSectionHead]'s boxed action, which had the glyph
/// hardcoded; `reminder_detail` draws three of these with three different
/// glyphs and `pet_profile` puts one in the header.
class HealthActionPill extends StatelessWidget {
  const HealthActionPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.dense = false,
    super.key,
  });

  final String label;

  /// Nullable so a heading can present the pill as a static caption — which is
  /// what `medication_tracker` does with "Next 12 months".
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  /// Tighter padding, for the app-bar slot where height is fixed at 48.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = color ?? PawTone.of(context).accent;
    return Semantics(
      button: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: dense ? 11 : 9, vertical: dense ? 7 : 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: c.withValues(alpha: 0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: c),
                  const SizedBox(width: 5),
                ],
                // Flexible, not bare: `mainAxisSize.min` still lets a long
                // label ("Open the vaccination manager") take its natural
                // width and blow the row out. The widget test found this at
                // the em-square font, which is the large-text case a real
                // handset would have hit.
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c,
                          fontSize: dense ? 12 : 11.5,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// `Title ........ action ›` — the record mockups' in-card section heading.
class HealthSectionHead extends StatelessWidget {
  const HealthSectionHead({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.leading,
    this.chevron = true,
    this.actionColor,
    this.actionBoxed = false,
    this.actionIcon,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;
  final bool chevron;
  final Color? actionColor;

  /// `medication_tracker` and `health_timeline` draw their heading action as a
  /// bordered lozenge ("View Treatment Plan", "View Calendar") rather than a
  /// bare link.
  final bool actionBoxed;

  /// The glyph inside that lozenge. Defaults to the list mark the medication
  /// screens use; `reminder_detail` wants a calendar on its schedule card.
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = actionColor ?? t.accent;
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 7)],
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700)),
        ),
        if (actionLabel != null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: actionBoxed
                ? HealthActionPill(
                    label: actionLabel!,
                    icon: actionIcon ?? LucideIcons.list,
                    color: c,
                    onTap: onAction,
                  )
                : InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(actionLabel!,
                            style: TextStyle(
                                color: c,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                        if (chevron)
                          Icon(LucideIcons.chevronRight, size: 13, color: c),
                      ]),
                    ),
                  ),
          ),
      ],
    );
  }
}

/// The date bar between groups of records — `Today`, `May 19, 2026`.
class HealthGroupLabel extends StatelessWidget {
  const HealthGroupLabel({required this.label, this.accent = false, super.key});

  final String label;

  /// `health_timeline` lights its `Today` label; `conversation_history` does
  /// not.
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 11, 2, 6),
        child: Text(label,
            style: TextStyle(
                color: accent ? PawTone.of(context).accent : HealthTone.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

// ---------------------------------------------------------------------------
// 2 · the pet header card
// ---------------------------------------------------------------------------

/// The pet, ringed in light, as every record mockup opens: portrait, name with
/// a switcher chevron, `Breed · age · weight`, and — on five of the six — a
/// "View Profile" pill.
///
/// [trailing] is the block each screen hangs on the right: the Care Score dial,
/// the current weight, the adherence bar, the record-status badge. [aside]
/// is drawn *outside* the card, which is how `conversation_history` places its
/// "All Pets" pill.
class PetModuleHeaderCard extends StatelessWidget {
  const PetModuleHeaderCard({
    required this.portrait,
    required this.name,
    required this.meta,
    required this.onSwitch,
    this.onViewProfile,
    this.trailing,
    this.aside,
    super.key,
  });

  final Widget portrait;
  final String name;
  final String meta;
  final VoidCallback onSwitch;
  final VoidCallback? onViewProfile;
  final Widget? trailing;
  final Widget? aside;

  @override
  Widget build(BuildContext context) {
    final card = HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      onTap: onSwitch,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HealthRingPortrait(portrait: portrait, size: 52),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(name,
                        key: const Key('module_pet_name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 3),
                  const Icon(LucideIcons.chevronDown,
                      size: 15, color: Colors.white70),
                ]),
                const SizedBox(height: 1),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 11.5, height: 1.25)),
                if (onViewProfile != null) ...[
                  const SizedBox(height: 5),
                  _ViewProfilePill(onTap: onViewProfile!),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
    if (aside == null) return card;
    return Row(
      children: [
        // Loose, not expanded: the mockup's card hugs its content and leaves
        // the black gap before the aside.
        Flexible(fit: FlexFit.loose, child: card),
        const SizedBox(width: 10),
        aside!,
      ],
    );
  }
}

class _ViewProfilePill extends StatelessWidget {
  const _ViewProfilePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('module_view_profile'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        // Flexible, not fixed: the header card shares its width with whatever
        // the screen hangs on the right (a Care Score dial, an adherence bar),
        // and at a large text scale this pill was the thing that overflowed.
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.user, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text('View Profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

/// The pet's portrait inside the mockups' ring of light, with the paw badge
/// pinned bottom-right.
class HealthRingPortrait extends StatelessWidget {
  const HealthRingPortrait({
    required this.portrait,
    this.size = 52,
    super.key,
  });

  final Widget portrait;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Container(
              width: size + 6,
              height: size + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.accent, width: 1.6),
                boxShadow: [
                  BoxShadow(
                      color: t.accent.withValues(alpha: 0.30), blurRadius: 12),
                ],
              ),
              child: Center(
                child: ClipOval(
                  child: SizedBox(width: size, height: size, child: portrait),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent,
                border: const Border.fromBorderSide(
                    BorderSide(color: Color(0xFF0A0F0B), width: 1.6)),
              ),
              child: const Icon(LucideIcons.pawPrint,
                  size: 10, color: Color(0xFF06110A)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The lozenge `conversation_history` hangs beside the pet card.
class HealthAsidePill extends StatelessWidget {
  const HealthAsidePill({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: HealthTone.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: t.accent),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 3),
          const Icon(LucideIcons.chevronRight, size: 14, color: Colors.white54),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · the filter rail
// ---------------------------------------------------------------------------

/// The rounded search box. `conversation_history` and `manage_multiple_pets`
/// both draw one; the hint differs, the shape does not.
class HealthSearchField extends StatelessWidget {
  const HealthSearchField({
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.autofocus = true,
    this.fieldKey,
    this.onSubmitted,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;
  final Key? fieldKey;

  /// So a screen can hand focus to the field from somewhere else on the page.
  /// The first-aid guide's hero button is a "start here" affordance, and what
  /// it does is put the cursor in the search box.
  final FocusNode? focusNode;

  /// Fired on the keyboard's search key. `search_memories` uses it to decide
  /// what to *remember* — storing every keystroke would fill the recent list
  /// with the prefixes of one word.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.search, size: 16, color: HealthTone.muted),
        const SizedBox(width: 9),
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction:
                onSubmitted == null ? null : TextInputAction.search,
            autofocus: autofocus,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  const TextStyle(color: HealthTone.faint, fontSize: 13.5),
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          InkWell(
            onTap: () {
              controller.clear();
              onChanged('');
            },
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(LucideIcons.x, size: 15, color: HealthTone.muted),
            ),
          ),
      ]),
    );
  }
}

/// One entry in [HealthFilterChips].
class HealthFilter {
  const HealthFilter(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

/// The scrolling chip rail four of the six mockups put under the pet card,
/// with the optional trailing round button `conversation_history` adds.
class HealthFilterChips extends StatelessWidget {
  const HealthFilterChips({
    required this.filters,
    required this.selected,
    required this.onSelect,
    this.trailing,
    super.key,
  });

  final List<HealthFilter> filters;
  final String selected;
  final ValueChanged<String> onSelect;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, i) {
                final f = filters[i];
                final on = f.id == selected;
                return Center(
                  child: InkWell(
                    key: Key('health_filter_${f.id}'),
                    onTap: () => onSelect(f.id),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        color: on
                            ? t.accent.withValues(alpha: 0.16)
                            : HealthTone.card,
                        border: Border.all(
                          color: on
                              ? t.accent.withValues(alpha: 0.70)
                              : Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(f.icon,
                            size: 14,
                            color: on ? t.accent : Colors.white70),
                        const SizedBox(width: 6),
                        Text(f.label,
                            style: TextStyle(
                                color: on ? t.accent : Colors.white,
                                fontSize: 12,
                                fontWeight:
                                    on ? FontWeight.w700 : FontWeight.w500)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          if (trailing != null) ...[
            // A hard black gap so a scrolling chip never slides under the
            // button and reads as a rendering fault.
            Container(width: 10, color: const Color(0xFF000608)),
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: trailing,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · statistic tiles
// ---------------------------------------------------------------------------

/// How a statistic cell arranges its glyph.
enum HealthStatLayout {
  /// Glyph on its own line above the value — `medication_tracker`.
  stacked,

  /// Glyph to the left of the value, label beneath both —
  /// `conversation_history`, `health_timeline`, `vaccination_manager`.
  inline,
}

/// One cell of [HealthStatTiles].
class HealthStat {
  const HealthStat({
    required this.icon,
    required this.value,
    required this.label,
    this.caption,
    this.captionColor,
    this.tint,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;

  /// The third line four mockups add under the label ("Right now", "Upcoming").
  final String? caption;
  final Color? captionColor;
  final Color? tint;

  /// `manage_multiple_pets` turns its caption into a link ("View all ›"), so a
  /// tile can be the affordance rather than just a readout.
  final VoidCallback? onTap;
}

/// The statistics strip. [grouped] draws the single card with hairline
/// dividers `health_timeline` and `conversation_history` use; the default
/// draws the separate tiles `medication_tracker` and `vaccination_manager` do.
class HealthStatTiles extends StatelessWidget {
  const HealthStatTiles({
    required this.stats,
    this.grouped = false,
    this.title,
    this.layout = HealthStatLayout.inline,
    this.ringedIcons = false,
    super.key,
  });

  final List<HealthStat> stats;
  final bool grouped;
  final String? title;
  final HealthStatLayout layout;

  /// `conversation_history` draws each glyph inside a thin ring; the health
  /// screens draw it bare.
  final bool ringedIcons;

  @override
  Widget build(BuildContext context) {
    if (grouped) {
      return HomeCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 11),
                child: Text(title!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
              ),
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        indent: 2,
                        endIndent: 2,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    Expanded(
                      child: _StatCell(
                        stat: stats[i],
                        boxed: false,
                        layout: layout,
                        ringed: ringedIcons,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: HomeCard(
                radius: 14,
                padding: const EdgeInsets.fromLTRB(9, 10, 6, 10),
                onTap: stats[i].onTap,
                child: _StatCell(
                  stat: stats[i],
                  boxed: true,
                  layout: layout,
                  ringed: ringedIcons,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.stat,
    required this.boxed,
    required this.layout,
    required this.ringed,
  });

  final HealthStat stat;
  final bool boxed;
  final HealthStatLayout layout;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final tint = stat.tint ?? t.accent;

    Widget glyph() {
      if (!ringed) return Icon(stat.icon, size: 17, color: tint);
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.3),
        ),
        child: Icon(stat.icon, size: 13, color: tint),
      );
    }

    // Shrink-to-fit rather than ellipsis: a count reading "1…" is worse than
    // one a point smaller.
    final value = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(stat.value,
          maxLines: 1,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              height: 1.1,
              fontWeight: FontWeight.w800)),
    );
    // A fixed two-line slot, for two reasons. The mockups set these labels at
    // ~8dp, where "Total conversations" fits a third of the card; at readable
    // type it does not, and "Total con…" is worse than a wrap. And the slot has
    // to be *explicit*: inside an IntrinsicHeight a Text reports its unwrapped
    // single-line height, so the row sizes to one line and the second one is
    // clipped away. Giving the box a height also makes every cell align without
    // the intrinsic pass having to guess.
    final label = SizedBox(
      height: 25,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(stat.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: HealthTone.muted, fontSize: 10, height: 1.2)),
      ),
    );
    final caption = stat.caption == null
        ? null
        : Text(stat.caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: stat.captionColor ?? tint,
                fontSize: 10,
                height: 1.25,
                fontWeight: FontWeight.w600));

    final Widget body = switch (layout) {
      HealthStatLayout.stacked => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            glyph(),
            const SizedBox(height: 7),
            value,
            const SizedBox(height: 1),
            label,
            if (caption != null) ...[const SizedBox(height: 1), caption],
          ],
        ),
      HealthStatLayout.inline => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            glyph(),
            SizedBox(width: ringed ? 7 : 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [value, label, ?caption],
              ),
            ),
          ],
        ),
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: boxed ? 0 : 5),
      child: body,
    );
  }
}

// ---------------------------------------------------------------------------
// 5 · the record row
// ---------------------------------------------------------------------------

/// A small tinted disc holding a glyph — the leading mark on every record row.
class HealthGlyphDisc extends StatelessWidget {
  const HealthGlyphDisc({
    required this.icon,
    required this.tint,
    this.size = 42,
    this.square = false,
    this.outlined = false,
    super.key,
  });

  final IconData icon;
  final Color tint;
  final double size;
  final bool square;

  /// `vaccination_manager`'s history rows draw a ring rather than a fill.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(12) : null,
        color: tint.withValues(alpha: outlined ? 0.06 : 0.14),
        border: Border.all(color: tint.withValues(alpha: outlined ? 0.55 : 0.28)),
      ),
      child: Icon(icon, size: size * 0.46, color: tint),
    );
  }
}

/// The chip a record row carries beside its title — a vaccine class, a
/// medication form, a conversation topic.
class HealthPill extends StatelessWidget {
  const HealthPill({
    required this.label,
    required this.tint,
    this.icon,
    this.filled = true,
    super.key,
  });

  final String label;
  final Color tint;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: filled ? tint.withValues(alpha: 0.14) : Colors.transparent,
        border: Border.all(color: tint.withValues(alpha: 0.42)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: tint),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: tint, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// One record: a tinted glyph, a title with optional chips, a subtitle, an
/// optional right-hand block, and a chevron.
///
/// This is the row `medication_tracker`, `vaccination_manager`,
/// `weight_tracking`, `health_timeline` and `conversation_history` all draw
/// with different fillings. Everything is a slot; nothing is screen-specific.
class HealthRecordRow extends StatelessWidget {
  const HealthRecordRow({
    required this.leading,
    required this.title,
    this.titleChips = const [],
    this.subtitle,
    this.footer,
    this.middle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron = true,
    this.padding = const EdgeInsets.all(9),
    this.background,
    super.key,
  });

  final Widget leading;
  final String title;
  final List<Widget> titleChips;
  final String? subtitle;

  /// A row beneath the subtitle — the category chip and photo count on a
  /// conversation, the "View Details" pill on a timeline event.
  final Widget? footer;

  /// The column the medication rows put between the name and the dates.
  final Widget? middle;

  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool chevron;
  final EdgeInsetsGeometry padding;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? HealthTone.raised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Weighted shares, not one Flexible against fixed chips.
                    // Two equal Flexibles split the row evenly and squeeze a
                    // name that had room; fixed chips overflow it at a large
                    // text scale. 3:2 lets the title take what it needs and
                    // both give proportionally when the row is genuinely short.
                    Row(children: [
                      Flexible(
                        flex: 3,
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700)),
                      ),
                      for (final chip in titleChips) ...[
                        const SizedBox(width: 5),
                        Flexible(flex: 2, child: chip),
                      ],
                    ]),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11.5,
                              height: 1.25)),
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: 5),
                      footer!,
                    ],
                  ],
                ),
              ),
              if (middle != null) ...[
                const SizedBox(width: 8),
                middle!,
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (chevron)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(LucideIcons.chevronRight,
                      size: 16, color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right-hand two-line block: a value over a caption, right-aligned. Used for
/// dates, schedules and "Started / Ends" pairs.
class HealthMetaBlock extends StatelessWidget {
  const HealthMetaBlock({
    required this.lines,
    this.align = CrossAxisAlignment.end,
    this.leadColor,
    super.key,
  });

  /// `(text, isLead)` — the lead line is brighter.
  final List<(String, bool)> lines;
  final CrossAxisAlignment align;
  final Color? leadColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        for (final (text, lead) in lines)
          Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: align == CrossAxisAlignment.end
                  ? TextAlign.right
                  : TextAlign.left,
              style: TextStyle(
                  color: lead
                      ? (leadColor ?? Colors.white)
                      : HealthTone.faint,
                  fontSize: lead ? 11.5 : 10.5,
                  height: 1.3,
                  fontWeight: lead ? FontWeight.w600 : FontWeight.w400)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6 · status badge
// ---------------------------------------------------------------------------

/// The badge `vaccination_manager` and `medication_tracker` put in the pet
/// card's right slot.
///
/// **Safety.** The mockup's version reads "Protection Status · Excellent ·
/// Fully protected" — an assertion of immunity the app has no basis for. What
/// it actually knows is the state of the *record*, and that is what this
/// states. See the file header.
class HealthStatusBadge extends StatelessWidget {
  const HealthStatusBadge({
    required this.caption,
    required this.value,
    required this.detail,
    required this.icon,
    this.tint,
    this.progress,
    super.key,
  });

  final String caption;
  final String value;
  final String detail;
  final IconData icon;
  final Color? tint;

  /// 0..1 — draws the mockup's segmented bar under the value.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = tint ?? t.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: HealthTone.muted, fontSize: 10.5, height: 1.2)),
        const SizedBox(height: 3),
        Row(children: [
          Icon(icon, size: 17, color: c),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      color: c,
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 5),
          _SegmentBar(value: progress!.clamp(0, 1), tint: c),
        ],
        const SizedBox(height: 3),
        Text(detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: HealthTone.faint, fontSize: 10, height: 1.2)),
      ],
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.value, required this.tint});

  final double value;
  final Color tint;

  static const _segments = 10;

  @override
  Widget build(BuildContext context) {
    final lit = (value * _segments).round();
    return Row(
      children: [
        for (var i = 0; i < _segments; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i < lit ? tint : Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 7 · footer blocks
// ---------------------------------------------------------------------------

/// The dashed "add a record" card five mockups put above their CTA.
class HealthAddCard extends StatelessWidget {
  const HealthAddCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = LucideIcons.plus,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Material(
      color: t.accent.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: HealthDashedPainter(t.accent.withValues(alpha: 0.45),
              radius: 14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.accent.withValues(alpha: 0.65)),
                  ),
                  child: Icon(icon, size: 16, color: t.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 13.5,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11,
                              height: 1.25)),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight,
                    size: 16, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The educational footer three mockups close with: a glyph, a heading, two
/// lines of copy and a decorative mark on the right.
class HealthEduCard extends StatelessWidget {
  const HealthEduCard({
    required this.title,
    required this.body,
    this.icon = LucideIcons.lightbulb,
    this.art,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 16, color: t.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(
                        color: HealthTone.dim, fontSize: 11, height: 1.35)),
              ],
            ),
          ),
          if (art != null) ...[const SizedBox(width: 8), art!],
        ],
      ),
    );
  }
}

/// The privacy reassurance card. `conversation_history` and
/// `add_health_record` both draw one; the copy differs, the shape does not.
class HealthPrivacyCard extends StatelessWidget {
  const HealthPrivacyCard({
    required this.title,
    required this.body,
    required this.onTap,
    this.actionLabel,
    super.key,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      onTap: actionLabel == null ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.10),
              border: Border.all(color: t.accent.withValues(alpha: 0.30)),
            ),
            child: Icon(LucideIcons.shieldCheck, size: 19, color: t.accent),
          ),
          const SizedBox(width: 11),
          // The title takes the full width and the action sits under it, at
          // the right, level with the last line of the body — which is where
          // the mockup puts "Learn more ›". Setting it beside the title
          // instead squeezed the heading onto two lines on the device.
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
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(body,
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11,
                              height: 1.35)),
                    ),
                    if (actionLabel != null)
                      InkWell(
                        key: const Key('health_privacy_action'),
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 2, 2),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(actionLabel!,
                                style: TextStyle(
                                    color: t.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            Icon(LucideIcons.chevronRight,
                                size: 14, color: t.accent),
                          ]),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (actionLabel == null) ...[
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: Colors.white54),
          ],
        ],
      ),
    );
  }
}

/// The destructive footer card `conversation_history` closes with.
class HealthDangerCard extends StatelessWidget {
  const HealthDangerCard({
    required this.title,
    required this.body,
    required this.onTap,
    this.icon = LucideIcons.trash2,
    super.key,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 21, color: t.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(body,
                    style: const TextStyle(
                        color: HealthTone.dim, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 17, color: Colors.white54),
        ],
      ),
    );
  }
}

/// The full-width lime CTA the record mockups pin above the nav bar.
class HealthPrimaryCta extends StatelessWidget {
  const HealthPrimaryCta({
    required this.label,
    required this.onTap,
    this.icon = LucideIcons.plus,
    this.trailingIcon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  /// The ringed glyph before the label. `null` drops the ring entirely, which
  /// is how `add_memory` draws its wizard button.
  ///
  /// **This was accepted and ignored until this batch** — the body drew a
  /// hardcoded `plus`, so the journal's "See Premium" button rendered a crown
  /// argument as a **+**. It is honoured now.
  final IconData? icon;

  /// A bare glyph *after* the label — `add_memory`'s "Next: Add Tags ›".
  final IconData? trailingIcon;

  /// A disabled CTA still occupies its slot; the wizard greys it rather than
  /// removing it, so the footer does not jump between steps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    const ink = Color(0xFF06110A);
    final fill = enabled ? t.accent : t.accent.withValues(alpha: 0.22);
    final fg = enabled ? ink : Colors.white.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: fg.withValues(alpha: 0.55)),
                      ),
                      child: Icon(icon, size: 13, color: fg),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 17, color: fg),
                  ],
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
// 8 · layout
// ---------------------------------------------------------------------------

/// The page gutter every record mockup measures at 17dp.
const double kRecordGutter = 17;

/// Standard horizontal padding for a record page's scroll body.
const EdgeInsets kRecordPadding =
    EdgeInsets.symmetric(horizontal: kRecordGutter);

/// Marks a child of [HealthRecordScaffold] that paints edge-to-edge instead of
/// inside the page gutter — the filter rails, which scroll past both margins.
class HealthBleed extends StatelessWidget {
  const HealthBleed({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A record screen: the module header, a scrolling body under it, an optional
/// pinned footer, and the app's bottom navigation — which every one of these
/// mockups draws, and which is why `PawNavBar` learned a detached mode.
///
/// The gutter is applied per child rather than to the scroll view, so a
/// [HealthBleed] can opt out of it. Negative padding is not a thing.
class HealthRecordScaffold extends StatelessWidget {
  const HealthRecordScaffold({
    required this.appBar,
    required this.children,
    this.footer,
    this.bottomNav,
    this.onRefresh,
    super.key,
  });

  final PreferredSizeWidget appBar;
  final List<Widget> children;
  final Widget? footer;
  final Widget? bottomNav;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    // A Column in a scroll view, not a lazy ListView: laziness hides content
    // from tests and from screen readers alike (result-screen lesson).
    Widget body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: footer == null ? 16 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            if (child is HealthBleed)
              child
            else
              Padding(padding: kRecordPadding, child: child),
        ],
      ),
    );
    if (onRefresh != null) {
      body = RefreshIndicator(
        color: PawTone.of(context).accent,
        backgroundColor: HealthTone.card,
        onRefresh: onRefresh!,
        child: body,
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: Column(
        children: [
          Expanded(child: body),
          if (footer != null)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(kRecordGutter, 0, kRecordGutter, 8),
              child: footer,
            ),
        ],
      ),
      bottomNavigationBar: bottomNav,
    );
  }
}

/// Vertical rhythm helper — `gap(12)` reads better than a bare SizedBox in a
/// 30-child column.
Widget gap(double height) => SizedBox(height: height);

/// The surface every record menu and detail sheet sits on.
///
/// `showModalBottomSheet` is opened transparent so the corners can be rounded,
/// which means the sheet has to draw its own panel — without it the rows float
/// over the page and the whole thing reads as a rendering fault. (Learned the
/// hard way on the assistant's pet and More menus.)
class HealthSheet extends StatelessWidget {
  const HealthSheet({
    required this.children,
    this.title,
    this.scrollable = false,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpace.s16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
    return PawSystemScope(
      system: PawSystem.b,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: HealthTone.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, AppSpace.s12, AppSpace.s16, AppSpace.s16),
            child: scrollable
                ? SingleChildScrollView(child: column)
                : column,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8b · sparkline
// ---------------------------------------------------------------------------

/// A bare trend line, no axes — the mark `pet_statistics` puts under each
/// overview tile and the result screen puts on its Track Symptoms cell.
///
/// **[points] are counts, never grades.** A line that trended better or worse
/// would be a graded verdict on an animal drawn from nothing; what these plot
/// is how much was *logged*, which is a fact about the record.
class HealthSparkline extends StatelessWidget {
  const HealthSparkline({
    required this.points,
    required this.tint,
    this.height = 42,
    this.dots = true,
    this.fill = false,
    super.key,
  });

  /// 0..1, oldest first. Fewer than two points draws nothing.
  final List<double> points;
  final Color tint;
  final double height;
  final bool dots;
  final bool fill;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: points.length < 2
            ? const SizedBox.shrink()
            : CustomPaint(
                painter: _SparkPainter(points, tint, dots: dots, fill: fill),
                size: Size.infinite,
              ),
      );
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.points, this.tint,
      {this.dots = true, this.fill = false});

  final List<double> points;
  final Color tint;
  final bool dots;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final dx = size.width / (points.length - 1);
    Offset at(int i) =>
        Offset(dx * i, size.height * (1 - points[i].clamp(0, 1)));

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = tint.withValues(alpha: 0.12));
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tint,
    );
    if (dots) {
      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(at(i), 3.2, Paint()..color = tint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points ||
      old.tint != tint ||
      old.dots != dots ||
      old.fill != fill;
}

// ---------------------------------------------------------------------------
// 9 · the two-column fact grid
// ---------------------------------------------------------------------------

/// One cell of [HealthInfoGrid].
class HealthInfoCell {
  const HealthInfoCell({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.captionColor,
    this.tint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// The accent third line — `reminder_detail`'s "In 12 days" under its next
  /// date.
  final String? caption;
  final Color? captionColor;
  final Color? tint;
  final VoidCallback? onTap;
}

/// The paired fact grid `reminder_detail` and `pet_profile` both draw: two
/// columns of glyph + label + value, hairline-ruled between rows and down the
/// middle.
///
/// Every text is single-line on purpose. Inside an [IntrinsicHeight] a `Text`
/// reports its *unwrapped* height, so a value that wanted to wrap would be
/// clipped to one line and the rest silently lost — the same trap the statistic
/// tiles hit. Values shrink to fit instead.
class HealthInfoGrid extends StatelessWidget {
  const HealthInfoGrid({required this.cells, super.key});

  final List<HealthInfoCell> cells;

  @override
  Widget build(BuildContext context) {
    final hairline = Colors.white.withValues(alpha: 0.06);
    final rows = <(HealthInfoCell, HealthInfoCell?)>[
      for (var i = 0; i < cells.length; i += 2)
        (cells[i], i + 1 < cells.length ? cells[i + 1] : null),
    ];
    return HomeCard(
      radius: 16,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0)
              Divider(
                  height: 1,
                  thickness: 1,
                  indent: 11,
                  endIndent: 11,
                  color: hairline),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _InfoCell(cell: rows[r].$1)),
                  VerticalDivider(
                      width: 1,
                      thickness: 1,
                      indent: 9,
                      endIndent: 9,
                      color: hairline),
                  Expanded(
                    child: rows[r].$2 == null
                        ? const SizedBox.shrink()
                        : _InfoCell(cell: rows[r].$2!),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.cell});

  final HealthInfoCell cell;

  @override
  Widget build(BuildContext context) {
    final tint = cell.tint ?? PawTone.of(context).accent;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(11, 11, 9, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(cell.icon, size: 17, color: tint),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cell.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 10.5, height: 1.2)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(cell.value,
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600)),
                ),
                if (cell.caption != null) ...[
                  const SizedBox(height: 1),
                  Text(cell.caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cell.captionColor ?? tint,
                          fontSize: 10.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (cell.onTap == null) return body;
    return InkWell(
        onTap: cell.onTap,
        borderRadius: BorderRadius.circular(12),
        child: body);
  }
}

/// `glyph  Label ........ value ›` — the settings rows `reminder_detail` lists
/// under Notification Settings, and the same shape `pet_profile` uses.
///
/// [soon] greys the value and drops the chevron: the control is drawn, in
/// place, but nothing is behind it yet. A row that looks tappable and is not is
/// worse than one that says so.
class HealthSettingRow extends StatelessWidget {
  const HealthSettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.valueColor,
    this.soon = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 16, color: soon ? HealthTone.faint : t.accent),
            const SizedBox(width: 10),
            // Weighted shares, never two bare Flexibles: an even split squeezes
            // a label that had room, and a fixed neighbour overflows the row
            // under the em-square test font.
            Flexible(
              flex: 4,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: soon ? HealthTone.muted : Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 6,
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: soon
                          ? HealthTone.faint
                          : (valueColor ?? t.accent),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500)),
            ),
            if (!soon && onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(LucideIcons.chevronRight,
                    size: 15, color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }
}

/// The bordered "All Types ⌄" lozenge the journal and the search surface put
/// their filters in — an optional glyph, a label, and a chevron.
///
/// `memories_gallery` had a private one of these; `search_memories` draws four
/// in a row, and a second implementation is how the two rows end up a point
/// apart in height.
class HealthDropPill extends StatelessWidget {
  const HealthDropPill({
    required this.fieldKey,
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
    super.key,
  });

  final Key fieldKey;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Lights the border when the filter is doing something — the reference
  /// draws every pill in its resting state, which never shows what "set"
  /// looks like.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Material(
      color: active ? t.accent.withValues(alpha: 0.08) : HealthTone.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: fieldKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active
                    ? t.accent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: t.accent),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active ? t.accent : Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronDown,
                size: 15, color: HealthTone.muted),
          ]),
        ),
      ),
    );
  }
}

/// A label/value pair, as the detail sheets list a record's contents.
class HealthDetailRow extends StatelessWidget {
  const HealthDetailRow({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: HealthTone.muted),
            const SizedBox(width: 9),
          ],
          SizedBox(
            width: 104,
            child: Text(label,
                style: const TextStyle(
                    color: HealthTone.muted, fontSize: 11.5, height: 1.35)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 10 · the form kit
// ---------------------------------------------------------------------------
//
// Lifted out of `health_event_form_screen.dart`, where all six were private.
// `edit_pet` draws the same bordered rows — a labelled shell with a glyph, a
// text field, a picker, a fixed-choice sheet, a notes box with a counter and
// the clear affordance — and a second implementation of a form row is how two
// screens end up with different focus behaviour and different padding.

/// The bordered field row the Record Details card is made of.
class HealthFieldShell extends StatelessWidget {
  const HealthFieldShell({
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.028),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Icon(icon, size: 16, color: HealthTone.muted),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 10.5, height: 1.3)),
                child,
              ],
            ),
          ),
          ?trailing,
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

/// The clear affordance the mockup puts at the end of every filled field.
class HealthClearButton extends StatelessWidget {
  const HealthClearButton({required this.onTap,
    super.key,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: const Icon(LucideIcons.x, size: 15, color: HealthTone.muted),
        tooltip: 'Clear',
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
}

class HealthTextField extends StatelessWidget {
  const HealthTextField({
    required this.fieldKey,
    required this.controller,
    required this.icon,
    required this.label,
    this.hint = '',
    this.keyboardType,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final IconData icon;
  final String label;

  /// An example of what belongs here. The mockup draws every field filled, so
  /// it never had to answer what an empty one says.
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return HealthFieldShell(
      icon: icon,
      label: label,
      trailing:
          controller.text.isEmpty ? null : HealthClearButton(onTap: controller.clear),
      child: TextField(
        key: fieldKey,
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.25),
        // Every border, not just `border`: the app's InputDecorationTheme
        // supplies enabled/focused ones, which drew a stray underline through
        // each row on the device.
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          hintText: hint,
          hintStyle: const TextStyle(color: HealthTone.faint, fontSize: 14),
        ),
      ),
    );
  }
}

class HealthPickerField extends StatelessWidget {
  const HealthPickerField({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
    this.onClear,
    super.key,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return HealthFieldShell(
      icon: icon,
      label: label,
      onTap: onTap,
      trailing: onClear == null
          ? const Padding(
              padding: EdgeInsets.only(top: 8, right: 6),
              child: Icon(LucideIcons.chevronDown,
                  size: 15, color: HealthTone.muted),
            )
          : HealthClearButton(onTap: onClear!),
      child: Text(value,
          key: fieldKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: muted ? HealthTone.faint : Colors.white,
              fontSize: 14,
              height: 1.25)),
    );
  }
}

/// A field whose value comes from a short fixed list — vaccine class, medicine
/// form. Opens the same sheet the rest of the module uses.
class HealthChoiceField extends StatelessWidget {
  const HealthChoiceField({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelect,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return HealthFieldShell(
      icon: icon,
      label: label,
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => HealthSheet(
            title: label,
            children: [
              for (final option in options)
                HealthRecordRow(
                  key: Key('choice_$option'),
                  leading: HealthGlyphDisc(
                      icon: icon, tint: PawTone.of(context).accent, size: 34),
                  title: option,
                  chevron: false,
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        );
        if (picked != null) onSelect(picked);
      },
      trailing: value == null
          ? const Padding(
              padding: EdgeInsets.only(top: 8, right: 6),
              child: Icon(LucideIcons.chevronDown,
                  size: 15, color: HealthTone.muted),
            )
          : HealthClearButton(onTap: () => onSelect(null)),
      child: Text(value ?? 'Not set',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: value == null ? HealthTone.faint : Colors.white,
              fontSize: 14,
              height: 1.25)),
    );
  }
}

/// Notes, with the mockup's `98/500` counter.
class HealthNotesField extends StatefulWidget {
  const HealthNotesField({
    required this.controller,
    required this.label,
    this.hint = 'Anything worth remembering about this…',
    this.maxLength = 500,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  /// What an empty box invites. The record form asks about an event; the pet
  /// form asks about the animal, and the same sentence does not fit both.
  final String hint;
  final int maxLength;

  @override
  State<HealthNotesField> createState() => _HealthNotesFieldState();
}

class _HealthNotesFieldState extends State<HealthNotesField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HealthFieldShell(
      icon: LucideIcons.notebookPen,
      label: widget.label,
      trailing: widget.controller.text.isEmpty
          ? null
          : HealthClearButton(onTap: widget.controller.clear),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('event_notes_field'),
            controller: widget.controller,
            maxLines: 4,
            minLines: 2,
            inputFormatters: [
              LengthLimitingTextInputFormatter(widget.maxLength)
            ],
            style:
                const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              hintText: widget.hint,
              hintStyle:
                  const TextStyle(color: HealthTone.faint, fontSize: 13.5),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                '${widget.controller.text.length}/${widget.maxLength}',
                style:
                    const TextStyle(color: HealthTone.faint, fontSize: 10.5)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 11 · the step wizard
// ---------------------------------------------------------------------------

/// The numbered progress rail `add_memory` opens with: circled numerals joined
/// by dashed rules, the current one lit, each captioned underneath.
///
/// The reference draws its circles at ~14dp around a ~7dp numeral, which is a
/// smudge on a handset. They are 26dp here; the *centres* are the reference's,
/// which is what the eye reads — four equal columns inside a 23dp side inset
/// puts them at 66 / 153 / 240 / 327 on a 393-wide screen, matching the plate
/// to within half a point.
class HealthStepRail extends StatelessWidget {
  const HealthStepRail({
    required this.steps,
    required this.current,
    this.onSelect,
    super.key,
  });

  final List<String> steps;

  /// Zero-based.
  final int current;

  /// Tapping a stop jumps to it. The reference draws no back affordance at
  /// all, and a four-step form whose only navigation is forward is a trap —
  /// the *whole column* is the target, not the 26dp dot, because a label with
  /// no hit box is the kind of thing that only fails on a real thumb.
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Semantics(
                button: onSelect != null,
                selected: i == current,
                label: 'Step ${i + 1} of ${steps.length}: ${steps[i]}',
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: onSelect == null || i == current
                        ? null
                        : () => onSelect!(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 26,
                          child: Row(
                            children: [
                              Expanded(
                                child: i == 0
                                    ? const SizedBox.shrink()
                                    : _StepDash(passed: i <= current, tone: t),
                              ),
                              _StepDot(index: i, current: current, tone: t),
                              Expanded(
                                child: i == steps.length - 1
                                    ? const SizedBox.shrink()
                                    : _StepDash(passed: i < current, tone: t),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: i == current
                                ? Colors.white
                                : (i < current
                                    ? HealthTone.muted
                                    : HealthTone.faint),
                            fontSize: 11.5,
                            height: 1.15,
                            fontWeight: i == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.current,
    required this.tone,
  });

  final int index;
  final int current;
  final PawTone tone;

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    final passed = index < current;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? tone.accent : const Color(0xFF151B15),
        border: active
            ? null
            : Border.all(
                color: passed
                    ? tone.accent.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.12)),
      ),
      child: passed
          ? Icon(LucideIcons.check, size: 13, color: tone.accent)
          : Text('${index + 1}',
              style: TextStyle(
                  color: active ? const Color(0xFF06110A) : HealthTone.muted,
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w800)),
    );
  }
}

class _StepDash extends StatelessWidget {
  const _StepDash({required this.passed, required this.tone});

  final bool passed;
  final PawTone tone;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(double.infinity, 26),
        painter: _StepDashPainter(passed
            ? tone.accent.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.16)),
      );
}

class _StepDashPainter extends CustomPainter {
  const _StepDashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 4.0;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dash).clamp(0.0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StepDashPainter old) => old.color != color;
}

/// "**1.** Add Photos or Video" over "Share a special moment with your pet" —
/// the head every numbered card on `add_memory` opens with.
class HealthNumberedHead extends StatelessWidget {
  const HealthNumberedHead({
    required this.number,
    required this.title,
    this.subtitle,
    this.suffix,
    this.trailing,
    super.key,
  });

  final int number;
  final String title;
  final String? subtitle;

  /// The greyed qualifier the reference sets after a heading — "(Optional)".
  final String? suffix;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('$number.',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700)),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 5),
              Text(suffix!,
                  style: const TextStyle(
                      color: HealthTone.faint, fontSize: 12, height: 1.15)),
            ],
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 11.5, height: 1.3)),
        ],
      ],
    );
  }
}

/// A dashed-outline tile — the "Add" well, the "New Pet" slot.
///
/// The dashed rectangle was drawn by two private painters (one in
/// `health_event_form_screen`, one in [HealthAddCard]) before this batch put a
/// third mockup in front of it.
class HealthDashedTile extends StatelessWidget {
  const HealthDashedTile({
    required this.child,
    this.onTap,
    this.radius = 12,
    this.color,
    this.fill,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final stroke = color ?? t.accent.withValues(alpha: 0.55);
    final painted = CustomPaint(
      painter: HealthDashedPainter(stroke, radius: radius),
      child: child,
    );
    if (onTap == null) {
      return fill == null
          ? painted
          : DecoratedBox(
              decoration: BoxDecoration(
                  color: fill, borderRadius: BorderRadius.circular(radius)),
              child: painted);
    }
    return Material(
      color: fill ?? Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: painted,
      ),
    );
  }
}

/// The dashed rounded rectangle [HealthDashedTile] and [HealthAddCard] share.
class HealthDashedPainter extends CustomPainter {
  const HealthDashedPainter(this.color, {this.radius = 12});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HealthDashedPainter old) =>
      old.color != color || old.radius != radius;
}

/// A bordered box with a live `0/60` counter in it — the title and note fields
/// `add_memory` draws. Unlike [HealthNotesField] it carries no glyph and no
/// label, because the numbered head above it is the label.
class HealthCountedField extends StatefulWidget {
  const HealthCountedField({
    required this.fieldKey,
    required this.controller,
    required this.maxLength,
    this.hint = '',
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final int maxLength;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  State<HealthCountedField> createState() => _HealthCountedFieldState();
}

class _HealthCountedFieldState extends State<HealthCountedField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;
    final counter = Text(
        '${widget.controller.text.length}/${widget.maxLength}',
        style: const TextStyle(color: HealthTone.faint, fontSize: 11));
    final field = TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        hintText: widget.hint,
        hintStyle: const TextStyle(color: HealthTone.faint, fontSize: 14),
      ),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(11, multiline ? 10 : 12, 11, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.022),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: multiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: counter),
              ],
            )
          : Row(children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              counter,
            ]),
    );
  }
}

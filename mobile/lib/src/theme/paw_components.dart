import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'design_tokens.dart';

/// Redesign component library (roadmap Phase B).
///
/// Deliberately a **new** file rather than an edit of `paw_ui.dart`: every
/// shipping screen depends on the widgets there, and restyling them in place
/// would restyle 29 screens in one commit. Screens move onto these components
/// phase by phase instead, so each phase's diff stays reviewable and revertible.
///
/// Everything here reads its accent from [PawSystem] so the same widget serves
/// onboarding (navy + emerald) and the in-app product (black + lime) without a
/// second implementation — see `design_tokens.dart`.

// ---------------------------------------------------------------------------
// Theming glue
// ---------------------------------------------------------------------------

/// Declares which visual system a subtree belongs to.
///
/// Without this, System A's emerald would leak into System B screens the moment
/// a shared component is reused across the boundary.
class PawSystemScope extends InheritedWidget {
  const PawSystemScope({required this.system, required super.child, super.key});

  final PawSystem system;

  static PawSystem of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PawSystemScope>()?.system ??
      PawSystem.legacy;

  @override
  bool updateShouldNotify(PawSystemScope oldWidget) => system != oldWidget.system;
}

/// Resolved colours for the active system + brightness.
class PawTone {
  const PawTone._(this.accent, this.canvas, this.card, this.cardRaised,
      this.border, this.text, this.textMuted, this.isDark);

  factory PawTone.of(BuildContext context) {
    final system = PawSystemScope.of(context);
    final b = Theme.of(context).brightness;
    final dark = b == Brightness.dark;
    final accent = AppColors.accent(system, b);

    if (!dark) {
      return PawTone._(
        accent,
        AppColors.lightBackground,
        AppColors.lightSurface,
        AppColors.lightSurfaceContainer,
        AppColors.lightOutline,
        AppColors.lightText,
        AppColors.lightTextSecondary,
        false,
      );
    }
    return switch (system) {
      PawSystem.a => PawTone._(accent, AppColors.navy900, AppColors.navy850,
          AppColors.navy850, const Color(0x2622D3EE), AppColors.ink50,
          AppColors.ink300, true),
      PawSystem.b => PawTone._(accent, AppColors.carbon900, AppColors.carbon850,
          AppColors.carbon800, const Color(0x1FA3E635), AppColors.ink50,
          AppColors.ink300, true),
      PawSystem.legacy => PawTone._(accent, AppColors.ink900, AppColors.ink800,
          AppColors.ink700, AppColors.ink600, AppColors.ink50,
          AppColors.ink300, true),
    };
  }

  final Color accent;
  final Color canvas;
  final Color card;
  final Color cardRaised;
  final Color border;
  final Color text;
  final Color textMuted;
  final bool isDark;

  /// A low-alpha wash of the accent, for icon tiles and selected states.
  Color accentWash([double opacity = 0.10]) => accent.withValues(alpha: opacity);
}

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

/// The single icon entry point.
///
/// Two sources, one call shape. Lucide covers the ~140-glyph core set — it is
/// font-based, so `color` tints it exactly like `currentColor`, which is what
/// makes the emergency red colourway a colour argument rather than a duplicate
/// set of files (UI_ASSET_SPECIFICATION §1.4.4). The bespoke medical families
/// (symptom, anatomy, vaccine, …) have no Lucide equivalent — there is no
/// `parvovirus` or `hip-dysplasia` glyph — and ship as art instead.
class PawIcon extends StatelessWidget {
  /// A core UI glyph. Pass a `LucideIcons.*` constant.
  const PawIcon(this.icon, {this.size = 22, this.color, this.semanticLabel, super.key})
      : asset = null,
        tint = true;

  /// A bespoke monochrome glyph (symptom / anatomy / vitals / records / …).
  /// Rendered black-on-transparent, so it is tinted to [color] at runtime.
  const PawIcon.glyph(this.asset,
      {this.size = 22, this.color, this.semanticLabel, super.key})
      : icon = null,
        tint = true;

  /// A multicolour art tile (vaccine, first-aid, weather, notification badge).
  /// Never tinted — the colour *is* the information.
  const PawIcon.art(this.asset, {this.size = 40, this.semanticLabel, super.key})
      : icon = null,
        color = null,
        tint = false;

  final IconData? icon;
  final String? asset;
  final double size;
  final Color? color;
  final bool tint;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? PawTone.of(context).accent;

    if (icon != null) {
      return Icon(icon, size: size, color: c, semanticLabel: semanticLabel);
    }

    final image = Image.asset(
      asset!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Bespoke glyphs are authored black-on-transparent so srcIn recolours the
      // stroke while preserving the alpha edge.
      color: tint ? c : null,
      colorBlendMode: tint ? BlendMode.srcIn : null,
      excludeFromSemantics: semanticLabel == null,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) =>
          Icon(LucideIcons.circleDashed, size: size, color: c.withValues(alpha: 0.5)),
    );
    return image;
  }
}

/// The rounded-square icon container used by every list row and quick action.
class PawIconTile extends StatelessWidget {
  const PawIconTile({
    required this.child,
    this.size = 44,
    this.background,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final double size;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? t.accentWash(t.isDark ? 0.09 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(color: borderColor ?? t.accentWash(0.16)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

/// The redesign's card: near-black fill, hairline accent-tinted border.
class PawPanel extends StatelessWidget {
  const PawPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.s16),
    this.onTap,
    this.selected = false,
    this.raised = false,
    this.radius = 20,
    this.borderColor,
    this.background,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final bool raised;
  final double radius;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final br = BorderRadius.circular(radius);
    final panel = AnimatedContainer(
      duration: AppMotion.micro,
      decoration: BoxDecoration(
        color: background ?? (raised ? t.cardRaised : t.card),
        borderRadius: br,
        border: Border.all(
          color: borderColor ?? (selected ? t.accent.withValues(alpha: 0.85) : t.border),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected && t.isDark
            ? [BoxShadow(color: t.accentWash(0.22), blurRadius: 18, spreadRadius: -2)]
            : null,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: br, child: panel),
    );
  }
}

/// `[icon] Title ............ See All ›` — the header above every card cluster.
class PawSectionHeader extends StatelessWidget {
  const PawSectionHeader({
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            PawIcon(icon!, size: 20),
            const SizedBox(width: AppSpace.s8),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: t.text, fontWeight: FontWeight.w700),
            ),
          ),
          if (actionLabel != null && onAction != null)
            // The target is sized by a constraint, not by padding around the
            // label: padding alone left it at 42dp, and it would shrink further
            // if the label ever got smaller.
            InkWell(
              onTap: onAction,
              borderRadius: AppRadius.brSm,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(actionLabel!,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: t.accent)),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 16, color: t.accent),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon tile + title + subtitle + trailing. The most repeated row in the design.
class PawListRow extends StatelessWidget {
  const PawListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingText,
    this.trailingTextColor,
    this.onTap,
    this.showChevron = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? trailingText;
  final Color? trailingTextColor;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final text = Theme.of(context).textTheme;
    return PawPanel(
      onTap: onTap,
      raised: true,
      radius: 16,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpace.s12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: text.titleSmall?.copyWith(color: t.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: text.bodySmall?.copyWith(color: t.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: AppSpace.s8),
            Text(trailingText!,
                style: text.labelLarge
                    ?.copyWith(color: trailingTextColor ?? t.accent)),
          ],
          if (trailing != null) ...[const SizedBox(width: AppSpace.s8), trailing!],
          if (onTap != null && showChevron) ...[
            const SizedBox(width: 2),
            Icon(LucideIcons.chevronRight, size: 18, color: t.textMuted),
          ],
        ],
      ),
    );
  }
}

/// The 4-across tile row under the hero (`AI Assistant`, `Emergency`, …).
class PawQuickAction extends StatelessWidget {
  const PawQuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    this.accentOverride,
    super.key,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  /// Set for the Emergency tile so it carries the safety-locked red rather than
  /// the brand accent.
  final Color? accentOverride;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = accentOverride ?? t.accent;
    final text = Theme.of(context).textTheme;
    return PawPanel(
      onTap: onTap,
      radius: 16,
      borderColor: accentOverride?.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: c),
          const SizedBox(height: AppSpace.s8),
          Text(label,
              style: text.titleSmall?.copyWith(color: t.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(caption,
              style: text.bodySmall?.copyWith(color: t.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

/// The lime gradient pill CTA.
class PawCta extends StatelessWidget {
  const PawCta({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.dense = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final enabled = onPressed != null;
    // The gradient is bright, so the label must be dark to stay legible; in
    // light mode the accent is already dark, so the label flips to white.
    final fg = t.isDark ? const Color(0xFF0A0F06) : Colors.white;
    final h = dense ? 44.0 : 54.0;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Ink(
              height: h,
              width: expand ? double.infinity : null,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: t.isDark
                      ? [AppColors.lime400, AppColors.lime600]
                      : [t.accent, t.accent],
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: enabled && t.isDark
                    ? [
                        BoxShadow(
                            color: t.accentWash(0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expand ? 0 : AppSpace.s24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: fg),
                      const SizedBox(width: AppSpace.s8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: fg, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined pill used for the secondary action rows (`History`, `Log event`, …).
class PawPillButton extends StatelessWidget {
  const PawPillButton({
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
    return PawPanel(
      onTap: onTap,
      radius: AppRadius.pill,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16, vertical: AppSpace.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: t.accent),
          const SizedBox(width: AppSpace.s8),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: t.text)),
          ),
        ],
      ),
    );
  }
}

/// Small status/filter pill.
class PawChip extends StatelessWidget {
  const PawChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.color,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = color ?? t.accent;
    final content = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.16) : t.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
            color: selected ? c.withValues(alpha: 0.7) : t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? c : t.textMuted),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? c : t.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: content,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data display
// ---------------------------------------------------------------------------

/// Circular progress ring with a value in the middle.
class PawProgressRing extends StatelessWidget {
  const PawProgressRing({
    required this.value,
    required this.label,
    this.size = 78,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// 0..1
  final double value;
  final String label;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = color ?? t.accent;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value.clamp(0.0, 1.0),
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: t.accentWash(0.12),
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: t.text, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// One cell of the bottom stat strip: icon + label above, value below.
class PawStat extends StatelessWidget {
  const PawStat({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.iconColor,
    this.leading,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final Color? iconColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Icon(icon, size: 18, color: iconColor ?? t.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: t.text)),
          ),
        ]),
        const SizedBox(height: AppSpace.s8),
        if (leading != null) ...[leading!, const SizedBox(height: 6)],
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium
                ?.copyWith(color: valueColor ?? t.text, fontWeight: FontWeight.w700)),
        if (caption != null)
          Text(caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: t.textMuted)),
      ],
    );
  }
}

/// Vertical timeline with accent nodes down the left.
class PawTimeline extends StatelessWidget {
  const PawTimeline({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: t.accent, shape: BoxShape.circle),
                      ),
                      if (i != children.length - 1)
                        Expanded(
                          child: Container(width: 2, color: t.accentWash(0.30)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i == children.length - 1 ? 0 : AppSpace.s8),
                    child: children[i],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Illustration + headline + body + optional action.
class PawEmptyState extends StatelessWidget {
  const PawEmptyState({
    required this.title,
    required this.body,
    this.art,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String body;

  /// Asset path; falls back to [icon] when the art has not landed.
  final String? art;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpace.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (art != null)
                Image.asset(art!,
                    height: 148,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) =>
                        Icon(icon ?? LucideIcons.pawPrint, size: 64, color: t.accent))
              else
                Icon(icon ?? LucideIcons.pawPrint, size: 64, color: t.accent),
              const SizedBox(height: AppSpace.s20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(color: t.text)),
              const SizedBox(height: AppSpace.s8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: t.textMuted)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpace.s24),
                PawCta(label: actionLabel!, onPressed: onAction, expand: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

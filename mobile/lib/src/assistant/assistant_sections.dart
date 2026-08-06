import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';

/// The pieces mockups `ai_assistant_home`, `ai_assistant_chat` and
/// `ai_message_actions` are built from.
///
/// They live apart from `assistant_screen.dart` for the same reason
/// `home_sections.dart` and `result_sections.dart` do: the screen owns the
/// transport, the emergency router and the quota gate, and the three mockups
/// add nineteen presentation blocks on top. Everything here is presentation —
/// data in, callbacks out.
///
/// **Safety.** Two rules shape this file and neither is negotiable:
///
/// * **V-23.** The mockups subtitle every assistant surface *"AI Vet
///   Assistant"*. The assistant is a companion, not a licensed professional,
///   and implying otherwise invites exactly the reliance the product cannot
///   carry. The layout keeps its subtitle slot; the claim is replaced.
/// * **V-12.** The mockups seed the prompt row with *"Why is Buddy itching?"* —
///   a symptom asserted before the owner has reported anything. Every chip here
///   is care-framed, and `safety_copy_test` greps for the banned shapes.
///
/// The action-sheet tints are also deliberate: see [AssistantTone].

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// Colours this surface uses that are not the brand accent.
///
/// **None of these may be one of the action ladder's four safety-locked hues**
/// (`emergencyDark`, `monitorDark`, `actionBookVisit`, `actionWatch`). The
/// mockup paints the message-action grid in eight colours, two of which land
/// squarely on the ladder's red and amber; reusing those as decoration is the
/// thing `design_tokens.dart` forbids in its own header, because a red glyph
/// beside an AI reply reads as a severity signal. The hues below carry the
/// mockup's *variety* without borrowing its *meaning*, and
/// `assistant_tone_test.dart` pins the separation.
class AssistantTone {
  const AssistantTone._();

  /// Informational blue (Copy). Distinct from `actionBookVisit`.
  static const Color info = Color(0xFF4FC3F7);

  /// A lighter sky for Regenerate, so it does not read as a second Copy.
  static const Color sky = Color(0xFF7DD3FC);

  /// Share.
  static const Color violet = Color(0xFFC084FC);

  /// Reminders. The same muted gold `HomeStatStrip` already gives the
  /// "Next Reminder" cell — not the MONITOR amber.
  static const Color gold = Color(0xFFE9C46A);

  /// Negative feedback. `coral400Dark` is documented in `design_tokens.dart`
  /// as warmth only, never status.
  static const Color coral = AppColors.coral400Dark;

  /// Report. Warm, and deliberately not the EMERGENCY red.
  static const Color rose = Color(0xFFFB7185);

  /// Every decorative tint above, for the guard test.
  static const List<Color> all = [info, sky, violet, gold, coral, rose];

  // Surfaces.
  static const Color raised = Color(0xFF10160F);
  static const Color muted = Color(0xFF9BA5A0);
  static const Color dim = Color(0xFF8A948D);
  static const Color faint = Color(0xFF7F8A85);
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

/// A circled icon button — the affordance every assistant mockup puts in its
/// header. Drawn at [size], with the tap target padded out to 48dp regardless.
class AssistantCircleButton extends StatelessWidget {
  const AssistantCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.label,
    this.size = 38,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  /// The chat mockup captions its three header buttons ("Private", "History",
  /// "More"); the home mockup does not.
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    final button = Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF121812),
              border: Border.all(color: c.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, size: size * 0.46, color: c),
          ),
        ),
      ),
    );
    if (label == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 3),
        Text(label!,
            style: const TextStyle(color: AssistantTone.muted, fontSize: 10.5)),
      ],
    );
  }
}

/// `PawDoc AI ✨` — the lozenge beside the title on every assistant mockup.
class AssistantBrandPill extends StatelessWidget {
  const AssistantBrandPill({super.key});

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: t.accent.withValues(alpha: 0.10),
        border: Border.all(color: t.accent.withValues(alpha: 0.40)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('PawDoc AI',
            style: TextStyle(
                color: t.accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 3),
        Icon(LucideIcons.sparkles, size: 11, color: t.accent),
      ]),
    );
  }
}

/// The assistant's header: circled back button, a centred title (with the brand
/// pill on the home surface), circled actions on the right, and a subtitle
/// underneath.
///
/// **V-23.** The mockups print "Your personal AI Vet Assistant" / "AI Vet
/// Assistant" here. The slot, its position and its weight are kept; the claim
/// is not.
class AssistantAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AssistantAppBar({
    required this.title,
    required this.subtitle,
    this.showPill = true,
    this.actions = const [],
    this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool showPill;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s16, 2, AppSpace.s16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 46,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AssistantCircleButton(
                        key: const Key('assistant_back'),
                        icon: LucideIcons.chevronLeft,
                        tooltip: 'Back',
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    // Padded in past both slots so a long title can never sit
                    // under the buttons. The right slot grows with the number
                    // of actions — the brand pill was tucking under the help
                    // button on the first device pass.
                    Padding(
                      padding: EdgeInsets.only(
                          left: 46,
                          right: actions.isEmpty ? 46 : actions.length * 46 + 6),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            if (showPill) ...[
                              const SizedBox(width: 7),
                              const AssistantBrandPill(),
                            ] else ...[
                              const SizedBox(width: 5),
                              Icon(LucideIcons.sparkles,
                                  size: 15, color: PawTone.of(context).accent),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          actions[i],
                        ],
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AssistantTone.muted, fontSize: 13, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// `Title ........ action ›` — the assistant mockups' section heading. Unlike
/// [HomeCardHeader] it carries no leading glyph, which is how both the
/// "Continue a conversation" and "Popular topics" cards are drawn.
class AssistantSectionHead extends StatelessWidget {
  const AssistantSectionHead({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.chevron = true,
    this.actionColor,
    this.leading,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool chevron;
  final Color? actionColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = actionColor ?? AssistantTone.muted;
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w700)),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!,
                    style: TextStyle(
                        color: c, fontSize: 12, fontWeight: FontWeight.w600)),
                if (chevron)
                  Icon(LucideIcons.chevronRight,
                      size: 14, color: t.accent),
              ]),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1 · the hero
// ---------------------------------------------------------------------------

/// The paw speech-bubble mark: a lime-ringed disc with a little tail. The
/// mockups use it twice — pinned to the hero portrait, and as the speaker
/// beside every assistant reply.
class AssistantPawBadge extends StatelessWidget {
  const AssistantPawBadge({this.size = 38, this.tail = true, super.key});

  final double size;
  final bool tail;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: size,
      height: size * (tail ? 1.22 : 1.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (tail)
            Positioned(
              left: size * 0.16,
              top: size * 0.82,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: size * 0.26,
                  height: size * 0.26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B120B),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.75), width: 1.3),
                  ),
                ),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B120B),
              border:
                  Border.all(color: t.accent.withValues(alpha: 0.75), width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: t.accent.withValues(alpha: 0.28),
                    blurRadius: size * 0.4,
                    spreadRadius: -2),
              ],
            ),
            child: Icon(LucideIcons.pawPrint, size: size * 0.5, color: t.accent),
          ),
        ],
      ),
    );
  }
}

/// The pet, lit by the mockup's orbit of light: a lime ring with nodes and
/// sparkles behind the portrait, and the paw badge pinned top-right.
class AssistantHaloPortrait extends StatelessWidget {
  const AssistantHaloPortrait({
    required this.portrait,
    this.width = 138,
    super.key,
  });

  final Widget portrait;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    t.accent.withValues(alpha: 0.22),
                    t.accent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ], stops: const [0.0, 0.55, 1.0]),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HaloPainter(t.accent)),
            ),
          ),
          // The pet sits over the orbit's lower half and clear of its top arc,
          // as drawn.
          //
          // The mockup's pet is a cutout on transparent ground; every plate the
          // app actually owns is a rectangle of edge-to-edge fur, and a hard
          // photo seam inside the hero was the biggest departure on the first
          // device pass. So the plate is feathered into the card with an
          // elliptical mask — the pet reads as cut out, and the ring of light
          // shows through the margins the way it does in the reference.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: width * 1.20,
            child: ShaderMask(
              shaderCallback: (r) => const RadialGradient(
                center: Alignment(0, -0.06),
                radius: 0.74,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.50, 1.0],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: portrait,
            ),
          ),
          const Positioned(
            right: 2,
            top: 4,
            child: AssistantPawBadge(size: 36),
          ),
        ],
      ),
    );
  }
}

/// The ring of light: one thin circle, six nodes on it, four four-point stars.
/// Deterministic — nothing here animates, so it never repaints.
class _HaloPainter extends CustomPainter {
  const _HaloPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.50, size.height - size.width * 0.62);
    final r = size.width * 0.50;

    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.75),
    );

    final node = Paint()..color = accent;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3 + 0.35;
      final p = centre + Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawCircle(p, 2.6, node);
      canvas.drawCircle(
          p, 6.5, Paint()..color = accent.withValues(alpha: 0.22));
    }

    // Four-point sparkles scattered inside the ring's left half, as drawn.
    const stars = [
      (0.06, 0.20, 6.0),
      (0.14, 0.52, 4.5),
      (0.02, 0.72, 5.0),
      (0.30, 0.06, 4.0),
    ];
    final star = Paint()..color = accent.withValues(alpha: 0.85);
    for (final (fx, fy, s) in stars) {
      final c = Offset(size.width * fx, size.height * fy);
      final path = Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
        ..close();
      canvas.drawPath(path, star);
    }
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.accent != accent;
}

/// The home surface's centrepiece: the greeting, the lime promise line, the
/// invitation, the privacy card, and the pet lit against the halo.
class AssistantHero extends StatelessWidget {
  const AssistantHero({
    required this.greeting,
    required this.promise,
    required this.invitation,
    required this.privacyTitle,
    required this.privacyBody,
    required this.portrait,
    super.key,
  });

  final String greeting;
  final String promise;
  final String invitation;
  final String privacyTitle;
  final String privacyBody;
  final Widget portrait;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F0B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                  child: AssistantHaloPortrait(portrait: portrait)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 134, 13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text(promise,
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(invitation,
                    style: const TextStyle(
                        color: AssistantTone.muted,
                        fontSize: 12,
                        height: 1.35)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(13),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.shieldCheck,
                              size: 18, color: t.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(privacyTitle,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const Icon(LucideIcons.lock,
                              size: 14, color: AssistantTone.faint),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(privacyBody,
                            style: const TextStyle(
                                color: AssistantTone.muted,
                                fontSize: 11.5,
                                height: 1.35)),
                      ),
                    ],
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
// 2 · the prompt row
// ---------------------------------------------------------------------------

/// One suggested opener. [label] is what the chip prints (the mockup fits three
/// short lines); [prompt] is the sentence actually sent.
class AssistantPrompt {
  const AssistantPrompt(this.icon, this.label, this.prompt);

  final IconData icon;
  final String label;
  final String prompt;
}

/// The four openers under the hero, filling the row exactly as drawn.
///
/// **V-12.** The mockup's first chip is "Why is Buddy itching?" — a symptom the
/// owner has not reported, asserted by the app. Every chip here asks about
/// care, and health worries go to the Check flow where they can be handled
/// properly.
class AssistantPromptRow extends StatelessWidget {
  const AssistantPromptRow({
    required this.prompts,
    required this.onSelect,
    super.key,
  });

  final List<AssistantPrompt> prompts;
  final ValueChanged<AssistantPrompt> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          for (var i = 0; i < prompts.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: HomeCard(
                key: Key('assistant_suggestion_$i'),
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onTap: () => onSelect(prompts[i]),
                child: Row(
                  children: [
                    Icon(prompts[i].icon, size: 15, color: t.accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(prompts[i].label,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: FontWeight.w500)),
                    ),
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

// ---------------------------------------------------------------------------
// 3 · continue a conversation
// ---------------------------------------------------------------------------

/// The "Continue a conversation" card: a heading, a link, and one resumable
/// thread with its avatar, preview, age and status pill.
class AssistantContinueCard extends StatelessWidget {
  const AssistantContinueCard({
    required this.title,
    required this.onViewAll,
    required this.rows,
    required this.emptyLabel,
    super.key,
  });

  final String title;
  final VoidCallback onViewAll;
  final List<AssistantConversationRow> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssistantSectionHead(
            title: title,
            actionLabel: 'View all',
            onAction: onViewAll,
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyLabel,
                  key: const Key('assistant_history_empty'),
                  style: const TextStyle(
                      color: AssistantTone.faint, fontSize: 12, height: 1.35)),
            )
          else
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 7),
                child: rows[i],
              ),
        ],
      ),
    );
  }
}

/// One resumable thread.
class AssistantConversationRow extends StatelessWidget {
  const AssistantConversationRow({
    required this.avatar,
    required this.title,
    required this.preview,
    required this.age,
    required this.status,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final Widget avatar;
  final String title;
  final String preview;
  final String age;
  final String status;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Material(
      color: AssistantTone.raised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipOval(child: SizedBox(width: 40, height: 40, child: avatar)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AssistantTone.dim, fontSize: 11.5)),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(LucideIcons.clock,
                          size: 11, color: AssistantTone.faint),
                      const SizedBox(width: 4),
                      Text(age,
                          style: const TextStyle(
                              color: AssistantTone.faint, fontSize: 10.5)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  color: t.accent.withValues(alpha: 0.12),
                  border: Border.all(color: t.accent.withValues(alpha: 0.35)),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · popular topics
// ---------------------------------------------------------------------------

/// One topic tile. [tint] is set only for Emergency, which carries the
/// safety-locked red rather than the brand accent.
class AssistantTopic {
  const AssistantTopic(this.icon, this.line1, this.line2, this.prompt,
      {this.tint, this.onTap});

  final IconData icon;
  final String line1;
  final String line2;
  final String prompt;
  final Color? tint;

  /// Overrides "send [prompt]" — the Emergency tile opens the red screen
  /// instead of asking a model about an emergency.
  final VoidCallback? onTap;
}

/// The six-across topic row, filling the card exactly as the mockup draws it.
class AssistantTopicsCard extends StatelessWidget {
  const AssistantTopicsCard({
    required this.topics,
    required this.onSelect,
    required this.onViewAll,
    super.key,
  });

  final List<AssistantTopic> topics;
  final ValueChanged<AssistantTopic> onSelect;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssistantSectionHead(
            title: 'Popular topics',
            actionLabel: 'View all topics',
            chevron: false,
            onAction: onViewAll,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < topics.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _TopicTile(
                    topic: topics[i],
                    accent: topics[i].tint ?? t.accent,
                    onTap: topics[i].onTap ?? () => onSelect(topics[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.accent,
    required this.onTap,
  });

  final AssistantTopic topic;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${topic.line1} ${topic.line2}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.white.withValues(alpha: 0.028),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.055)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(topic.icon, size: 20, color: accent),
                  const SizedBox(height: 6),
                  // Shrink-to-fit rather than ellipsis: a topic reading
                  // "Supplem…" is worse than one a point smaller.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${topic.line1}\n${topic.line2}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9, height: 1.25)),
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
// 5 · health at a glance
// ---------------------------------------------------------------------------

/// One row of the right-hand signal list.
class AssistantSignal {
  const AssistantSignal(this.icon, this.label, this.value, {this.available = true});

  final IconData icon;
  final String label;
  final String value;

  /// False renders the mockup's row with the value marked as not yet recorded.
  /// Nothing in the product measures energy, appetite, mood or activity, and a
  /// fabricated "Mood · Happy" is a claim about an animal nobody observed.
  final bool available;
}

/// "…'s health at a glance": the score dial on the left, the signal list on the
/// right.
///
/// **D-2.** The mockup labels the dial "Health Score · 92 · Excellent". A
/// number that reads as a verdict on an animal's health, with nothing behind
/// it, is precisely the reliance the product must not invite — so the dial is
/// computed from how complete the pet's *record* is, and captioned as such.
class AssistantGlanceCard extends StatelessWidget {
  const AssistantGlanceCard({
    required this.title,
    required this.score,
    required this.scoreBand,
    required this.scoreCaption,
    required this.signals,
    required this.onOpen,
    required this.onDetails,
    super.key,
  });

  final String title;
  final int score;
  final String scoreBand;
  final String scoreCaption;
  final List<AssistantSignal> signals;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.heartPulse, size: 19, color: t.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
            const Icon(LucideIcons.chevronRight, size: 17, color: Colors.white54),
          ]),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 44, child: _ScoreCell(
                  score: score,
                  band: scoreBand,
                  caption: scoreCaption,
                  onDetails: onDetails,
                )),
                const SizedBox(width: 8),
                Expanded(flex: 56, child: _SignalCell(signals: signals)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.score,
    required this.band,
    required this.caption,
    required this.onDetails,
  });

  final int score;
  final String band;
  final String caption;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AssistantTone.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Care Score',
              style: TextStyle(color: AssistantTone.muted, fontSize: 11.5)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 4.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(t.accent),
                ),
                Text('$score',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(band,
                      style: TextStyle(
                          color: t.accent,
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(caption,
                      style: const TextStyle(
                          color: AssistantTone.dim,
                          fontSize: 10.5,
                          height: 1.25)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 9),
          InkWell(
            key: const Key('assistant_care_details'),
            onTap: onDetails,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              alignment: Alignment.center,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // The cell is barely a hundred points wide; shrink the label
                // rather than let it push the chevron off the pill.
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('View Details',
                        maxLines: 1,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 14, color: t.accent),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalCell extends StatelessWidget {
  const _SignalCell({required this.signals});

  final List<AssistantSignal> signals;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AssistantTone.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < signals.length; i++) ...[
            if (i > 0)
              Container(height: 1, color: Colors.white.withValues(alpha: 0.055)),
            Expanded(
              child: Row(children: [
                Icon(signals[i].icon,
                    size: 16,
                    color: signals[i].available
                        ? AppColors.teal300Dark
                        : AppColors.teal300Dark.withValues(alpha: 0.45)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(signals[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12.5)),
                ),
                Text(signals[i].value,
                    style: TextStyle(
                        color: signals[i].available
                            ? t.accent
                            : AssistantTone.faint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6 · premium
// ---------------------------------------------------------------------------

/// The "Unlock deeper insights" strip that closes the scroll.
class AssistantPremiumBanner extends StatelessWidget {
  const AssistantPremiumBanner({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    required this.onDismiss,
    super.key,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.accent.withValues(alpha: 0.30)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                t.accent.withValues(alpha: 0.10),
                t.accent.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.sparkles, size: 32, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AssistantTone.muted,
                            fontSize: 11.5,
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // The mockup gives the CTA about a third of the strip. A
              // content-sized button takes far more than that once the label
              // is at readable weight, which squeezes the copy column into a
              // one-word-per-line ribbon — so the width is the constraint and
              // the label fits itself to it.
              SizedBox(
                width: 122,
                height: 44,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('assistant_premium_cta'),
                    onTap: onCta,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        gradient: const LinearGradient(
                            colors: [AppColors.lime400, AppColors.lime600]),
                        boxShadow: [
                          BoxShadow(
                              color: t.accent.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.crown,
                                size: 15, color: Color(0xFF0A0F06)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(ctaLabel,
                                    maxLines: 1,
                                    style: const TextStyle(
                                        color: Color(0xFF0A0F06),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton(
            key: const Key('assistant_premium_dismiss'),
            tooltip: 'Dismiss',
            iconSize: 14,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: onDismiss,
            icon: const Icon(LucideIcons.x, color: AssistantTone.faint),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 7 · the composer
// ---------------------------------------------------------------------------

/// The pinned footer every assistant mockup ends on: an optional suggestion
/// rail, the input pill with its attachment and voice controls, the send
/// button, and — on the conversation surface — the disclaimer.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    required this.controller,
    required this.hint,
    required this.streaming,
    required this.uploading,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.onVoice,
    this.pendingImage,
    this.onRemoveImage,
    this.sendIcon = LucideIcons.arrowUp,
    this.above,
    this.disclaimer,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final bool streaming;
  final bool uploading;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final Widget? pendingImage;
  final VoidCallback? onRemoveImage;
  final IconData sendIcon;

  /// The suggestion rail, on the conversation surface.
  final Widget? above;
  final Widget? disclaimer;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.s16, 0, AppSpace.s16, 8),
        child: HomeCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (above != null) ...[above!, const SizedBox(height: 10)],
              if (pendingImage != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: AppRadius.brSm,
                      child: SizedBox(width: 64, height: 64, child: pendingImage),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        key: const Key('assistant_remove_image'),
                        onTap: onRemoveImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(LucideIcons.x,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.only(left: 4, right: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D120C),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // The mockup's sparkle sits here; it is also the
                          // attachment control, so the affordance the shipping
                          // app needs keeps the glyph the design drew.
                          IconButton(
                            key: const Key('assistant_attach_button'),
                            tooltip: 'Attach a photo',
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 44),
                            onPressed:
                                streaming || uploading ? null : onAttach,
                            icon: const Icon(LucideIcons.sparkles,
                                color: Colors.white),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TextField(
                                key: const Key('assistant_input'),
                                controller: controller,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 2000,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  counterText: '',
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  hintText: hint,
                                  hintStyle: const TextStyle(
                                      color: AssistantTone.faint,
                                      fontSize: 14),
                                ),
                                onSubmitted: (_) => streaming ? null : onSend(),
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('assistant_voice_button'),
                            tooltip: 'Voice input — coming soon',
                            iconSize: 19,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 44),
                            onPressed: onVoice,
                            icon: const Icon(LucideIcons.mic,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (uploading)
                    const SizedBox(
                      width: 46,
                      height: 46,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Semantics(
                      button: true,
                      label: streaming ? 'Stop' : 'Send',
                      child: InkWell(
                        key: Key(streaming
                            ? 'assistant_stop_button'
                            : 'assistant_send_button'),
                        onTap: streaming ? onStop : onSend,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              AppColors.lime400,
                              AppColors.lime600,
                            ]),
                            boxShadow: [
                              BoxShadow(
                                  color: t.accent.withValues(alpha: 0.35),
                                  blurRadius: 16),
                            ],
                          ),
                          child: Icon(
                              streaming ? LucideIcons.square : sendIcon,
                              size: 20,
                              color: const Color(0xFF0A0F06)),
                        ),
                      ),
                    ),
                ],
              ),
              if (disclaimer != null) ...[
                const SizedBox(height: 8),
                disclaimer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The standing line under the composer.
///
/// Not the API-injected result disclaimer (that one is gated on
/// `disclaimerRequired` and lives on the result screens) — this is the
/// assistant's own standing statement, and it is always on.
class AssistantDisclaimer extends StatelessWidget {
  const AssistantDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, left: 4),
          child: Icon(LucideIcons.shieldCheck, size: 13, color: t.accent),
        ),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'PawDoc AI gives general guidance — not a diagnosis, and never a '
            'replacement for a vet. For symptoms, run a Check.',
            key: Key('assistant_disclaimer'),
            style: TextStyle(
                color: AssistantTone.dim, fontSize: 11, height: 1.3),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8 · the conversation surface
// ---------------------------------------------------------------------------

/// The pet the conversation is about, plus the three circled header actions the
/// chat mockup captions.
class AssistantPetBar extends StatelessWidget {
  const AssistantPetBar({
    required this.avatar,
    required this.name,
    required this.detail,
    required this.onSwitch,
    required this.actions,
    super.key,
  });

  final Widget avatar;
  final String name;
  final String detail;
  final VoidCallback onSwitch;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Material(
            color: const Color(0xFF0A0F0B),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const Key('assistant_pet_switch'),
              onTap: onSwitch,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.accent, width: 1.6),
                        boxShadow: [
                          BoxShadow(
                              color: t.accent.withValues(alpha: 0.30),
                              blurRadius: 12),
                        ],
                      ),
                      child: ClipOval(
                          child:
                              SizedBox(width: 42, height: 42, child: avatar)),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 3),
                            const Icon(LucideIcons.chevronDown,
                                size: 15, color: Colors.white70),
                          ]),
                          Text(detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AssistantTone.muted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions[i],
        ],
      ],
    );
  }
}

/// The privacy strip under the pet bar.
class AssistantPrivacyStrip extends StatelessWidget {
  const AssistantPrivacyStrip({required this.onLearnMore, super.key});

  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, size: 19, color: AssistantTone.muted),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Your conversations are private and never stored with your '
              'pet’s personal data.',
              style: TextStyle(
                  color: AssistantTone.muted, fontSize: 11.5, height: 1.3),
            ),
          ),
          TextButton(
            key: const Key('assistant_privacy_learn_more'),
            onPressed: onLearnMore,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 44)),
            child: Text('Learn more',
                style: TextStyle(
                    color: t.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// The `Today` lozenge between day groups.
class AssistantDayChip extends StatelessWidget {
  const AssistantDayChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: AssistantTone.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500)),
        ),
      );
}

/// The owner's turn: an olive lime-tinted bubble with a tail, a timestamp and
/// the mockup's delivery ticks.
class AssistantUserBubble extends StatelessWidget {
  const AssistantUserBubble({
    required this.text,
    required this.stamp,
    this.hasImage = false,
    super.key,
  });

  final String text;
  final String stamp;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 52, top: 5, bottom: 5, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.13),
            border: Border.all(color: t.accent.withValues(alpha: 0.45)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasImage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.image, size: 14, color: t.accent),
                    const SizedBox(width: 4),
                    Text('Photo attached',
                        style: TextStyle(color: t.accent, fontSize: 11)),
                  ]),
                ),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.4)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(stamp,
                    style: const TextStyle(
                        color: AssistantTone.muted, fontSize: 10.5)),
                const SizedBox(width: 4),
                Icon(LucideIcons.checkCheck, size: 12, color: t.accent),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The assistant's turn: the paw speaker, the reply, its timestamp and the row
/// of per-message actions the mockups draw at the bubble's foot.
class AssistantReplyBubble extends StatelessWidget {
  const AssistantReplyBubble({
    required this.child,
    required this.stamp,
    this.onCopy,
    this.onHelpful,
    this.onNotHelpful,
    this.onMore,
    this.rating,
    super.key,
  });

  final Widget child;
  final String stamp;
  final VoidCallback? onCopy;
  final VoidCallback? onHelpful;
  final VoidCallback? onNotHelpful;
  final VoidCallback? onMore;

  /// `true` helpful, `false` not helpful, null unrated.
  final bool? rating;

  @override
  Widget build(BuildContext context) {
    final showActions = onCopy != null;
    return Padding(
      padding: const EdgeInsets.only(right: 34, top: 5, bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: ExcludeSemantics(child: AssistantPawBadge(size: 32)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 11, 11, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1519),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  child,
                  const SizedBox(height: 6),
                  Row(children: [
                    Flexible(
                      child: Text(stamp,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AssistantTone.muted, fontSize: 10.5)),
                    ),
                    const Spacer(),
                    if (showActions) ...[
                      _BubbleAction(
                        icon: LucideIcons.copy,
                        tooltip: 'Copy',
                        onTap: onCopy!,
                        actionKey: const Key('assistant_msg_copy'),
                      ),
                      const SizedBox(width: 5),
                      _BubbleAction(
                        icon: LucideIcons.thumbsUp,
                        tooltip: 'Helpful',
                        onTap: onHelpful,
                        active: rating == true,
                        actionKey: const Key('assistant_msg_helpful'),
                      ),
                      const SizedBox(width: 5),
                      _BubbleAction(
                        icon: LucideIcons.thumbsDown,
                        tooltip: 'Not helpful',
                        onTap: onNotHelpful,
                        active: rating == false,
                        activeColor: AssistantTone.coral,
                        actionKey: const Key('assistant_msg_not_helpful'),
                      ),
                      const SizedBox(width: 5),
                      _BubbleAction(
                        icon: LucideIcons.ellipsis,
                        tooltip: 'More actions',
                        onTap: onMore,
                        actionKey: const Key('assistant_msg_more'),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.actionKey,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Key actionKey;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = active ? (activeColor ?? t.accent) : Colors.white70;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          key: actionKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: active ? c.withValues(alpha: 0.12) : Colors.transparent,
              border: Border.all(
                  color: active
                      ? c.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, size: 14, color: c),
          ),
        ),
      ),
    );
  }
}

/// The mockup's "Was this helpful?" pill, offered once under the newest reply.
class AssistantHelpfulPrompt extends StatelessWidget {
  const AssistantHelpfulPrompt({
    required this.onHelpful,
    required this.onNotHelpful,
    super.key,
  });

  final VoidCallback onHelpful;
  final VoidCallback onNotHelpful;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
          decoration: BoxDecoration(
            color: AssistantTone.raised,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Was this helpful?',
                style: TextStyle(color: AssistantTone.muted, fontSize: 12)),
            const SizedBox(width: 8),
            _BubbleAction(
              icon: LucideIcons.thumbsUp,
              tooltip: 'Helpful',
              onTap: onHelpful,
              actionKey: const Key('assistant_prompt_helpful'),
            ),
            const SizedBox(width: 5),
            _BubbleAction(
              icon: LucideIcons.thumbsDown,
              tooltip: 'Not helpful',
              onTap: onNotHelpful,
              activeColor: AssistantTone.coral,
              actionKey: const Key('assistant_prompt_not_helpful'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The "Suggestions for you" rail above the conversation composer.
class AssistantSuggestionRail extends StatelessWidget {
  const AssistantSuggestionRail({
    required this.prompts,
    required this.onSelect,
    required this.onViewAll,
    super.key,
  });

  final List<AssistantPrompt> prompts;
  final ValueChanged<AssistantPrompt> onSelect;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssistantSectionHead(
          title: 'Suggestions for you',
          actionLabel: 'See all',
          chevron: false,
          actionColor: t.accent,
          onAction: onViewAll,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prompts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 178),
              child: HomeCard(
                key: Key('assistant_rail_$i'),
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onTap: () => onSelect(prompts[i]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(prompts[i].icon, size: 18, color: t.accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(prompts[i].label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, height: 1.2)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 9 · the message-action sheet
// ---------------------------------------------------------------------------

/// One tile of the 4×2 action grid.
class AssistantAction {
  const AssistantAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.tint,
    required this.onTap,
    this.actionKey,
    this.soon = false,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color tint;
  final VoidCallback onTap;
  final Key? actionKey;

  /// Renders the tile with a *Soon* marker instead of dropping it — the design
  /// keeps every affordance it draws.
  final bool soon;
}

/// `ai_message_actions`: the grid, and the follow-up prompts beneath it.
class AssistantActionSheet extends StatelessWidget {
  const AssistantActionSheet({
    required this.actions,
    required this.followUps,
    required this.onFollowUp,
    required this.onShuffle,
    super.key,
  });

  final List<AssistantAction> actions;
  final List<String> followUps;
  final ValueChanged<String> onFollowUp;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    return PawSystemScope(
      system: PawSystem.b,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A0F0B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                  child: Text('AI Message Actions',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  key: const Key('assistant_actions_close'),
                  tooltip: 'Close',
                  iconSize: 20,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, color: Colors.white70),
                ),
              ]),
              const SizedBox(height: 6),
              for (var row = 0; row * 4 < actions.length; row++) ...[
                if (row > 0) const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = row * 4;
                          i < math.min(row * 4 + 4, actions.length);
                          i++) ...[
                        if (i > row * 4) const SizedBox(width: 8),
                        Expanded(child: _ActionTile(action: actions[i])),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(
                  child: Text('You might also ask',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                Semantics(
                  button: true,
                  label: 'Shuffle suggestions',
                  child: InkWell(
                    key: const Key('assistant_followup_shuffle'),
                    onTap: onShuffle,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AssistantTone.info.withValues(alpha: 0.14),
                      ),
                      child: const Icon(LucideIcons.refreshCw,
                          size: 17, color: AssistantTone.info),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < followUps.length; i++)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key('assistant_followup_$i'),
                        onTap: () => onFollowUp(followUps[i]),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                                color: AssistantTone.info
                                    .withValues(alpha: 0.45)),
                          ),
                          child: Text(followUps[i],
                              style: const TextStyle(
                                  color: AssistantTone.info, fontSize: 12.5)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final AssistantAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.028),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: action.actionKey,
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 26, color: action.tint),
              const SizedBox(height: 8),
              Text(action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(action.soon ? 'Soon' : action.caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: action.soon
                          ? action.tint.withValues(alpha: 0.85)
                          : AssistantTone.faint,
                      fontSize: 9.5,
                      height: 1.2,
                      fontWeight:
                          action.soon ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

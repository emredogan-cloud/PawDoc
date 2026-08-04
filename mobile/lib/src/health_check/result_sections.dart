import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_sections.dart';
import '../theme/design_tokens.dart';

/// The cards mockups `ai_analysis_result_low_risk` and
/// `ai_analysis_result_monitor` build the result out of.
///
/// **These two mockups are the most contract-hostile in the set**, and the
/// layout is reproduced while the claims are not. What they draw, and what
/// ships in its place:
///
/// | Mockup | Why it cannot ship | Shipped |
/// |---|---|---|
/// | "Good news! / No signs of a serious condition" | an all-clear headline; `safety_copy_test` bans the phrase | the action the check ended on |
/// | "Overall Risk Level · Low" | a severity grade | the action and its timeframe |
/// | "68% confidence" | confidence is never rendered — the single most explicit rule in CLAUDE.md | the recheck window |
/// | "Most Likely Cause: Mild Skin Irritation" | names a condition and asserts a cause | what vets look for with this kind of presentation |
/// | "Other Possibilities · 21% / 7% / 4%" | a differential with probabilities (review V-02) | — the block becomes what the owner reported |
/// | "No swelling detected / No signs of infection" | an all-clear checklist | what to watch for, neutrally marked |
/// | "Health Score 92 · Excellent" | D-2: wellness only, never a verdict | Care Score, from record completeness |
///
/// Every card, its position, its glyph and its furniture are kept.

/// The split hero: headline and deck on the left, the submitted photo on the
/// right with the mockup's "View Photo" pill.
class ResultHero extends StatelessWidget {
  const ResultHero({
    required this.headline,
    required this.deck,
    required this.tint,
    this.photo,
    this.onViewPhoto,
    super.key,
  });

  final String headline;
  final String deck;
  final Color tint;
  final Widget? photo;
  final VoidCallback? onViewPhoto;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: headline),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Icon(LucideIcons.sparkles,
                            size: 17, color: Colors.white),
                      ),
                    ),
                  ]),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4),
                ),
                const SizedBox(height: 8),
                Text(deck,
                    style: const TextStyle(
                        color: Color(0xFF9BA5A0), fontSize: 13, height: 1.42)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 48,
            child: AspectRatio(
              aspectRatio: 0.92,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: photo ??
                          const ColoredBox(color: Color(0xFF141B14)),
                    ),
                  ),
                  if (onViewPhoto != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: InkWell(
                          onTap: onViewPhoto,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.maximize2,
                                  size: 13, color: Colors.white),
                              SizedBox(width: 5),
                              Text('View Photo',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the mockup puts "Overall Risk Level · Low · 68% confidence".
///
/// A severity grade and a rendered confidence, in one card. It carries the
/// action and its window instead — the two things the contract says an output
/// may never terminate without.
class ResultActionCard extends StatelessWidget {
  const ResultActionCard({
    required this.action,
    required this.icon,
    required this.detail,
    required this.chip,
    required this.tint,
    super.key,
  });

  final String action;

  /// The ladder's glyph. Colour is never the only signal (a11y, §2.2), so the
  /// icon travels with the hue rather than being decided here.
  final IconData icon;
  final String detail;
  final String chip;

  /// **Safety-locked.** This is the action ladder's hue, not the page accent —
  /// see `_actionColor`. The mockup paints this card lime at the floor; the
  /// floor is calm slate, and never reads as "all clear".
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.10),
              border: Border.all(color: tint.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                    color: tint.withValues(alpha: 0.28),
                    blurRadius: 20,
                    spreadRadius: -4)
              ],
            ),
            child: Icon(icon, size: 24, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What to do next',
                    style: TextStyle(
                        color: Color(0xFF9BA5A0), fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(action,
                    style: TextStyle(
                        color: tint,
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(detail,
                    style: const TextStyle(
                        color: Color(0xFFB8C2BB), fontSize: 12.5, height: 1.35)),
                const SizedBox(height: 9),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    color: tint.withValues(alpha: 0.10),
                    border: Border.all(color: tint.withValues(alpha: 0.32)),
                  ),
                  child: Text(chip,
                      style: TextStyle(
                          color: tint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "AI Summary" card, doodle and "generated" stamp included.
class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({
    required this.body,
    required this.stamp,
    required this.tint,
    super.key,
  });

  final String body;
  final String stamp;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      accent: tint.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.sparkles, size: 17, color: tint),
            const SizedBox(width: 7),
            Text('AI Summary',
                style: TextStyle(
                    color: tint, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.clock,
                    size: 12, color: Color(0xFF9BA5A0)),
                const SizedBox(width: 4),
                Text(stamp,
                    style: const TextStyle(
                        color: Color(0xFF9BA5A0), fontSize: 11)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(body,
                    style: const TextStyle(
                        color: Color(0xFFDCE3DE),
                        fontSize: 13.5,
                        height: 1.45)),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.dog, size: 44, color: tint),
            ],
          ),
        ],
      ),
    );
  }
}

/// One of the two side-by-side list cards. The mockup's left cell is a named
/// cause with a differential; its right cell is an all-clear checklist. Both
/// carry lists here instead, and the bullets are neutral — a column of green
/// ticks reads as "nothing wrong" whatever the words next to it say.
class ResultListCard extends StatelessWidget {
  const ResultListCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.tint,
    this.emptyLabel,
    this.footerLabel,
    this.onFooter,
    super.key,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final Color tint;
  final String? emptyLabel;
  final String? footerLabel;
  final VoidCallback? onFooter;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  maxLines: 2,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty && emptyLabel != null)
            Text(emptyLabel!,
                style: const TextStyle(
                    color: Color(0xFF7F8A85), fontSize: 12, height: 1.35))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, color: tint),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              color: Color(0xFFC7D0C9),
                              fontSize: 12,
                              height: 1.35)),
                    ),
                  ],
                ),
              ),
          if (footerLabel != null) ...[
            const SizedBox(height: 2),
            InkWell(
              onTap: onFooter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(footerLabel!,
                      style: TextStyle(
                          color: tint,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  Icon(LucideIcons.chevronRight, size: 14, color: tint),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The "Recommendations" / "What you can do" rows: glyph, two lines, a kind
/// badge, a chevron.
class ResultActionRow extends StatelessWidget {
  const ResultActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.badge,
    required this.tint,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String badge;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10160F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: tint.withValues(alpha: 0.10),
                    border: Border.all(color: tint.withValues(alpha: 0.30)),
                  ),
                  child: Icon(icon, size: 18, color: tint),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(detail,
                          style: const TextStyle(
                              color: Color(0xFF8A948D),
                              fontSize: 11.5,
                              height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    color: tint.withValues(alpha: 0.14),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          color: tint,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(LucideIcons.chevronRight,
                    size: 16, color: Colors.white.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The three-across button row: Save Report · Share with Vet · Add to Diary.
class ResultActionBar extends StatelessWidget {
  const ResultActionBar({
    required this.onSave,
    required this.onShare,
    required this.onDiary,
    required this.tint,
    this.saveSoon = false,
    this.shareKey,
    super.key,
  });

  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onDiary;
  final Color tint;

  /// Marks Save Report as not yet built. The mockup's button stays exactly
  /// where it is — it simply says so, rather than quietly doing something
  /// else when tapped.
  final bool saveSoon;
  final Key? shareKey;

  @override
  Widget build(BuildContext context) {
    Widget outline(IconData icon, String label, VoidCallback onTap,
            {Key? k, bool soon = false}) =>
        Expanded(
          child: OutlinedButton(
            key: k,
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 17,
                    color: soon ? tint.withValues(alpha: 0.5) : tint),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            maxLines: 1,
                            style: TextStyle(
                                color: soon
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (soon)
                          Text('Soon',
                              style: TextStyle(
                                  color: tint.withValues(alpha: 0.75),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(children: [
      outline(LucideIcons.fileDown, 'Save Report', onSave, soon: saveSoon),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          key: shareKey,
          onPressed: onShare,
          style: FilledButton.styleFrom(
            backgroundColor: tint,
            foregroundColor: const Color(0xFF06140A),
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.stethoscope, size: 17),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: const Text('Share with Vet',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      outline(LucideIcons.calendarPlus, 'Add to Diary', onDiary),
    ]);
  }
}

/// The "Track Symptoms" cell, sparkline and all.
class ResultTrendCard extends StatelessWidget {
  const ResultTrendCard({
    required this.petName,
    required this.points,
    required this.onTap,
    required this.tint,
    super.key,
  });

  final String petName;

  /// 0..1, oldest first. Empty draws the flat invitation state.
  final List<double> points;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Track Symptoms',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('See how $petName is doing over time.',
              style: const TextStyle(
                  color: Color(0xFF8A948D), fontSize: 11.5, height: 1.3)),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: points.length < 2
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Not enough checks yet',
                        style: TextStyle(
                            color: tint.withValues(alpha: 0.75),
                            fontSize: 11.5)),
                  )
                : CustomPaint(
                    painter: _SparkPainter(points, tint),
                    size: Size.infinite),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View History',
                    style: TextStyle(
                        color: tint,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
                Icon(LucideIcons.chevronRight, size: 14, color: tint),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.points, this.tint);

  final List<double> points;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(dx * i, size.height * (1 - points[i].clamp(0, 1)));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = tint,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        Offset(dx * i, size.height * (1 - points[i].clamp(0, 1))),
        3.2,
        Paint()..color = tint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points || old.tint != tint;
}

/// The closing "Still have questions? / Ask AI Assistant" strip.
class ResultAssistantStrip extends StatelessWidget {
  const ResultAssistantStrip({
    required this.title,
    required this.detail,
    required this.onAsk,
    required this.tint,
    super.key,
  });

  final String title;
  final String detail;
  final VoidCallback onAsk;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(LucideIcons.sparkles, size: 26, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(
                        color: Color(0xFF8A948D), fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('result_ask_assistant'),
            onPressed: onAsk,
            style: FilledButton.styleFrom(
              backgroundColor: tint,
              foregroundColor: const Color(0xFF06140A),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.messageCircle, size: 16),
              SizedBox(width: 5),
              Text('Ask AI',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_assets.dart';
import 'onboarding_ui.dart';

/// The large composed illustrations of the onboarding pages (`004`–`009`).
///
/// These are the parts of the mockups that are *pictures*, not layout: the
/// two-card collision on `004`, the device-plus-animal stages on `005`–`007`,
/// the species gallery and form on `008`, the celebration hero on `009`. They
/// live apart from `onboarding_flow.dart` because each is a hundred-odd lines
/// of stacking and none of them owns state, copy decisions or navigation.
///
/// **Safety.** Everything a device screen in here depicts is product output, so
/// it follows the contract rather than the mockup wherever the two disagree —
/// see the notes on `_DiaryScreen` and `_ChatScreen`. No condition is named, no
/// severity graded, no all-clear rendered, and every sample ends with an action
/// and a timeframe.

// ---------------------------------------------------------------------------
// 004 · emergency vs keep-watching
// ---------------------------------------------------------------------------

/// The two glass cards and the light collision that separates them.
///
/// The collision is the supplied `onb-collision-notequal` plate, composited
/// with `BlendMode.screen` so its black ground drops out and the red and cyan
/// streaks spill over both cards exactly as the mockup draws them — a matte
/// would leave a visible box across the middle of the composition.
class EmergencyCompareStage extends StatelessWidget {
  const EmergencyCompareStage({super.key});

  static const _red = Color(0xFFFF5A52);
  static const _green = AppColors.emerald400;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                child: _CompareCard(
                  tint: _red,
                  title: 'Emergency',
                  subtitle: 'Act Now',
                  notch: _SirenNotch(),
                  rows: [
                    (LucideIcons.activity, 'Immediate guidance'),
                    (LucideIcons.plus, 'First aid steps'),
                    (LucideIcons.mapPin, 'Find a vet near you'),
                  ],
                  chip: 'Always Free',
                ),
              ),
              const SizedBox(width: 34),
              const Expanded(
                child: _CompareCard(
                  tint: _green,
                  title: 'Keep Watching',
                  subtitle: 'Monitor Safely',
                  notch: _HouseNotch(),
                  rows: [
                    (LucideIcons.shieldCheck, 'AI suggests monitoring'),
                    (LucideIcons.calendarDays, 'Track changes over time'),
                    (LucideIcons.heart, 'Know when to call the vet'),
                  ],
                  chip: 'Smart & Safe',
                ),
              ),

            ],
          ),
        ),
        // The streaks and the ≠ node sit in front of both cards.
        Positioned(
          top: 128,
          child: IgnorePointer(
            child: BlendMask(
              blendMode: BlendMode.screen,
              child: Image.asset(
                UiAssets.onbCollisionNotequal,
                width: 250,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.chip,
    required this.notch,
  });

  final Color tint;
  final String title;
  final String subtitle;
  final List<(IconData, String)> rows;
  final String chip;
  final Widget notch;

  @override
  Widget build(BuildContext context) {
    Widget rule() => Container(
        height: 1, color: Colors.white.withValues(alpha: 0.07));

    return OnbNeonCard(
      tint: tint,
      radius: 28,
      notch: notch,
      notchSize: 52,
      fill: 0.020,
      glow: 0.20,
      padding: const EdgeInsets.fromLTRB(10, 28, 10, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.18,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: tint,
                    fontSize: 14.5,
                    height: 1.22,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          rule(),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  OnbRowChip(r.$1, tint: tint, size: 28),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(r.$2,
                        style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 10.5,
                            height: 1.26)),
                  ),
                ],
              ),
            ),
          // Pushes the closing rule and chip to the card's foot, so the two
          // cards' chips line up even though their row counts differ.
          const Spacer(),
          rule(),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(chip,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: tint, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// The red beacon straddling the emergency card's top edge, rays and all.
class _SirenNotch extends StatelessWidget {
  const _SirenNotch();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 68,
        height: 52,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            const Positioned.fill(
                child: _Rays(tint: EmergencyCompareStage._red)),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: OnbNeonGlyph(LucideIcons.siren,
                  tint: EmergencyCompareStage._red, size: 34),
            ),
          ],
        ),
      );
}

class _Rays extends StatelessWidget {
  const _Rays({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(painter: _RayPainter(tint), size: Size.infinite));
}

class _RayPainter extends CustomPainter {
  const _RayPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final p = Paint()
      ..color = tint.withValues(alpha: 0.85)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (final deg in [-74.0, -48.0, 0.0, 48.0, 74.0]) {
      final a = (deg - 90) * math.pi / 180;
      final r0 = size.height * 0.42, r1 = size.height * 0.58;
      canvas.drawLine(
        origin + Offset(math.cos(a) * r0, math.sin(a) * r0),
        origin + Offset(math.cos(a) * r1, math.sin(a) * r1),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RayPainter old) => old.tint != tint;
}

/// The green house with a paw in it, on the keep-watching card.
class _HouseNotch extends StatelessWidget {
  const _HouseNotch();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 68,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const OnbNeonGlyph(LucideIcons.house,
                tint: EmergencyCompareStage._green, size: 46),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(LucideIcons.pawPrint,
                  size: 17,
                  color: EmergencyCompareStage._green.withValues(alpha: 0.95)),
            ),
          ],
        ),
      );
}

/// `004`'s transparency panel — the mockup's own framing, which the safety
/// review names as correct, kept verbatim.
class DoesNotDiagnosePanel extends StatelessWidget {
  const DoesNotDiagnosePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return OnbNeonCard(
      tint: AppColors.cyan300,
      radius: 22,
      borderAlpha: 0.22,
      glow: 0.10,
      fill: 0.02,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            UiAssets.onbShieldPawTeal3d,
            height: 62,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const OnbNeonGlyph(
                LucideIcons.shieldCheck, tint: AppColors.cyan300, size: 44),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PawDoc does not diagnose.',
                    style: TextStyle(
                        color: AppColors.emerald400,
                        fontSize: 14.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                    'We provide AI-powered guidance,\nnot a replacement for '
                    'your veterinarian.',
                    style: TextStyle(
                        color: Color(0xFFC3CCD9), fontSize: 12.5, height: 1.34)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 005 · the health diary
// ---------------------------------------------------------------------------

/// Decorative rail hues.
///
/// The mockup tints the fourth item amber, but amber is `monitorLight` — a
/// safety-locked status colour that design_tokens forbids using as decoration —
/// so Memories takes a rose that carries no triage meaning.
class _RailHue {
  const _RailHue._();
  static const violet = Color(0xFFA78BFA);
  static const rose = Color(0xFFF472B6);
  static const azure = Color(0xFF60A5FA);
}

/// `005`'s composition: the capability rail, the device, the callout bubble and
/// the pair of animals, all pooled in one floor glow.
///
/// The reference sets the rail's labels at roughly eight points — legible in a
/// poster, not on a handset — so the rail keeps the mockup's *shape* (glyph,
/// title, caption, dotted spine) at sizes that can actually be read, and the
/// device gives back the width that costs. Nothing is dropped.
class DiaryStage extends StatelessWidget {
  const DiaryStage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 372,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
              left: -40, right: -40, bottom: -10, height: 150,
              child: OnbFloorGlow()),
          // The pair sit behind the device, bleeding off the right edge exactly
          // as the reference crops them.
          Positioned(
            right: -22,
            bottom: -4,
            child: Image.asset(
              UiAssets.onbHeroDogKittenCutout,
              height: 212,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const Positioned(left: 0, top: 2, width: 104, child: _DiaryRail()),
          const Align(
            alignment: Alignment(0.033, 0),
            child: OnbPhoneMockup(height: 320, child: _DiaryScreen()),
          ),
          Positioned(
            right: 0,
            top: 26,
            child: OnbSpeechBubble(
              tint: AppColors.cyan300,
              width: 90,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12),
                  Text('A complete health story for a happier, healthier life.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white, fontSize: 10.5, height: 1.32)),
                ],
              ),
            ),
          ),
          // The shield badge straddles the bubble's top edge.
          Positioned(
            right: 24,
            top: 2,
            child: Image.asset(
              UiAssets.onbShieldPawTeal3d,
              height: 52,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const OnbNeonGlyph(
                  LucideIcons.shieldCheck, tint: AppColors.cyan300, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

/// The five-stop capability rail down the left of `005`, dotted spine included.
class _DiaryRail extends StatelessWidget {
  const _DiaryRail();

  static const _items = <(IconData, String, String, Color)>[
    (LucideIcons.chartLine, 'Health Timeline', 'See the big picture at a glance.',
        AppColors.cyan400),
    (LucideIcons.syringe, 'Vaccinations', 'Never miss an important shot.',
        AppColors.emerald400),
    (LucideIcons.calendarDays, 'Reminders', 'Smart alerts for what matters.',
        _RailHue.violet),
    (LucideIcons.image, 'Memories', 'Save moments that matter.', _RailHue.rose),
    (LucideIcons.fileText, 'Reports', 'Export beautiful PDF summaries.',
        AppColors.cyan300),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(left: 13),
              child: _DottedSpine(height: 18),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RailBadge(icon: _items[i].$1, tint: _items[i].$4),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_items[i].$2,
                        style: TextStyle(
                            // The mockup colours only the first title; the rest
                            // are white.
                            color: i == 0 ? AppColors.cyan400 : Colors.white,
                            fontSize: 11,
                            height: 1.16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_items[i].$3,
                        style: const TextStyle(
                            color: Color(0xFF8B96A6),
                            fontSize: 9.5,
                            height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RailBadge extends StatelessWidget {
  const _RailBadge({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint.withValues(alpha: 0.09),
          border: Border.all(color: tint.withValues(alpha: 0.50)),
          boxShadow: [
            BoxShadow(
                color: tint.withValues(alpha: 0.26),
                blurRadius: 12,
                spreadRadius: -2),
          ],
        ),
        child: OnbNeonGlyph(icon, tint: tint, size: 14, strength: 0.5),
      );
}

class _DottedSpine extends StatelessWidget {
  const _DottedSpine({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: 2,
          height: height,
          child: CustomPaint(painter: _SpinePainter()),
        ),
      );
}

class _SpinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF33415A)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var y = 0.0; y < size.height - 1; y += 5) {
      canvas.drawLine(Offset(1, y), Offset(1, y + 1.6), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// What `005`'s phone shows.
///
/// The mockup's first row reads *"AI Health Check · ✦Low · Mild coughing
/// detected. Monitor at home."* — a finding, a severity grade and a terminating
/// instruction with no timeframe. All three are contract breaks (review V-14),
/// so the row states what was observed and when to recheck, and the badge is
/// gone: `confidence` and severity are never rendered.
class _DiaryScreen extends StatelessWidget {
  const _DiaryScreen();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 150,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Text('9:41',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w700)),
                Spacer(),
                Icon(LucideIcons.signalHigh, size: 7, color: Colors.white),
                SizedBox(width: 2),
                Icon(LucideIcons.wifi, size: 7, color: Colors.white),
                SizedBox(width: 2),
                Icon(LucideIcons.batteryFull, size: 8, color: Colors.white),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.emerald400.withValues(alpha: 0.85),
                        width: 1.2),
                  ),
                  child: ClipOval(
                    child: Image.asset(UiAssets.petBuddyAvatar,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Color(0xFF14203A))),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Buddy',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const Icon(LucideIcons.chevronDown,
                    size: 9, color: Color(0xFF9AA6B6)),
                const Spacer(),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF19233A)),
                  child: const Icon(LucideIcons.plus,
                      size: 10, color: Colors.white),
                ),
              ]),
              const SizedBox(height: 7),
              Row(children: [
                for (final (label, on) in const [
                  ('All', true),
                  ('Health', false),
                  ('Vaccines', false),
                  ('Notes', false),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: on
                            ? AppColors.emerald500.withValues(alpha: 0.16)
                            : const Color(0xFF141D30),
                        border: Border.all(
                            color: on
                                ? AppColors.emerald400.withValues(alpha: 0.8)
                                : const Color(0xFF243044)),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: on
                                  ? AppColors.emerald400
                                  : const Color(0xFFB9C3D1),
                              fontSize: 6.5)),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Timeline',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(LucideIcons.listFilter,
                    size: 8, color: AppColors.cyan400),
                const SizedBox(width: 2),
                const Text('Filter',
                    style: TextStyle(color: AppColors.cyan400, fontSize: 7)),
              ]),
              const SizedBox(height: 5),
              const _TimelineRow(
                tint: AppColors.emerald400,
                icon: LucideIcons.scanHeart,
                title: 'AI Health Check',
                date: 'Today',
                body: 'Cough noted — keep watching.\nRecheck within 24–48 hours.',
                thumb: UiAssets.petBuddyAvatar,
              ),
              const _TimelineRow(
                tint: _RailHue.azure,
                icon: LucideIcons.syringe,
                title: 'Rabies Vaccine',
                date: 'May 28',
                body: 'Next: May 28, 2026',
              ),
              const _TimelineRow(
                tint: AppColors.cyan300,
                icon: LucideIcons.chartLine,
                title: 'Weight',
                date: 'May 20',
                body: '24.3 kg',
              ),
              const _TimelineRow(
                tint: _RailHue.violet,
                icon: LucideIcons.notebookPen,
                title: 'Note Added',
                date: 'May 18',
                body: 'Changed food brand to\ngrain-free formula.',
              ),
              const _TimelineRow(
                tint: _RailHue.rose,
                icon: LucideIcons.image,
                title: 'Memory',
                date: 'May 10',
                body: 'First beach day!',
                thumb: UiAssets.petBuddyParkPortrait,
                last: true,
              ),
              const SizedBox(height: 6),
              Container(height: 1, color: const Color(0xFF1A2438)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (icon, label, on) in const [
                    (LucideIcons.house, 'Home', false),
                    (LucideIcons.notebookPen, 'Diary', true),
                    (LucideIcons.messageCircle, 'Assistant', false),
                    (LucideIcons.bell, 'Community', false),
                    (LucideIcons.user, 'Profile', false),
                  ])
                    Column(children: [
                      Icon(icon,
                          size: 10,
                          color: on
                              ? AppColors.emerald400
                              : const Color(0xFF7C8AA0)),
                      const SizedBox(height: 1),
                      Text(label,
                          style: TextStyle(
                              color: on
                                  ? AppColors.emerald400
                                  : const Color(0xFF7C8AA0),
                              fontSize: 5.5)),
                    ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.tint,
    required this.icon,
    required this.title,
    required this.date,
    required this.body,
    this.thumb,
    this.last = false,
  });

  final Color tint;
  final IconData icon;
  final String title;
  final String date;
  final String body;
  final String? thumb;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The spine and its node, as the mockup threads them down the list.
          SizedBox(
            width: 7,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: last ? null : 0,
                  height: last ? 14 : null,
                  child: Container(width: 1, color: const Color(0xFF22304A)),
                ),
                Positioned(
                  top: 12,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: tint),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1526),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint.withValues(alpha: 0.16),
                      border:
                          Border.all(color: tint.withValues(alpha: 0.55)),
                    ),
                    child: Icon(icon, size: 10, color: tint),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text(date,
                              style: const TextStyle(
                                  color: Color(0xFF7C8AA0), fontSize: 5.5)),
                        ]),
                        const SizedBox(height: 1),
                        Text(body,
                            style: const TextStyle(
                                color: Color(0xFFAFBACA),
                                fontSize: 7,
                                height: 1.3)),
                      ],
                    ),
                  ),
                  if (thumb != null) ...[
                    const SizedBox(width: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(thumb!,
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const SizedBox(
                              width: 22,
                              height: 22,
                              child: ColoredBox(color: Color(0xFF14203A)))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 006 / 007 · the assistant
// ---------------------------------------------------------------------------

/// A photographic plate composited with `BlendMode.screen`.
///
/// The supplied heroes are rendered on black rather than on alpha. Under
/// `screen` black is the identity, so the plate merges into the navy canvas
/// with no matte line — and because the canvas is nearly black the animals come
/// through essentially unchanged. A soft side-and-top fade finishes the join,
/// which is how the mockups bleed these into the page.
class HeroPlate extends StatelessWidget {
  const HeroPlate(this.asset, {required this.height, this.fade = true, super.key});

  final String asset;
  final double height;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final image = BlendMask(
      blendMode: BlendMode.screen,
      child: Image.asset(
        asset,
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => SizedBox(height: height),
      ),
    );
    if (!fade) return image;
    // Two passes: the plate is a rectangle, and one gradient cannot dissolve
    // both axes. Sides first, then the top — the bottom is left alone because
    // that is where the animals' feet are.
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white],
        stops: [0.0, 0.24, 1.0],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0.0, 0.22, 0.78, 1.0],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: image,
      ),
    );
  }
}

/// The hero plate with the pair of heart bubbles the mockups float beside it.
class HeroWithHearts extends StatelessWidget {
  const HeroWithHearts({
    required this.asset,
    required this.height,
    required this.tint,
    super.key,
  });

  final String asset;
  final double height;
  final Color tint;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          HeroPlate(asset, height: height),
          Positioned(
              left: 6,
              top: height * 0.30,
              child: OnbNeonGlyph(LucideIcons.messageCircleHeart,
                  tint: tint, size: 26)),
          Positioned(
              right: 8,
              top: height * 0.22,
              child: OnbNeonGlyph(LucideIcons.messageCircleHeart,
                  tint: tint, size: 22)),
        ],
      );
}

/// The device flanked by capability cards, as `006` and `007` both compose it.
///
/// The mockups sit the cards at roughly 68dp with ~10pt labels. Here they take
/// the width back from the device — the reading order (card · tether · screen)
/// is what the composition is doing, and a card too narrow to hold its own
/// title would lose it.
class AssistantStage extends StatelessWidget {
  const AssistantStage({
    required this.left,
    required this.right,
    required this.screen,
    this.phoneHeight = 360,
    super.key,
  });

  final List<OnbSideCard> left;
  final List<OnbSideCard> right;
  final Widget screen;
  final double phoneHeight;

  @override
  Widget build(BuildContext context) {
    Widget column(List<OnbSideCard> cards, {required bool fromLeft}) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:
              fromLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: fromLeft
                    ? [cards[i], OnbDashTether(tint: cards[i].tint, width: 13)]
                    : [
                        OnbDashTether(
                            tint: cards[i].tint, width: 13, fromLeft: false),
                        cards[i],
                      ],
              ),
            ],
          ],
        );

    // The row, not a fixed box, sets the stage height: `007` stacks three cards
    // a side, which is taller than the device, and a hard height would clip
    // them (it did — 35px, on the Redmi).
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
            left: -40, right: -40, bottom: -16, height: 130,
            child: const OnbFloorGlow()),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            column(left, fromLeft: true),
            OnbPhoneMockup(height: phoneHeight, child: screen),
            column(right, fromLeft: false),
          ],
        ),
      ],
    );
  }
}

/// The paw-in-a-ring crest with the small `+` badge, drawn on `007` in emerald
/// and on `008` in cyan. No supplied plate carries it, so it is composed.
class PawPlusCrest extends StatelessWidget {
  const PawPlusCrest({required this.tint, this.size = 62, super.key});

  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.0,
      height: size + 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 22,
            child: OnbGroundRings(tint: tint),
          ),
          Positioned(
            left: size * 0.18,
            top: 4,
            child: Icon(LucideIcons.sparkles,
                size: size * 0.20, color: tint.withValues(alpha: 0.75)),
          ),
          Positioned(
            right: size * 0.20,
            top: size * 0.30,
            child: Icon(LucideIcons.sparkles,
                size: size * 0.16, color: tint.withValues(alpha: 0.60)),
          ),
          Positioned(
            top: 0,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: tint.withValues(alpha: 0.90), width: 1.6),
                      boxShadow: [
                        BoxShadow(
                            color: tint.withValues(alpha: 0.34),
                            blurRadius: 22,
                            spreadRadius: -2),
                      ],
                    ),
                    child: OnbNeonGlyph(LucideIcons.pawPrint,
                        tint: tint, size: size * 0.52),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 0,
                    child: Container(
                      width: size * 0.30,
                      height: size * 0.30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF050B14),
                        border: Border.all(
                            color: tint.withValues(alpha: 0.90), width: 1.4),
                      ),
                      child: Icon(LucideIcons.plus,
                          size: size * 0.18, color: tint),
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

/// One turn of an assistant conversation, drawn inside a device.
///
/// Neither mockup's answer ships as written. `006` has the assistant reply
/// *"Sneezing can be caused by mild irritants, allergies, or infections"* —
/// three named conditions asserted as causes (review V-13). `007` is the
/// compliant reference the review points at, and its answer is reproduced.
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    required this.title,
    required this.subtitle,
    required this.question,
    required this.time,
    required this.opening,
    required this.leadIn,
    required this.checks,
    required this.closing,
    required this.disclaimer,
    required this.avatar,
    this.sendIcon = LucideIcons.send,
    super.key,
  });

  final String title;
  final String subtitle;
  final String question;
  final String time;
  final String opening;
  final String leadIn;
  final List<String> checks;
  final String? closing;
  final String disclaimer;
  final String avatar;
  final IconData sendIcon;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(color: Color(0xFFDCE3EC), fontSize: 7, height: 1.34);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 5),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 150,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Text('9:41',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w700)),
                Spacer(),
                Icon(LucideIcons.signalHigh, size: 7, color: Colors.white),
                SizedBox(width: 2),
                Icon(LucideIcons.wifi, size: 7, color: Colors.white),
                SizedBox(width: 2),
                Icon(LucideIcons.batteryFull, size: 8, color: Colors.white),
              ]),
              const SizedBox(height: 7),
              Row(children: [
                const Icon(LucideIcons.menu, size: 9, color: Color(0xFF9AA6B6)),
                const SizedBox(width: 6),
                const Icon(LucideIcons.pawPrint,
                    size: 10, color: AppColors.emerald400),
                const SizedBox(width: 3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                      Text('• $subtitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.emerald400, fontSize: 5.5)),
                    ],
                  ),
                ),
                const Icon(LucideIcons.history, size: 9, color: Color(0xFF9AA6B6)),
              ]),
              const SizedBox(height: 8),
              // Owner turn.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 22),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withValues(alpha: 0.18),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(question,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  height: 1.34)),
                          const SizedBox(height: 1),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(time,
                                style: const TextStyle(
                                    color: Color(0xFF8FB39A), fontSize: 5)),
                            const SizedBox(width: 2),
                            const Icon(LucideIcons.checkCheck,
                                size: 6, color: AppColors.emerald400),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  ClipOval(
                    child: Image.asset(avatar,
                        width: 15,
                        height: 15,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox(
                            width: 15,
                            height: 15,
                            child: ColoredBox(color: Color(0xFF14203A)))),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Assistant turn.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2B),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opening, style: body),
                    const SizedBox(height: 4),
                    Text(leadIn, style: body),
                    const SizedBox(height: 3),
                    for (final c in checks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(LucideIcons.circleCheck,
                                  size: 7, color: AppColors.emerald400),
                            ),
                            const SizedBox(width: 3),
                            Expanded(child: Text(c, style: body)),
                          ],
                        ),
                      ),
                    if (closing != null) ...[
                      const SizedBox(height: 2),
                      Text(closing!, style: body),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: AppColors.emerald500.withValues(alpha: 0.34)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.shieldCheck,
                              size: 7, color: AppColors.emerald400),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(disclaimer,
                                style: const TextStyle(
                                    color: Color(0xFFD9C98A),
                                    fontSize: 6,
                                    height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Row(children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF19233A)),
                  child:
                      const Icon(LucideIcons.plus, size: 9, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141D30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Ask anything about your pet…',
                        style:
                            TextStyle(color: Color(0xFF6C7A8C), fontSize: 6)),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.emerald500),
                  child:
                      Icon(sendIcon, size: 8, color: const Color(0xFF04140A)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `24/7` dial the `004` trust strip opens with. Lucide has a clock, but
/// the mockup draws the literal legend, and that is the thing being promised.
class OnbAlwaysOnDial extends StatelessWidget {
  const OnbAlwaysOnDial({this.size = 60, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size + 16,
        height: size + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.cyan300.withValues(alpha: 0.13),
                  Colors.transparent,
                ]),
              ),
              child: SizedBox(width: size + 16, height: size + 16),
            ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.cyan300.withValues(alpha: 0.85), width: 1.6),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.cyan300.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -2),
                ],
              ),
              alignment: Alignment.center,
              child: Text('24/7',
                  style: TextStyle(
                      color: AppColors.cyan300,
                      fontSize: size * 0.30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5)),
            ),
          ],
        ),
      );
}

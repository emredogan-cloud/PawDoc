import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../analysis/analysis_service.dart';
import '../core/action_labels.dart';
import '../core/last_check.dart';
import '../home/home_sections.dart';
import '../pets/pet.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import '../theme/ui_assets.dart';
import 'health_check_chrome.dart';
import 'health_check_photo_screen.dart';

/// Step 1 of the AI Health Check (mockup `ai_health_check_start`).
///
/// **Safety.** The mockup's capability grid reads *"Skin & Coat — Identify
/// irritation, allergies & more"* and *"Eyes, Ears & Nose — Check for signs of
/// infection"*. Both name conditions the product must never claim to identify
/// (CLAUDE.md rule 3; `safety_copy_test` bans "allergic reaction", "ear
/// infection" and their neighbours). The grid keeps its four cells and its
/// artwork; each says what the owner can *describe* instead of what the model
/// would *find*.
///
/// The mockup's "Recent Checks" row also carries a `Low risk` grade. Certainty
/// is never quantified and severity is never graded, so the row shows the
/// action the check ended on — which is what the owner actually needs to see.
class HealthCheckStartScreen extends ConsumerWidget {
  const HealthCheckStartScreen({
    required this.pet,
    required this.isPremium,
    super.key,
  });

  final Pet pet;
  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final lastTriage = ref.watch(latestTriageProvider(pet.id!));

    return HealthCheckScaffold(
      body: [
        _Hero(pet: pet),
        const SizedBox(height: AppSpace.s16),
        HomeCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('What can AI check?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Icon(LucideIcons.sparkles, size: 15, color: t.accent),
              ]),
              const SizedBox(height: AppSpace.s16),
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Capability(
                      icon: LucideIcons.heart,
                      title: 'General\nHealth',
                      caption: 'Describe overall well-being',
                    ),
                    _CapDivider(),
                    _Capability(
                      icon: LucideIcons.sprout,
                      title: 'Skin & Coat',
                      caption: 'Note redness, itching or hair loss',
                    ),
                    _CapDivider(),
                    _Capability(
                      icon: LucideIcons.eye,
                      title: 'Eyes, Ears\n& Nose',
                      caption: 'Note discharge or head shaking',
                    ),
                    _CapDivider(),
                    _Capability(
                      icon: LucideIcons.brain,
                      title: 'Behavior',
                      caption: 'Describe unusual behaviour',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              Container(
                  height: 1, color: Colors.white.withValues(alpha: 0.07)),
              const SizedBox(height: AppSpace.s12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(LucideIcons.lockKeyhole, size: 15, color: t.accent),
                const SizedBox(width: 7),
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Your data is '),
                      TextSpan(
                          text: 'private, secure',
                          style: TextStyle(
                              color: t.accent, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' and encrypted.'),
                    ]),
                    style: const TextStyle(
                        color: Color(0xFF9BA5A0), fontSize: 13),
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        HomeCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('How it works',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Icon(LucideIcons.sparkles, size: 15, color: t.accent),
              ]),
              const SizedBox(height: AppSpace.s16),
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Step(
                        index: 1,
                        icon: LucideIcons.camera,
                        title: 'Capture',
                        caption: 'Take a clear photo of the area'),
                    _StepArrow(),
                    _Step(
                        index: 2,
                        icon: LucideIcons.listChecks,
                        title: 'Answer',
                        caption: 'Tell us a few quick details'),
                    _StepArrow(),
                    _Step(
                        index: 3,
                        icon: LucideIcons.brain,
                        title: 'AI Analyzes',
                        caption: 'Our AI reviews and analyzes'),
                    _StepArrow(),
                    _Step(
                        index: 4,
                        icon: LucideIcons.shieldCheck,
                        title: 'Get Insights',
                        caption: 'Receive results and guidance'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        const _PhotoTipCard(),
        const SizedBox(height: AppSpace.s16),
        PawPrimaryButton(
          key: const Key('health_check_start'),
          icon: LucideIcons.sparkles,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                HealthCheckPhotoScreen(pet: pet, isPremium: isPremium),
          )),
          child: const Text('Start AI Health Check'),
        ),
        const SizedBox(height: AppSpace.s12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(LucideIcons.clock, size: 15, color: t.accent),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Takes about '),
              TextSpan(
                  text: '2–3 minutes',
                  style:
                      TextStyle(color: t.accent, fontWeight: FontWeight.w700)),
            ]),
            style: const TextStyle(color: Color(0xFF9BA5A0), fontSize: 13.5),
          ),
        ]),
        const SizedBox(height: AppSpace.s16),
        HomeListCard(
          icon: LucideIcons.history,
          title: 'Recent Checks',
          actionLabel: 'View All',
          onAction: () => Navigator.of(context).maybePop(),
          emptyLabel: 'No checks yet. The ones you run will be listed here.',
          rows: lastTriage.maybeWhen(
            data: (t) => t == null
                ? const []
                : [
                    (
                      LucideIcons.scanHeart,
                      pet.name,
                      // Never the wire level or a severity grade — the action
                      // the check ended on (contract v2).
                      actionLabel(t.level),
                      t.checkedAt == null ? '' : lastCheckLabel(t.checkedAt!),
                      null as Color?,
                      null as VoidCallback?,
                    ),
                  ],
            orElse: () =>
                const <(IconData, String, String, String, Color?, VoidCallback?)>[],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        const HealthCheckDisclaimer(),
      ],
    );
  }
}

/// The split hero: the wordmark headline on the left, the pair lit by a green
/// halo on the right, with the mockup's floating plus/heart glyphs.
class _Hero extends StatelessWidget {
  const _Hero({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -60,
            top: -20,
            width: 300,
            height: 290,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    t.accent.withValues(alpha: 0.30),
                    t.accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ], stops: const [0.0, 0.52, 1.0]),
                ),
              ),
            ),
          ),
          Positioned(
            right: -26,
            top: 8,
            width: 262,
            child: IgnorePointer(
              // The mockup's hero *is* this plate — the pair inside a green
              // halo. It is rendered on black, so `screen` drops the ground
              // out against the near-black canvas with no matte line, which a
              // square species portrait behind a radial mask never matched.
              child: BlendMask(
                blendMode: BlendMode.screen,
                child: Image.asset(
                  UiAssets.onbHeroDogCatHalo,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned(
              left: 148,
              top: 128,
              child: _FloatGlyph(icon: LucideIcons.plus, tint: t.accent)),
          Positioned(
              right: 22,
              top: 26,
              child: _FloatGlyph(icon: LucideIcons.plus, tint: t.accent)),
          Positioned(
              right: 4,
              top: 148,
              child: _FloatGlyph(icon: LucideIcons.plus, tint: t.accent, size: 26)),
          Positioned(
            right: 42,
            top: 88,
            child: Icon(LucideIcons.heartPulse, size: 40, color: t.accent),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'AI Health\n'),
                    TextSpan(text: 'Check', style: TextStyle(color: t.accent)),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(LucideIcons.sparkles,
                            size: 22, color: Colors.white),
                      ),
                    ),
                  ]),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8),
                ),
                const SizedBox(height: AppSpace.s12),
                SizedBox(
                  width: 190,
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Get AI-powered insights about your pet’s '
                              'health '),
                      TextSpan(
                          text: 'in minutes.',
                          style: TextStyle(
                              color: t.accent, fontWeight: FontWeight.w700)),
                    ]),
                    style: const TextStyle(
                        color: Color(0xFF9BA5A0), fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF0F150F),
                    border:
                        Border.all(color: t.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.shieldCheck, size: 18, color: t.accent),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 168,
                      child: Text(
                          'Not a replacement for professional veterinary '
                          'care.',
                          style: TextStyle(
                              color: Color(0xFFB8C2BB),
                              fontSize: 12.5,
                              height: 1.3)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatGlyph extends StatelessWidget {
  const _FloatGlyph({required this.icon, required this.tint, this.size = 32});

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          color: tint.withValues(alpha: 0.14),
          border: Border.all(color: tint.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: size * 0.55, color: tint),
      );
}

class _Capability extends StatelessWidget {
  const _Capability({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 28, color: t.accent),
          const SizedBox(height: 9),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF8A948D), fontSize: 10, height: 1.25)),
        ],
      ),
    );
  }
}

/// The `→` between the four "how it works" steps.
class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 15),
        child: Icon(LucideIcons.arrowRight, size: 15, color: Color(0xFF4A534C)),
      );
}

class _CapDivider extends StatelessWidget {
  const _CapDivider();

  @override
  Widget build(BuildContext context) => Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: const Color(0x14FFFFFF));
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.caption,
  });

  final int index;
  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Expanded(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF141B14),
                  border: Border.all(color: t.accent.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, size: 22, color: t.accent),
              ),
              Positioned(
                bottom: -8,
                child: Container(
                  width: 19,
                  height: 19,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: t.accent),
                  child: Text('$index',
                      style: const TextStyle(
                          color: Color(0xFF06140A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF8A948D), fontSize: 9.5, height: 1.25)),
        ],
      ),
    );
  }
}

/// "Better photos, better insights", with the mockup's three sample thumbs.
class _PhotoTipCard extends StatelessWidget {
  const _PhotoTipCard();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.10),
              border: Border.all(color: t.accent.withValues(alpha: 0.35)),
            ),
            child: Icon(LucideIcons.lightbulb, size: 19, color: t.accent),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Better photos, better insights',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text(
                    'Use good lighting and make sure the area is clearly '
                    'visible.',
                    style: TextStyle(
                        color: Color(0xFF8A948D), fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _SampleThumbs(),
        ],
      ),
    );
  }
}

class _SampleThumbs extends StatelessWidget {
  const _SampleThumbs();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    Widget thumb(String asset, bool good, double dim) => Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: good ? t.accent : Colors.white.withValues(alpha: 0.14)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Opacity(
                    opacity: dim,
                    child: Image.asset(asset,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Color(0xFF141B14))),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: good ? t.accent : const Color(0xFF3A423B),
                  ),
                  child: Icon(good ? LucideIcons.check : LucideIcons.x,
                      size: 11,
                      color: good ? const Color(0xFF06140A) : Colors.white),
                ),
              ),
            ],
          ),
        );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      thumb(AppAssets.species('dog'), true, 1),
      thumb(AppAssets.species('dog'), false, 0.45),
      thumb(AppAssets.species('dog'), false, 0.2),
    ]);
  }
}

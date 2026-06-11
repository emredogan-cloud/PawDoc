import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_image.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';

/// Analysis loading view: a calm "AI-thinking pulse" (concentric rings breathing
/// out from the shield-care mark) with rotating, reassuring messages (§3.5.1 /
/// §4.6). VISUAL ONLY — no analysis/timing/safety logic here.
///
/// M4 (#23): when [resolveColor] is set (runner, NON-EMERGENCY results only),
/// the rings do one 450ms settle in the verdict hue — the payoff curve after
/// the pulse. EMERGENCY never passes a color (instant cut preserved).
/// M4 (#22, flag-gated evaluation): [pulsePetSpecies] renders a small calm
/// (sleepy) Paw Pal beneath the message — "being cared for" — only when the
/// founder enables the PostHog experiment; control is pulse-only.
///
/// Reduce-motion: a static shield + a single static message (no rings, no
/// message timer) — which also keeps widget tests deterministic.
class AnalysisLoadingView extends StatefulWidget {
  const AnalysisLoadingView({super.key, this.resolveColor, this.pulsePetSpecies});

  /// Verdict hue for the one-shot resolve beat; null = normal pulsing.
  final Color? resolveColor;

  /// Species for the flag-gated pulse-pet variant; null = pulse only.
  final String? pulsePetSpecies;

  static const messages = [
    'Looking at the details…',
    'Checking for anything concerning…',
    'Comparing against common conditions…',
    'Putting together your guidance…',
  ];

  @override
  State<AnalysisLoadingView> createState() => _AnalysisLoadingViewState();
}

class _AnalysisLoadingViewState extends State<AnalysisLoadingView> {
  int _i = 0;
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rotate messages only when motion is allowed; otherwise show a static one.
    if (!_started && !reduceMotion(context)) {
      _started = true;
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) {
          setState(() => _i = (_i + 1) % AnalysisLoadingView.messages.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AiThinkingPulse(resolveColor: widget.resolveColor),
          const SizedBox(height: AppSpace.s24),
          Semantics(
            liveRegion: true,
            child: AnimatedSwitcher(
              duration: AppMotion.standard,
              child: Text(
                AnalysisLoadingView.messages[_i],
                key: ValueKey(_i),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (widget.pulsePetSpecies != null) ...[
            const SizedBox(height: AppSpace.s24),
            // #22 variant (flag-gated, default OFF): the pet rests calmly
            // while the AI works — sleepy state, deliberately not playful.
            LivingPetAvatar(
                species: widget.pulsePetSpecies!, size: 48, sleepy: true),
          ],
        ],
      ),
    );
  }
}

/// The shield-care mark with concentric rings emitting outward (calm cadence,
/// 1.6s loop). Static under reduce-motion. The pulse itself is UNCHANGED
/// (hard guardrail — code-drawn, never replaced by assets); [resolveColor]
/// only adds the one-shot 450ms verdict-hue settle on top (#23).
class _AiThinkingPulse extends StatelessWidget {
  const _AiThinkingPulse({this.resolveColor});
  final Color? resolveColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shield = AppImage(
      AppAssets.shieldCare,
      width: 72,
      height: 72,
      fallback: Icon(Icons.verified_user_rounded, size: 56, color: scheme.primary),
    );

    if (reduceMotion(context)) {
      return SizedBox(
        height: 160,
        child: Center(child: shield),
      );
    }

    if (resolveColor != null) {
      // #23: the built tension resolves — two rings settle outward in the
      // verdict hue (one shot, 450ms), the shield holds steady.
      return SizedBox(
        width: 180,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 2; i++)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: resolveColor!, width: 3),
                ),
              )
                  .animate()
                  .scaleXY(
                      begin: 0.8,
                      end: 1.7 + 0.4 * i,
                      duration: const Duration(milliseconds: 450),
                      delay: Duration(milliseconds: 90 * i),
                      curve: Curves.easeOut)
                  .fadeOut(
                      duration: const Duration(milliseconds: 450),
                      delay: Duration(milliseconds: 90 * i)),
            shield,
          ],
        ),
      );
    }

    return SizedBox(
      width: 180,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary, width: 2),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(
                    begin: 0.7,
                    end: 2.2,
                    duration: const Duration(milliseconds: 1600),
                    delay: Duration(milliseconds: 530 * i),
                    curve: Curves.easeOut)
                .fadeOut(
                    duration: const Duration(milliseconds: 1600),
                    delay: Duration(milliseconds: 530 * i)),
          shield
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                  begin: 1.0,
                  end: 1.05,
                  duration: const Duration(milliseconds: 1600),
                  curve: Curves.easeInOut),
        ],
      ),
    );
  }
}

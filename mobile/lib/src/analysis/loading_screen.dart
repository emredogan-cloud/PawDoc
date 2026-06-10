import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_image.dart';
import '../core/motion.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';

/// Analysis loading view: a calm "AI-thinking pulse" (concentric rings breathing
/// out from the shield-care mark) with rotating, reassuring messages (§3.5.1 /
/// §4.6). VISUAL ONLY — no analysis/timing/safety logic here.
///
/// Reduce-motion: a static shield + a single static message (no rings, no
/// message timer) — which also keeps widget tests deterministic.
class AnalysisLoadingView extends StatefulWidget {
  const AnalysisLoadingView({super.key});

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
          const _AiThinkingPulse(),
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
        ],
      ),
    );
  }
}

/// The shield-care mark with concentric rings emitting outward (calm cadence,
/// 1.6s loop). Static under reduce-motion.
class _AiThinkingPulse extends StatelessWidget {
  const _AiThinkingPulse();

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

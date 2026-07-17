import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app_image.dart';
import 'motion.dart';

/// The single integration point for Lottie motion assets (M1 "First breath",
/// PAWDOC_MOTION_ROADMAP.md §4 global conventions). Hard rules it enforces:
///
/// * **Reduce-motion → the static PNG** (the existing `AppAssets` slot) — the
///   motion layer simply does not exist for those users.
/// * **Pause offscreen/background**: playback only while ≥10% visible (via
///   [VisibilityDetector]; tickers already mute when the app is backgrounded).
/// * **Graceful degrade**: a missing/corrupt animation falls back to the PNG
///   (and the PNG itself falls back to [fallback], the `AppImage` pattern).
/// * **Controller disposed** with the widget; one instance = one animation.
///
/// `oneShot` plays once and holds the final frame (sign-in heartbeat).
/// `loopFromMarker` plays the intro once, then cycles from the named marker to
/// the end (settle → idle loop).
class AppMotionAsset extends StatefulWidget {
  const AppMotionAsset(
    this.motionAsset, {
    required this.fallbackAsset,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.oneShot = false,
    this.loopFromMarker,
    this.semanticLabel,
    super.key,
  }) : assert(!(oneShot && loopFromMarker != null),
            'oneShot and loopFromMarker are mutually exclusive');

  /// Lottie JSON under assets/motion/ (see [AppMotionAssets]).
  final String motionAsset;

  /// The static reduce-motion / degrade PNG (the existing AppAssets slot).
  final String fallbackAsset;

  /// Rendered when even the PNG is missing — never a broken box.
  final Widget fallback;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// Play once, hold the last frame. Used for trust surfaces (sign-in).
  final bool oneShot;

  /// Name of the marker the idle loop starts from; everything before it plays
  /// exactly once (e.g. the gift "settle-in").
  final String? loopFromMarker;

  /// Decorative animations pass null (excluded from semantics).
  final String? semanticLabel;

  @override
  State<AppMotionAsset> createState() => _AppMotionAssetState();
}

class _AppMotionAssetState extends State<AppMotionAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  LottieComposition? _composition;
  double _loopStart = 0;
  bool _visible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _png() => AppImage(
        widget.fallbackAsset,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        semanticLabel: widget.semanticLabel,
        fallback: widget.fallback,
      );

  void _onLoaded(LottieComposition composition) {
    _composition = composition;
    _controller.duration = composition.duration;
    final marker = widget.loopFromMarker == null
        ? null
        : composition.getMarker(widget.loopFromMarker!);
    if (marker != null && composition.durationFrames > 0) {
      _loopStart = ((marker.startFrame - composition.startFrame) /
              composition.durationFrames)
          .clamp(0.0, 1.0);
    }
    _play();
  }

  /// The loop segment duration (marker→end), so repeat() keeps real-time speed.
  Duration get _loopPeriod {
    final total = _composition?.duration ?? Duration.zero;
    if (_loopStart <= 0) return total;
    return total * (1 - _loopStart);
  }

  void _play() {
    if (!_visible || _composition == null || !mounted) return;
    if (widget.oneShot) {
      if (_controller.status != AnimationStatus.completed) {
        _controller.forward();
      }
      return;
    }
    if (_loopStart > 0 && _controller.value < _loopStart) {
      // Intro (settle-in) plays exactly once, then falls into the idle loop.
      _controller.forward().whenComplete(() {
        if (mounted && _visible) {
          _controller.repeat(min: _loopStart, max: 1, period: _loopPeriod);
        }
      });
      return;
    }
    _controller.repeat(min: _loopStart, max: 1, period: _loopPeriod);
  }

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.1;
    if (visible == _visible || !mounted) return;
    _visible = visible;
    if (visible) {
      _play();
    } else {
      _controller.stop(); // budget rule: never animate offscreen
    }
  }

  @override
  Widget build(BuildContext context) {
    // The gate is re-evaluated on every dependency change, so flipping the OS
    // setting swaps to the static PNG on the next frame.
    if (reduceMotion(context)) {
      _controller.stop();
      return _png();
    }
    return VisibilityDetector(
      key: ValueKey('motion_${widget.motionAsset}_$hashCode'),
      onVisibilityChanged: _onVisibility,
      child: Lottie.asset(
        widget.motionAsset,
        controller: _controller,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        onLoaded: _onLoaded,
        errorBuilder: (_, _, _) => _png(),
      ),
    );
  }
}

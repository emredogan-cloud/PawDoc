import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/motion.dart';
import '../home/home_sections.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import 'health_check_chrome.dart';

/// The analysis wait, as mockup `ai_analysis_loading` composes it: the node
/// rail with the result step revealed, a scanning ring around the pet with a
/// progress read-out, the stage list, the "did you know" card, and the closing
/// reassurance.
///
/// **Safety.** The percentage is *progress through the wait*, not confidence —
/// confidence is never rendered anywhere (CLAUDE.md; `safety_copy_test` scans
/// for it). It is deliberately labelled by the stage list beside it, and it is
/// driven by elapsed time rather than by anything the model reports, so it can
/// never be mistaken for a score.
///
/// The stage list is what the pipeline actually does in order; the copy
/// narrates noticing and organising, never "comparing against conditions".
class HealthCheckLoadingView extends StatefulWidget {
  const HealthCheckLoadingView({
    required this.petSpecies,
    required this.resultReady,
    required this.onCeremonyComplete,
    this.hasPhoto = true,
    super.key,
  });

  final String petSpecies;

  /// True once the backend has answered. The run only *finishes* — reaches
  /// 100 and hands over — when this is true; until then it holds at 99 with
  /// the closing stage still working, rather than showing a completed bar
  /// while the network is still out.
  final bool resultReady;

  /// Fired once, when the run reaches 100.
  final VoidCallback onCeremonyComplete;
  final bool hasPhoto;

  /// How long a full run takes when the backend keeps up. The reference sets
  /// the expectation on screen — "This may take up to 30-45 seconds" — and the
  /// wait is the product telling the owner it is being careful, so a request
  /// that happens to return in two seconds must not undercut it.
  static const ceremony = Duration(milliseconds: 33500);

  /// The six stages, and the percentage each completes at. Percentages, not
  /// seconds: the bar is what the owner is watching, so the ticks have to land
  /// against it rather than against a clock that may be held at 99.
  static const stages = <(IconData, String, int)>[
    (LucideIcons.image, 'Checking image quality', 14),
    (LucideIcons.crosshair, 'Detecting visible areas', 30),
    (LucideIcons.listChecks, 'Matching symptoms', 48),
    (LucideIcons.brain, 'Running AI model', 74),
    (LucideIcons.clipboardList, 'Preparing recommendations', 92),
    (LucideIcons.chartColumn, 'Building report', 100),
  ];

  @override
  State<HealthCheckLoadingView> createState() => _HealthCheckLoadingViewState();
}

class _HealthCheckLoadingViewState extends State<HealthCheckLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _run;
  late final Animation<double> _curve;
  bool _started = false;
  bool _handedOver = false;
  bool _parked = false;

  /// Fast off the mark, deliberately slow through the model stage, then a
  /// short close — the shape of a machine actually working, rather than a
  /// linear bar that reads as a timer.
  static final _schedule = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 22.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12),
    TweenSequenceItem(
        tween: Tween(begin: 22.0, end: 56.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30),
    TweenSequenceItem(
        tween: Tween(begin: 56.0, end: 79.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 26),
    TweenSequenceItem(
        tween: Tween(begin: 79.0, end: 96.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 23),
    TweenSequenceItem(
        tween: Tween(begin: 96.0, end: 100.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 9),
  ]);

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _run = AnimationController(
        vsync: this, duration: HealthCheckLoadingView.ceremony);
    _curve = _schedule.animate(_run);
    _run.addListener(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      // Nobody who has asked the system to stop animating should be held for
      // half a minute. The run is skipped; the reveal waits on the network
      // alone.
      _spin.stop();
      _run.value = 1;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handOver());
    } else {
      _run.forward();
    }
  }

  void _tick() {
    if (!mounted) return;
    // Park one point short of the finish until the answer is in — a bar that
    // sits at 100 while the request is still out is a lie the owner can see.
    // The value has to be pulled back, not just stopped: a single long frame
    // lands it on 1.0 in one step, and stopping there would still read as
    // finished (and hand over).
    if (!widget.resultReady && _run.value > _hold) {
      _run.stop();
      _parked = true;
      _run.value = _hold; // re-enters here once, then falls through
      return;
    }
    setState(() {});
    if (_run.value >= 1.0 && widget.resultReady) _handOver();
  }

  /// Where the bar parks while the network is still out — 99 on screen.
  static const _hold = 0.985;

  @override
  void didUpdateWidget(HealthCheckLoadingView old) {
    super.didUpdateWidget(old);
    if (!widget.resultReady || old.resultReady) return;
    if (reduceMotion(context)) {
      _handOver();
    } else if (_parked) {
      // Only when the bar is actually parked. Keying this off `isAnimating`
      // instead collapsed the whole run into 650ms whenever the backend
      // answered in the same frame the run started — which is every mocked
      // test and most warm requests.
      _parked = false;
      _run.animateTo(1, duration: const Duration(milliseconds: 650));
    }
  }

  void _handOver() {
    if (_handedOver || !mounted) return;
    _handedOver = true;
    widget.onCeremonyComplete();
  }

  @override
  void dispose() {
    _run.removeListener(_tick);
    _run.dispose();
    _spin.dispose();
    super.dispose();
  }

  int get _percent => _curve.value.floor().clamp(1, 100);

  /// True once the bar is parked short of the finish waiting on the network.
  bool get _waitingOnNetwork => _parked && !widget.resultReady;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s24),
      children: [
        const HealthCheckSteps(current: 3, steps: healthCheckSteps5),
        const SizedBox(height: AppSpace.s24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScanRing(
              species: widget.petSpecies,
              percent: _percent,
              spin: _spin,
              animate: !reduceMotion(context),
            ),
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Analyzing with\n'),
                      TextSpan(
                          text: 'PawDoc AI',
                          style: TextStyle(color: t.accent)),
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(LucideIcons.sparkles,
                              size: 17, color: Colors.white),
                        ),
                      ),
                    ]),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                      'Please wait while our AI carefully reviews your pet’s '
                      '${widget.hasPhoto ? 'photo and ' : ''}selected details.',
                      style: const TextStyle(
                          color: Color(0xFF9BA5A0),
                          fontSize: 13.5,
                          height: 1.4)),
                  const SizedBox(height: AppSpace.s12),
                  HomeCard(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Icon(LucideIcons.shieldCheck, size: 18, color: t.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            // Scoped, because this screen is on-camera at the
                            // exact moment a photo of somebody's animal is
                            // being uploaded. "Your data is private, secure
                            // and never shared" was the previous line, and it
                            // is not true of a check: the image goes to object
                            // storage and to a model provider. What IS true is
                            // the transport, the ownership and the absence of
                            // a sale, so that is what it says.
                            const TextSpan(text: 'Encrypted in transit, kept '),
                            TextSpan(
                                text: 'under your account',
                                style: TextStyle(
                                    color: t.accent,
                                    fontWeight: FontWeight.w700)),
                            const TextSpan(text: ', and not sold.'),
                          ]),
                          style: const TextStyle(
                              color: Color(0xFFB8C2BB),
                              fontSize: 12,
                              height: 1.35),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        HomeCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What we’re analyzing',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpace.s12),
              for (var i = 0; i < HealthCheckLoadingView.stages.length; i++)
                _StageRow(
                  icon: HealthCheckLoadingView.stages[i].$1,
                  label: HealthCheckLoadingView.stages[i].$2,
                  state: _percent >= HealthCheckLoadingView.stages[i].$3
                      ? _StageState.done
                      : (i == 0 ||
                              _percent >=
                                  HealthCheckLoadingView.stages[i - 1].$3)
                          ? _StageState.active
                          : _StageState.pending,
                  last: i == HealthCheckLoadingView.stages.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        const _DidYouKnowCard(),
        const SizedBox(height: AppSpace.s20),
        Text(_waitingOnNetwork ? 'Finishing up…' : 'Almost there…',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.accent, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            _waitingOnNetwork
                ? 'Putting the last details together. This one is taking a '
                    'little longer than usual — thank you for waiting.'
                : 'Our AI is working hard to deliver the best insights for '
                    'your furry friend.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF9BA5A0), fontSize: 13.5, height: 1.4)),
        const SizedBox(height: AppSpace.s16),
        HomeCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(LucideIcons.shieldCheck, size: 19, color: t.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'This may take up to '),
                  TextSpan(
                      text: '30–45 seconds',
                      style: TextStyle(
                          color: t.accent, fontWeight: FontWeight.w700)),
                  const TextSpan(text: '. Thank you for your patience!'),
                ]),
                style: const TextStyle(
                    color: Color(0xFFB8C2BB), fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.timer, size: 26, color: t.accent),
          ]),
        ),
      ],
    );
  }
}

/// The pet inside a scanning ring, with the progress read-out beneath it.
class _ScanRing extends StatelessWidget {
  const _ScanRing({
    required this.species,
    required this.percent,
    required this.spin,
    required this.animate,
  });

  final String species;
  final int percent;
  final AnimationController spin;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: 168,
      height: 186,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        t.accent.withValues(alpha: 0.22),
                        Colors.transparent,
                      ], stops: const [0.55, 1.0]),
                    ),
                    child: const SizedBox(width: 168, height: 168),
                  ),
                  ClipOval(
                    child: SizedBox(
                      width: 124,
                      height: 124,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            AppAssets.species(species),
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Color(0xFF141B14)),
                          ),
                          // The scan grid the mockup lays over the subject.
                          CustomPaint(
                              painter: _GridPainter(
                                  t.accent.withValues(alpha: 0.30))),
                        ],
                      ),
                    ),
                  ),
                  // The sweeping arc.
                  animate
                      ? AnimatedBuilder(
                          animation: spin,
                          builder: (_, _) => Transform.rotate(
                            angle: spin.value * 6.2831853,
                            child: CustomPaint(
                              size: const Size(154, 154),
                              painter: _ArcPainter(t.accent),
                            ),
                          ),
                        )
                      : CustomPaint(
                          size: const Size(154, 154),
                          painter: _ArcPainter(t.accent)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Semantics(
              liveRegion: true,
              label: 'Analysis $percent percent through',
              child: ExcludeSemantics(
                child: Text('$percent%',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = tint;
    canvas.drawArc(rect.deflate(3), -1.9, 1.5, false, p);
    canvas.drawArc(rect.deflate(3), 1.4, 1.2, false, p);
    canvas.drawCircle(
      rect.center,
      size.width / 2 - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.tint != tint;
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = tint
      ..strokeWidth = 0.7;
    for (var x = 0.0; x < size.width; x += size.width / 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += size.height / 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.tint != tint;
}

enum _StageState { done, active, pending }

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.icon,
    required this.label,
    required this.state,
    required this.last,
  });

  final IconData icon;
  final String label;
  final _StageState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final done = state == _StageState.done;
    final active = state == _StageState.active;
    final tint = done || active ? t.accent : const Color(0xFF4A534C);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!last)
                  Positioned(
                    top: 20,
                    bottom: 0,
                    child: Container(
                        width: 1, color: t.accent.withValues(alpha: 0.25)),
                  ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10160F),
                    border: Border.all(color: tint.withValues(alpha: 0.45)),
                  ),
                  child: Icon(icon, size: 17, color: tint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 16),
              child: Text(label,
                  style: TextStyle(
                      color: done || active
                          ? Colors.white
                          : const Color(0xFF6C766F),
                      fontSize: 14.5)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Text(
                  done
                      ? 'Completed'
                      : active
                          ? 'In progress'
                          : 'Pending',
                  style: TextStyle(
                      color: done
                          ? const Color(0xFF9BA5A0)
                          : active
                              ? t.accent
                              : const Color(0xFF6C766F),
                      fontSize: 12.5)),
              const SizedBox(width: 7),
              SizedBox(
                width: 20,
                height: 20,
                child: done
                    ? Icon(LucideIcons.circleCheck, size: 19, color: t.accent)
                    : active
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: t.accent),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF3A423B), width: 1.4),
                            ),
                          ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DidYouKnowCard extends StatelessWidget {
  const _DidYouKnowCard();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.10),
              border: Border.all(color: t.accent.withValues(alpha: 0.35)),
            ),
            child: Icon(LucideIcons.lightbulb, size: 20, color: t.accent),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Did you know?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                    'Adding more details after results can help our AI '
                    'provide even more accurate guidance.',
                    style: TextStyle(
                        color: Color(0xFF9BA5A0), fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(LucideIcons.dog, size: 40, color: t.accent),
        ],
      ),
    );
  }
}

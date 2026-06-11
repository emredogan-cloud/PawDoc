import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../experiments/feature_flags.dart';
import '../theme/app_assets.dart';
import 'app_image.dart';
import 'motion.dart';

/// One-shot emotional beats the host screen can request (M2 matrix #10–#13).
enum PalBeat {
  /// One happy beat (activation arrival, NORMAL relief).
  happy,

  /// Restrained attention only — eyes widen, slight lift (MONITOR rule:
  /// ear-perk-only, never a celebration).
  attentive,

  /// "Attentive → relieved": attention, then a happy beat (home hero on
  /// return from a completed check, #11).
  attentiveThenHappy,
}

/// Kill-switch for the whole Paw Pals layer (M2 rollback path). The feature
/// is ON by default — including when the founder has not created the flag in
/// PostHog at all; creating `paw_pals_enabled` = false reverts every surface
/// to the original paw-disc without a release (true kill-switch semantics,
/// device finding D-2).
final pawPalsEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(featureFlagsProvider).isEnabledUnlessKilled('paw_pals_enabled');
});

/// The species rig file, parsed once per session. Any failure (corrupt asset,
/// unsupported runtime) resolves to null and every avatar degrades to its
/// paw-disc fallback — the rig can never break a screen.
Future<RiveFile?> _loadPawPals() async {
  try {
    // Device finding D-1 (M2 device pass): the runtime requires its engine
    // initialized before import on-device; without this the import throws
    // and every avatar silently degraded to the paw-disc. flutter_tester has
    // no rive native lib — initialize() faults outside our zone there, so
    // tests exercise the import-throw degrade path instead (same fallback).
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      // Defensive: never let engine init hold the avatar hostage — on
      // timeout we still attempt the import (the engine may have loaded).
      await RiveFile.initialize()
          .timeout(const Duration(seconds: 4), onTimeout: () {});
    }
    final data = await rootBundle.load(AppMotionAssets.pawPals);
    return RiveFile.import(data);
  } catch (e) {
    debugPrint('PawPals rig unavailable, using paw-disc fallback: $e');
    return null;
  }
}

Future<RiveFile?>? _pawPalsFuture;

/// M2 flagship (`PAWDOC_MOTION_ROADMAP.md` A10): the user's pet as a living
/// avatar — idle breath + per-species blink rhythm, tap → head-tilt, happy /
/// attentive beats, sleepy state. Used on the home hero, onboarding
/// activation, pets list, and pet-form preview. NEVER on EMERGENCY or Delete
/// surfaces (guard-tested).
///
/// Honors every M2 budget rule: reduce-motion renders the static species PNG;
/// offscreen instances pause; the rig file is shared; [seed] de-syncs blink
/// phases so lists never blink in unison.
class LivingPetAvatar extends ConsumerStatefulWidget {
  const LivingPetAvatar({
    required this.species,
    required this.size,
    this.sleepy = false,
    this.mountBeat,
    this.beatKey,
    this.seed,
    super.key,
  });

  /// One of kSpecies; unknown values fall back to 'other'.
  final String species;
  final double size;

  /// Drives the rig's `sleepy` bool input (quiet-hours surfaces).
  final bool sleepy;

  /// Beat fired once shortly after mount (activation arrival / result relief).
  final PalBeat? mountBeat;

  /// When this value CHANGES (non-null → different non-null), the avatar does
  /// the attentive→relieved beat — the home hero passes the last-check
  /// timestamp, so a completed analysis greets the owner on return (#11).
  final Object? beatKey;

  /// Stable per-pet seed (pet id) for blink-phase desync in lists.
  final String? seed;

  @override
  ConsumerState<LivingPetAvatar> createState() => _LivingPetAvatarState();
}

class _LivingPetAvatarState extends ConsumerState<LivingPetAvatar> {
  Artboard? _artboard;
  StateMachineController? _controller;
  SMITrigger? _tap;
  SMITrigger? _happy;
  SMITrigger? _attentive;
  SMIBool? _sleepy;
  bool _rigFailed = false;
  bool _visible = true;
  bool _rigRequested = false;

  Future<void> _initRig() async {
    _pawPalsFuture ??= _loadPawPals();
    final file = await _pawPalsFuture!;
    if (!mounted) return;
    if (file == null) {
      setState(() => _rigFailed = true);
      return;
    }
    try {
      final name =
          kSpeciesRigs.contains(widget.species) ? widget.species : 'other';
      final artboard =
          file.artboards.firstWhere((a) => a.name == name).instance();
      final controller = StateMachineController.fromArtboard(artboard, 'pal');
      if (controller == null) throw StateError('pal machine missing');
      artboard.addController(controller);
      _tap = controller.findSMI('tap') as SMITrigger?;
      _happy = controller.findSMI('happy') as SMITrigger?;
      _attentive = controller.findSMI('attentive') as SMITrigger?;
      _sleepy = controller.findInput<bool>('sleepy') as SMIBool?;
      _sleepy?.value = widget.sleepy;

      // Blink-phase desync: advance by a seeded offset so a list of pets
      // never blinks in unison (M2 acceptance).
      final rng = Random(widget.seed?.hashCode ?? identityHashCode(this));
      artboard.advance(rng.nextDouble() * 5.0);

      setState(() {
        _artboard = artboard;
        _controller = controller;
      });
      _scheduleMountBeat();
    } catch (e, st) {
      debugPrint('PawPals: rig stage failed for ${widget.species}: $e\n$st');
      if (mounted) setState(() => _rigFailed = true);
    }
  }

  void _scheduleMountBeat() {
    final beat = widget.mountBeat;
    if (beat == null) return;
    // After the entrance settles; never delays anything tappable.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _fire(beat);
    });
  }

  void _fire(PalBeat beat) {
    switch (beat) {
      case PalBeat.happy:
        _happy?.fire();
      case PalBeat.attentive:
        _attentive?.fire();
      case PalBeat.attentiveThenHappy:
        _attentive?.fire();
        Future<void>.delayed(const Duration(milliseconds: 550), () {
          if (mounted) _happy?.fire();
        });
    }
  }

  @override
  void didUpdateWidget(LivingPetAvatar old) {
    super.didUpdateWidget(old);
    if (old.sleepy != widget.sleepy) _sleepy?.value = widget.sleepy;
    // The relieved beat fires only on a real change between two known
    // checks — never on first data arrival (no fabricated celebrations).
    if (widget.beatKey != null &&
        old.beatKey != null &&
        widget.beatKey != old.beatKey) {
      _fire(PalBeat.attentiveThenHappy);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _fallbackDisc(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: scheme.primaryContainer,
      child: Icon(Icons.pets_rounded,
          size: widget.size / 2, color: scheme.primary),
    );
  }

  Widget _staticPng(BuildContext context) {
    return AppImage(
      AppAssets.species(
          kSpeciesRigs.contains(widget.species) ? widget.species : 'other'),
      width: widget.size,
      height: widget.size,
      fallback: _fallbackDisc(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reduce-motion: the static species PNG, no rig at all (M2 acceptance) —
    // the runtime is never even loaded for reduce-motion users.
    if (reduceMotion(context)) return _staticPng(context);

    // Lazy rig load on the first motion-enabled build.
    if (!_rigRequested) {
      _rigRequested = true;
      _initRig();
    }

    // Flag-gated rollout: disabled (or flag still loading on first frame)
    // keeps the original paw-disc — the M2 rollback path.
    final enabled = ref.watch(pawPalsEnabledProvider).maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );
    if (!enabled || _rigFailed) return _fallbackDisc(context);
    if (_artboard == null) return _fallbackDisc(context);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: VisibilityDetector(
        key: ValueKey('pal_${widget.seed ?? widget.species}_$hashCode'),
        onVisibilityChanged: (info) {
          final visible = info.visibleFraction >= 0.1;
          if (visible == _visible || !mounted) return;
          _visible = visible;
          _controller?.isActive = visible; // pause offscreen (budget rule)
        },
        child: GestureDetector(
          // Tap-tilt is optional/decorative (≤400ms); excluded from semantics —
          // the pet's name is always adjacent text.
          onTap: () => _tap?.fire(),
          child: ExcludeSemantics(
            child: Rive(artboard: _artboard!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// Species with a dedicated artboard in paw_pals_v1.riv.
const kSpeciesRigs = {
  'dog', 'cat', 'rabbit', 'guinea_pig', 'bird', 'reptile', 'other',
};

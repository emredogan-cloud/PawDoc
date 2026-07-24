import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/motion.dart';
import '../pets/active_pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'walk_scorer.dart';
import 'walks_controller.dart';
import 'walks_screen.dart';

/// Home card for Smart Walks (Next Evolution Phase 5): a contextual
/// pre-prompt before any permission dialog, then a live weather-aware
/// suggestion with the walk-score ring. All computation is on-device.
class WalkCard extends ConsumerWidget {
  const WalkCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walksControllerProvider);
    final pet = ref.watch(activePetProvider);
    final species = pet?.species ?? 'dog';

    return switch (state) {
      WalksInitial() => PawCard(
          key: const Key('walk_card_initial'),
          child: Row(
            children: [
              const Icon(Icons.directions_walk_rounded,
                  color: PawPalette.mint, size: 32),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart walks',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.ink50)),
                    const SizedBox(height: 2),
                    Text(
                      'Weather-aware walk times${pet == null ? '' : ' for ${pet.name}'}. '
                      'Uses your location on this device only — never stored '
                      'on PawDoc servers.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.ink300),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              FilledButton(
                key: const Key('walk_card_enable'),
                onPressed: () => ref
                    .read(walksControllerProvider.notifier)
                    .enable(species: species),
                child: const Text('Show'),
              ),
            ],
          ),
        ),
      WalksLoading() => const SkeletonCard(height: 84),
      WalksPermissionNeeded(:final deniedForever, :final serviceOff) => PawCard(
          key: const Key('walk_card_permission'),
          child: Row(
            children: [
              const Icon(Icons.location_off_rounded,
                  color: AppColors.ink300, size: 28),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  serviceOff
                      ? 'Turn on location services to see walk weather.'
                      : 'Walk weather needs location while you use the app.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.ink300),
                ),
              ),
              TextButton(
                key: const Key('walk_card_permission_action'),
                onPressed: () async {
                  if (deniedForever) {
                    await Geolocator.openAppSettings();
                  } else if (serviceOff) {
                    await Geolocator.openLocationSettings();
                  } else {
                    await ref
                        .read(walksControllerProvider.notifier)
                        .enable(species: species);
                  }
                },
                child: Text(deniedForever || serviceOff ? 'Settings' : 'Allow'),
              ),
            ],
          ),
        ),
      WalksError() => PawCard(
          key: const Key('walk_card_error'),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: AppColors.ink300, size: 28),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text('Walk weather is unavailable right now.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.ink300)),
              ),
              TextButton(
                onPressed: () => ref
                    .read(walksControllerProvider.notifier)
                    .refresh(species: species),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      WalksReady(:final now, :final todayWindows, :final hours) => PawCard(
          key: const Key('walk_card_ready'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WalksScreen()),
          ),
          child: Row(
            children: [
              WalkScoreRing(score: now.score, size: 56),
              const SizedBox(width: AppSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(now.headline,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.ink50)),
                    const SizedBox(height: 2),
                    Text(
                      walkSuggestionCopy(
                        now: now,
                        windows: todayWindows,
                        petName: pet?.name,
                        species: species,
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.ink300),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      '${hours.first.tempC.round()}°C · '
                      '${hours.first.precipMm > 0 ? 'rain possible' : 'dry'} · '
                      'wind ${hours.first.windMs.round()} m/s',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: PawPalette.mint),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
            ],
          ),
        ),
    };
  }
}

/// The 0–100 walk-comfort ring (safety-neutral colors: mint for good, ink
/// for poor — never the triage reds/ambers, which stay reserved for health).
class WalkScoreRing extends StatelessWidget {
  const WalkScoreRing({super.key, required this.score, this.size = 56});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: score / 100,
          color: score >= 70
              ? PawPalette.mint
              : score >= 45
                  ? PawPalette.teal
                  : AppColors.ink300,
          track: Colors.white.withValues(alpha: 0.10),
        ),
        child: Center(
          child: Text(
            '$score',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.ink50, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track});

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = track;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

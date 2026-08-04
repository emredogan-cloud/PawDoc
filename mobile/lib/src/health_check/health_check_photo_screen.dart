import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../capture/camera_screen.dart';
import '../capture/image_compressor.dart';
import '../capture/upload_service.dart';
import '../home/home_sections.dart';
import '../pets/pet.dart';
import '../pets/pet_photo_service.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'health_check_chrome.dart';
import 'health_check_symptoms_screen.dart';

/// Step 2 of the AI Health Check (mockup `photo_analysis_upload`).
///
/// The photo is optional: text checks are free and unmetered (quota v3), and
/// gating a health question behind a camera would meter safety. Continue is
/// live either way, which is also why the well says "Add clear photos" rather
/// than demanding one.
class HealthCheckPhotoScreen extends ConsumerStatefulWidget {
  const HealthCheckPhotoScreen({
    required this.pet,
    required this.isPremium,
    super.key,
  });

  final Pet pet;
  final bool isPremium;

  @override
  ConsumerState<HealthCheckPhotoScreen> createState() =>
      _HealthCheckPhotoScreenState();
}

class _HealthCheckPhotoScreenState
    extends ConsumerState<HealthCheckPhotoScreen> {
  /// The uploaded object key, once the capture flow has stored one.
  String? _storageKey;
  Uint8List? _preview;
  bool _busy = false;

  Future<void> _takePhoto() async {
    final key = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (key != null && mounted) setState(() => _storageKey = key);
  }

  Future<void> _fromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final raw = await ref.read(petPhotoServiceProvider).pick(ImageSource.gallery);
      if (raw == null || !mounted) return;
      setState(() => _preview = raw);
      // Same pipeline the camera runs — EXIF/GPS stripped, downscaled and
      // re-encoded off the UI thread, then uploaded through the presigned PUT.
      // A gallery pick must not be a way round any of that.
      final prepared = await compute(compressForUpload, raw);
      final upload =
          await ref.read(uploadServiceProvider).uploadJpeg(prepared.bytes);
      if (mounted) setState(() => _storageKey = upload.storageKey);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t open that photo. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HealthCheckScaffold(
      body: [
        const HealthCheckSteps(current: 1, steps: healthCheckSteps4),
        const SizedBox(height: AppSpace.s24),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Let’s take a '),
            TextSpan(text: 'closer look', style: TextStyle(color: t.accent)),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 6),
                child:
                    Icon(LucideIcons.sparkles, size: 20, color: Colors.white),
              ),
            ),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: AppSpace.s12),
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Add clear photos of the area you’re concerned about. '
                    'Good photos help AI give '),
            TextSpan(
                text: 'more accurate insights',
                style: TextStyle(color: t.accent, fontWeight: FontWeight.w600)),
            const TextSpan(text: '.'),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF9BA5A0), fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: AppSpace.s16),
        HomeCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.accent.withValues(alpha: 0.10),
                    border: Border.all(color: t.accent.withValues(alpha: 0.35)),
                  ),
                  child:
                      Icon(LucideIcons.lightbulb, size: 16, color: t.accent),
                ),
                const SizedBox(width: 9),
                const Text('Photo tips',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: AppSpace.s16),
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Tip(
                        icon: LucideIcons.sun,
                        title: 'Good lighting',
                        caption: 'Use natural light when possible.'),
                    _TipDivider(),
                    _Tip(
                        icon: LucideIcons.scanLine,
                        title: 'Clear & close',
                        caption: 'Take a clear photo of the area.'),
                    _TipDivider(),
                    _Tip(
                        icon: LucideIcons.hand,
                        title: 'Steady hand',
                        caption: 'Keep your phone steady.'),
                    _TipDivider(),
                    _Tip(
                        icon: LucideIcons.images,
                        title: 'Multiple angles',
                        caption: 'Different angles help a lot.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        _CaptureWell(
          hasPhoto: _storageKey != null,
          preview: _preview,
          busy: _busy,
          onCamera: _takePhoto,
          onGallery: _fromGallery,
        ),
        const SizedBox(height: AppSpace.s12),
        const _WhatCanIPhotoCard(),
        const SizedBox(height: AppSpace.s12),
        HomeCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Icon(LucideIcons.shieldCheck, size: 19, color: t.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Your photos are '),
                  TextSpan(
                      text: 'private',
                      style: TextStyle(
                          color: t.accent, fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' and only used for this analysis.'),
                ]),
                style:
                    const TextStyle(color: Color(0xFFB8C2BB), fontSize: 13),
              ),
            ),
            Icon(LucideIcons.lock, size: 17, color: t.accent),
          ]),
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PawPrimaryButton(
            key: const Key('health_check_photo_continue'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => HealthCheckSymptomsScreen(
                pet: widget.pet,
                isPremium: widget.isPremium,
                imageStorageKey: _storageKey,
              ),
            )),
            child: const Text('Continue'),
          ),
          const SizedBox(height: AppSpace.s12),
          const HealthCheckDisclaimer(),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.caption});

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 26, color: t.accent),
          const SizedBox(height: 9),
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
                  color: Color(0xFF8A948D), fontSize: 10, height: 1.25)),
        ],
      ),
    );
  }
}

class _TipDivider extends StatelessWidget {
  const _TipDivider();

  @override
  Widget build(BuildContext context) => Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: const Color(0x14FFFFFF));
}

/// The dashed capture well: paw watermark, glowing camera ring, and the
/// gallery alternative under a rule.
class _CaptureWell extends StatelessWidget {
  const _CaptureWell({
    required this.hasPhoto,
    required this.preview,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool hasPhoto;
  final Uint8List? preview;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return CustomPaint(
      painter: _DashedWellPainter(t.accent.withValues(alpha: 0.55)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(LucideIcons.pawPrint,
                    size: 128, color: Colors.white.withValues(alpha: 0.06)),
                Positioned(
                    left: 34,
                    top: 4,
                    child: Icon(LucideIcons.sparkles,
                        size: 16, color: t.accent)),
                Positioned(
                    right: 28,
                    top: 18,
                    child: Icon(LucideIcons.sparkles,
                        size: 20, color: t.accent)),
                Positioned(
                    right: 40,
                    bottom: 4,
                    child: Icon(LucideIcons.sparkles,
                        size: 13, color: t.accent)),
                Semantics(
                  button: true,
                  label: hasPhoto ? 'Retake photo' : 'Take a photo',
                  child: ExcludeSemantics(
                    child: InkWell(
                      key: const Key('health_check_take_photo'),
                      onTap: onCamera,
                      customBorder: const CircleBorder(),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: t.accent, width: 2.4),
                              boxShadow: [
                                BoxShadow(
                                    color: t.accent.withValues(alpha: 0.45),
                                    blurRadius: 26,
                                    spreadRadius: -4)
                              ],
                            ),
                            child: preview == null
                                ? const Icon(LucideIcons.camera,
                                    size: 36, color: Colors.white)
                                : ClipOval(
                                    child: Image.memory(preview!,
                                        fit: BoxFit.cover)),
                          ),
                          Positioned(
                            right: -2,
                            bottom: 4,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: t.accent),
                              child: Icon(
                                  hasPhoto
                                      ? LucideIcons.check
                                      : LucideIcons.plus,
                                  size: 17,
                                  color: const Color(0xFF06140A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            Text(hasPhoto ? 'Photo added' : 'Take a Photo',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: hasPhoto ? 'Tap the ' : 'Tap the '),
                TextSpan(
                    text: 'camera',
                    style:
                        TextStyle(color: t.accent, fontWeight: FontWeight.w600)),
                TextSpan(
                    text: hasPhoto
                        ? ' to replace it'
                        : ' to take a new photo'),
              ]),
              style: const TextStyle(color: Color(0xFF8A948D), fontSize: 12.5),
            ),
            const SizedBox(height: AppSpace.s16),
            Row(children: [
              const Expanded(child: Divider(color: Color(0x1AFFFFFF))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13)),
              ),
              const Expanded(child: Divider(color: Color(0x1AFFFFFF))),
            ]),
            const SizedBox(height: AppSpace.s12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('health_check_gallery'),
                onPressed: busy ? null : onGallery,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(LucideIcons.image, size: 18, color: t.accent),
                label: Text('Choose from Gallery',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedWellPainter extends CustomPainter {
  const _DashedWellPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(20));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF080C08));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = color;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), stroke);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedWellPainter old) => old.color != color;
}

/// "What can I photo?" — the mockup's four sample crops.
class _WhatCanIPhotoCard extends StatelessWidget {
  const _WhatCanIPhotoCard();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.10),
              border: Border.all(color: t.accent.withValues(alpha: 0.35)),
            ),
            child: Icon(LucideIcons.scanSearch, size: 16, color: t.accent),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What can I photo?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text(
                    'Any area related to your pet’s health concern.',
                    style: TextStyle(
                        color: Color(0xFF8A948D), fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (ok, dim) in const [
                (true, 1.0),
                (true, 1.0),
                (false, 0.5),
                (false, 0.3),
              ])
                Container(
                  width: 34,
                  height: 40,
                  margin: const EdgeInsets.only(left: 3),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Opacity(
                            opacity: dim,
                            child: Image.asset(AppAssets.species('dog'),
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFF141B14))),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ok ? t.accent : const Color(0xFF3A423B),
                          ),
                          child: Icon(
                              ok
                                  ? LucideIcons.check
                                  : LucideIcons.ellipsis,
                              size: 10,
                              color:
                                  ok ? const Color(0xFF06140A) : Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

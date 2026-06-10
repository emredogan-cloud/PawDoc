import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../theme/design_tokens.dart';
import 'image_compressor.dart';
import 'image_quality.dart';
import 'upload_service.dart';

/// In-app camera: live preview + a real-time lighting hint (from the image
/// stream's luma plane) + capture -> compress (<2MB, EXIF stripped) -> upload
/// via presigned URL. Pops the R2 storage key. Device-only; no AI here.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  String? _error;
  String _liveHint = '';
  bool _busy = false;
  int _lastSampleMs = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      await controller.startImageStream(_onFrame);
      if (!mounted) return;
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      setState(() => _error = e.code == 'CameraAccessDenied'
          ? 'Camera permission is needed to take a photo. Enable it in Settings.'
          : 'Could not open the camera (${e.code}).');
    }
  }

  // Real-time lighting hint from the Y (luma) plane — cheap, no full decode.
  void _onFrame(CameraImage image) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSampleMs < 500) return; // throttle to ~2/sec
    _lastSampleMs = now;
    final plane = image.planes.first.bytes;
    if (plane.isEmpty) return;
    var sum = 0;
    final step = (plane.length ~/ 2048).clamp(1, plane.length);
    var n = 0;
    for (var i = 0; i < plane.length; i += step) {
      sum += plane[i];
      n++;
    }
    final mean = n == 0 ? 0 : sum / n / 255.0;
    final hint = mean < 0.22
        ? 'Too dark — find better lighting.'
        : (mean > 0.88 ? 'Too bright — reduce glare.' : '');
    if (hint != _liveHint && mounted) setState(() => _liveHint = hint);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      await controller.stopImageStream();
      final shot = await controller.takePicture();
      final raw = await shot.readAsBytes();

      // Compress + strip EXIF off the UI thread.
      final result = await compute(_compress, raw);

      // Blur/lighting check on the captured frame.
      final decoded = img.decodeJpg(result.bytes);
      if (decoded != null) {
        final report = assessQuality(decoded);
        if (report.hints.isNotEmpty && mounted) {
          final useAnyway = await _qualityDialog(report.hints);
          if (useAnyway != true) {
            await controller.startImageStream(_onFrame);
            if (mounted) setState(() => _busy = false);
            return;
          }
        }
      }

      final upload = await ref.read(uploadServiceProvider).uploadJpeg(result.bytes);
      if (mounted) Navigator.of(context).pop(upload.storageKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
        setState(() => _busy = false);
      }
    }
  }

  Future<bool?> _qualityDialog(List<String> hints) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Photo quality'),
          content: Text('${hints.join('\n')}\n\nUse this photo anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retake')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use anyway')),
          ],
        ),
      );

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(_error!, textAlign: TextAlign.center)),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Take a photo')),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(child: CameraPreview(controller)),
          if (_liveHint.isNotEmpty)
            Positioned(
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius: AppRadius.brMd,
                ),
                child: Text(_liveHint, style: const TextStyle(color: Colors.white)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: FloatingActionButton.large(
              onPressed: _busy ? null : _capture,
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt),
            ),
          ),
        ],
      ),
    );
  }
}

// Top-level so it can run in a background isolate via compute().
CompressionResult _compress(Uint8List bytes) => compressForUpload(bytes);

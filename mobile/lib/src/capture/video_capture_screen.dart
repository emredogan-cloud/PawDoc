import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/design_tokens.dart';
import 'keyframe_extractor.dart';
import 'upload_service.dart';

/// In-app video capture (≤ 30s) → client-side keyframe extraction (native, no
/// ffmpeg) → upload the frames via presigned URLs. Pops the list of R2 frame
/// keys (List&lt;String&gt;). Device-only; no AI here. Keyframe extraction + upload
/// run in async/await off the UI build, so the thread is never blocked.
class VideoCaptureScreen extends ConsumerStatefulWidget {
  const VideoCaptureScreen({super.key});

  @override
  ConsumerState<VideoCaptureScreen> createState() => _VideoCaptureScreenState();
}

class _VideoCaptureScreenState extends ConsumerState<VideoCaptureScreen> {
  CameraController? _controller;
  String? _error;
  bool _recording = false;
  bool _processing = false;
  int _elapsed = 0;
  Timer? _timer;
  DateTime? _startedAt;

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
      if (!mounted) return;
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      setState(() => _error = e.code == 'CameraAccessDenied'
          ? 'Camera permission is needed to record a video. Enable it in Settings.'
          : 'Could not open the camera (${e.code}).');
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || _recording) return;
    try {
      await controller.startVideoRecording();
      _startedAt = DateTime.now();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _elapsed = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _elapsed = t.tick);
        if (t.tick >= kMaxVideoSeconds) unawaited(_stopRecording());
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not start recording: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_recording) return;
    _timer?.cancel();
    setState(() {
      _recording = false;
      _processing = true;
    });
    try {
      final file = await controller.stopVideoRecording();
      final durationMs =
          DateTime.now().difference(_startedAt ?? DateTime.now()).inMilliseconds;
      // Native keyframe extraction (off the UI thread via the platform channel).
      final frames = await extractKeyframes(file.path, durationMs);
      if (frames.isEmpty) throw Exception('No keyframes could be extracted');
      final keys = await ref.read(uploadServiceProvider).uploadFrames(frames);
      if (mounted) Navigator.of(context).pop(keys);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not process the video: $e')));
        setState(() => _processing = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record a video')),
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
      appBar: AppBar(title: const Text('Record a video')),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(child: CameraPreview(controller)),
          Positioned(
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: AppRadius.brMd,
              ),
              child: Text(
                _recording
                    ? 'Recording  $_elapsed s / $kMaxVideoSeconds s'
                    : 'Tap to record (max $kMaxVideoSeconds s)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          if (_processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text('Processing video…', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: FloatingActionButton.large(
              key: const Key('video_record_button'),
              backgroundColor: _recording ? Colors.red : null,
              onPressed: _processing ? null : (_recording ? _stopRecording : _startRecording),
              child: Icon(_recording ? Icons.stop : Icons.videocam),
            ),
          ),
        ],
      ),
    );
  }
}

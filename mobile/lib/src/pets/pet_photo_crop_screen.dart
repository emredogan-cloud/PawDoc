import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../capture/image_compressor.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// Frame the pet inside the circle that every avatar surface will show.
///
/// Pure Flutter — pan and zoom an image behind a fixed square viewport and
/// return where the user landed as fractions of the source. No native cropper
/// plugin: one more Android activity to register (and to keep working across
/// OEM skins) is not worth it for a square crop, and this keeps the crop maths
/// unit-testable.
class PetPhotoCropScreen extends StatefulWidget {
  const PetPhotoCropScreen({super.key, required this.bytes, this.petName});

  final Uint8List bytes;
  final String? petName;

  @override
  State<PetPhotoCropScreen> createState() => _PetPhotoCropScreenState();
}

class _PetPhotoCropScreenState extends State<PetPhotoCropScreen> {
  final _controller = TransformationController();
  Size? _imageSize;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Translate the viewer's transform into a source-relative square.
  ///
  /// The viewport is square and shows the image scaled to *cover* it, so the
  /// visible region maps back to the source by undoing the fit scale and the
  /// user's pan/zoom.
  SquareCrop _cropFor(double viewport) {
    final size = _imageSize;
    if (size == null || size.width <= 0 || size.height <= 0) {
      return SquareCrop.centre;
    }
    final matrix = _controller.value;
    final scale = matrix.getMaxScaleOnAxis();
    if (scale <= 0) return SquareCrop.centre;

    // BoxFit.cover scale from source pixels to viewport pixels.
    final cover = viewport / (size.width < size.height ? size.width : size.height);
    final effective = cover * scale;

    // Translation is in viewport pixels and negative as content moves left/up.
    final dx = -matrix.getTranslation().x / effective;
    final dy = -matrix.getTranslation().y / effective;

    // The image is centred in the viewport before any pan.
    final shownW = viewport / effective;
    final shownH = viewport / effective;
    final baseX = (size.width - shownW) / 2;
    final baseY = (size.height - shownH) / 2;

    final shortEdge = size.width < size.height ? size.width : size.height;
    return SquareCrop(
      left: ((baseX + dx) / size.width).clamp(0.0, 1.0),
      top: ((baseY + dy) / size.height).clamp(0.0, 1.0),
      size: (shownW / shortEdge).clamp(0.05, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.ink50),
          title: Text(
            widget.petName == null ? 'Frame the photo' : 'Frame ${widget.petName}',
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink50),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.maxWidth - AppSpace.s24 * 2;
            return Column(
              children: [
                const SizedBox(height: AppSpace.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                  child: Text(
                    'Pinch to zoom, drag to position. This is the circle you\'ll '
                    'see across the app.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.ink300),
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                SizedBox(
                  width: viewport,
                  height: viewport,
                  child: ClipOval(
                    child: InteractiveViewer(
                      key: const Key('pet_photo_crop_viewer'),
                      transformationController: _controller,
                      minScale: 1,
                      maxScale: 5,
                      clipBehavior: Clip.none,
                      child: Image.memory(
                        widget.bytes,
                        fit: BoxFit.cover,
                        width: viewport,
                        height: viewport,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: PawPalette.bgBottom,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: AppColors.ink300),
                          ),
                        ),
                        frameBuilder: (context, child, frame, _) {
                          if (frame != null && _imageSize == null) {
                            // Resolve the intrinsic size once the frame exists.
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => _measure());
                          }
                          return child;
                        },
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.s24, 0, AppSpace.s24, AppSpace.s24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: PawPrimaryButton(
                          key: const Key('pet_photo_crop_confirm'),
                          icon: Icons.check_rounded,
                          onPressed: () =>
                              Navigator.of(context).pop(_cropFor(viewport)),
                          child: const Text('Use this photo'),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s8),
                      TextButton(
                        key: const Key('pet_photo_crop_cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Choose a different one'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _measure() {
    final stream = MemoryImage(widget.bytes).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() => _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ));
      }
      stream.removeListener(listener);
    }, onError: (_, _) => stream.removeListener(listener));
    stream.addListener(listener);
  }
}

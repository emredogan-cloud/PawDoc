import 'package:image/image.dart' as img;

/// Real-time capture quality assessment that drives the camera overlay hints
/// (blur / lighting). Pure functions over a decoded frame -> unit-testable.
class QualityReport {
  const QualityReport({
    required this.brightness,
    required this.sharpness,
    required this.hints,
  });

  /// Mean luma in 0..1.
  final double brightness;

  /// Relative sharpness (variance of a Laplacian); higher = sharper.
  final double sharpness;

  /// Human-readable hints; empty when the frame looks good.
  final List<String> hints;

  bool get isAcceptable => hints.isEmpty;
}

const double _darkThreshold = 0.22;
const double _brightThreshold = 0.88;
const double _blurThreshold = 6.0;

double _luma(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

/// Mean brightness (0..1), sampled on a grid for speed.
double meanBrightness(img.Image image) {
  final stepX = (image.width ~/ 64).clamp(1, image.width);
  final stepY = (image.height ~/ 64).clamp(1, image.height);
  double total = 0;
  int count = 0;
  for (int y = 0; y < image.height; y += stepY) {
    for (int x = 0; x < image.width; x += stepX) {
      total += _luma(image.getPixel(x, y));
      count++;
    }
  }
  return count == 0 ? 0 : (total / count) / 255.0;
}

/// Variance of a 4-neighbour Laplacian over a sampled luma grid. Flat/blurry
/// frames -> low variance; sharp, detailed frames -> high variance.
double sharpnessScore(img.Image image) {
  final step = (image.width ~/ 96).clamp(1, image.width);
  final laplacians = <double>[];
  for (int y = step; y < image.height - step; y += step) {
    for (int x = step; x < image.width - step; x += step) {
      final c = _luma(image.getPixel(x, y));
      final lap = _luma(image.getPixel(x - step, y)) +
          _luma(image.getPixel(x + step, y)) +
          _luma(image.getPixel(x, y - step)) +
          _luma(image.getPixel(x, y + step)) -
          4 * c;
      laplacians.add(lap);
    }
  }
  if (laplacians.isEmpty) return 0;
  final mean = laplacians.reduce((a, b) => a + b) / laplacians.length;
  final variance =
      laplacians.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) /
          laplacians.length;
  return variance;
}

QualityReport assessQuality(img.Image image) {
  final brightness = meanBrightness(image);
  final sharpness = sharpnessScore(image);
  final hints = <String>[];
  if (brightness < _darkThreshold) {
    hints.add('Too dark — find better lighting.');
  } else if (brightness > _brightThreshold) {
    hints.add('Too bright — reduce glare.');
  }
  if (sharpness < _blurThreshold) {
    hints.add('Looks blurry — hold steady and tap to focus.');
  }
  return QualityReport(brightness: brightness, sharpness: sharpness, hints: hints);
}

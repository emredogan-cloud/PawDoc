import 'package:flutter/material.dart';

/// Renders an asset image with a graceful, themed fallback.
///
/// A missing asset (e.g. an illustration not yet generated) must never crash or
/// show a broken-image box — `errorBuilder` swaps in [fallback] instead. This is
/// what lets the Phase A design-token work merge before the art is produced
/// (PAWDOC_UI_UX_MASTER_ROADMAP.md §7.4 / §7.5).
class AppImage extends StatelessWidget {
  const AppImage(
    this.asset, {
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    super.key,
  });

  final String asset;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Decorative illustrations should pass null (excluded from semantics); set a
  /// label only when the image conveys information not present in nearby text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

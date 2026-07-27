import 'package:flutter/material.dart';

import '../core/app_image.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// The Assistant's face, in one place.
///
/// Every surface that shows the Assistant renders this widget, so the mask,
/// ring, glow and padding can never drift between the greeting hero and a chat
/// bubble — only [size] changes. Falls back to the previous paw mark if the
/// asset is missing, so a bad build degrades instead of showing a broken box.
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 88, this.glow = true});

  /// Outer diameter in logical pixels.
  final double size;

  /// The soft brand halo. On at hero scale, off in dense lists where a glow per
  /// row would turn into visual noise.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [PawPalette.mint, PawPalette.teal],
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: PawPalette.glow.withValues(alpha: 0.35),
                  blurRadius: size * 0.36,
                ),
              ]
            : null,
      ),
      // The gradient reads as a hairline ring around the portrait.
      padding: EdgeInsets.all(size * 0.03),
      child: ClipOval(
        child: AppImage(
          AppAssets.assistantAvatar,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fallback: Container(
            color: PawPalette.bgBottom,
            alignment: Alignment.center,
            child: Icon(
              Icons.pets_rounded,
              size: size * 0.45,
              color: AppColors.ink50,
            ),
          ),
        ),
      ),
    );
  }
}

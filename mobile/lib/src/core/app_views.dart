import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import 'app_motion_asset.dart';

/// Shared, polished loading / error / empty states.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[const SizedBox(height: 16), Text(label!)],
        ],
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // M4 (matrix #20): the calm "nap" loop replaces the bare error
            // icon — muted breath, never playful; static PNG under
            // reduce-motion; icon fallback if the art is missing.
            AppMotionAsset(
              AppMotionAssets.errorNapLoop,
              fallbackAsset: AppAssets.sysError,
              height: 120,
              fallback: Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(message, textAlign: TextAlign.center)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'media_url_cache.dart';

/// Displays a memory photo addressed by its R2 storage key: resolves a signed
/// GET URL (TTL-cached) and renders it via [CachedNetworkImage] with the
/// STORAGE KEY as the cache key, so URL rotation never re-downloads bytes.
/// Skeleton while resolving/loading; calm fallback tile when unavailable.
class MemoryPhoto extends ConsumerWidget {
  const MemoryPhoto({
    super.key,
    required this.storageKey,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String storageKey;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(mediaUrlServiceProvider);
    final image = FutureBuilder<String?>(
      future: service.resolveOne(storageKey),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Skeleton(height: double.infinity, width: double.infinity);
        }
        final url = snap.data;
        if (url == null) return const _PhotoFallback();
        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: storageKey,
          fit: fit,
          fadeInDuration: reduceMotion(context) ? Duration.zero : AppMotion.standard,
          placeholder: (_, _) =>
              const Skeleton(height: double.infinity, width: double.infinity),
          errorWidget: (_, _, _) => const _PhotoFallback(),
        );
      },
    );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PawPalette.leaf.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Icon(
        Icons.photo_outlined,
        size: 32,
        color: PawPalette.mint.withValues(alpha: 0.6),
      ),
    );
  }
}

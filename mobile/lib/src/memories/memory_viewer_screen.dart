import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../pets/pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'memories_repository.dart';
import 'memory.dart';
import 'memory_editor_sheet.dart';
import 'memory_photo.dart';

/// Full-screen memory view: photo (pinch-zoomable), title/date/note, and
/// edit / share / delete actions. Pops `true` when the memory changed so the
/// gallery refreshes.
class MemoryViewerScreen extends ConsumerStatefulWidget {
  const MemoryViewerScreen({
    super.key,
    required this.memory,
    required this.pet,
  });

  final Memory memory;
  final Pet pet;

  @override
  ConsumerState<MemoryViewerScreen> createState() => _MemoryViewerScreenState();
}

class _MemoryViewerScreenState extends ConsumerState<MemoryViewerScreen> {
  late Memory _memory = widget.memory;
  bool _changed = false;

  Future<void> _edit() async {
    final saved = await showMemoryEditorSheet(
      context,
      pet: widget.pet,
      existing: _memory,
    );
    if (saved == true && mounted) {
      _changed = true;
      // Re-read the fresh row so the viewer reflects the edit immediately.
      final list = await ref
          .read(memoriesRepositoryProvider)
          .listForPet(widget.pet.id!);
      final updated = list.where((m) => m.id == _memory.id).toList();
      if (mounted && updated.isNotEmpty) setState(() => _memory = updated.first);
    }
  }

  Future<void> _share() async {
    final text = '${_memory.title} — a memory with ${widget.pet.name} 🐾';
    try {
      // Share the already-downloaded bytes when they are in the image cache
      // (keyed by storage key); fall back to text-only.
      final cached = await DefaultCacheManager()
          .getFileFromCache(_memory.storageKey);
      if (cached != null) {
        await SharePlus.instance.share(ShareParams(
          text: text,
          files: [XFile(cached.file.path, mimeType: 'image/jpeg')],
        ));
        return;
      }
    } catch (_) {
      // Fall through to text-only.
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text(
            'The photo and note will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('memory_delete_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(memoriesRepositoryProvider).delete(_memory);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete the memory. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: PawScaffold(
        showDecor: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              key: const Key('memory_share_button'),
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _share,
            ),
            IconButton(
              key: const Key('memory_edit_button'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded),
              onPressed: _edit,
            ),
            IconButton(
              key: const Key('memory_delete_button'),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Hero(
                    tag: 'memory_${_memory.id}',
                    child: MemoryPhoto(
                      storageKey: _memory.storageKey,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.s16),
              decoration: BoxDecoration(
                color: AppColors.ink900.withValues(alpha: 0.75),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _memory.title,
                      key: const Key('memory_viewer_title'),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: AppColors.ink50),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Row(
                      children: [
                        const Icon(Icons.event_rounded,
                            size: 16, color: PawPalette.mint),
                        const SizedBox(width: AppSpace.s4),
                        Text(
                          _viewerDate(_memory.takenOn),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: PawPalette.mint),
                        ),
                        const SizedBox(width: AppSpace.s12),
                        Icon(Icons.pets_rounded,
                            size: 16,
                            color: AppColors.ink300.withValues(alpha: 0.8)),
                        const SizedBox(width: AppSpace.s4),
                        Text(
                          widget.pet.name,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.ink300),
                        ),
                      ],
                    ),
                    if ((_memory.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s12),
                      Text(
                        _memory.note!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.ink50),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _viewerDate(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Capture screen — user picks an image (or types a description) for
/// their pet and submits the analyze request.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/pet.dart';
import '../../shared/services/analyze_service.dart';
import '../../shared/services/connectivity_service.dart';
import '../../shared/widgets/disclaimer.dart';
import 'analysis_controller.dart';

class AnalysisCaptureScreen extends ConsumerStatefulWidget {
  const AnalysisCaptureScreen({super.key, required this.pet});
  final Pet pet;

  @override
  ConsumerState<AnalysisCaptureScreen> createState() =>
      _AnalysisCaptureScreenState();
}

class _AnalysisCaptureScreenState extends ConsumerState<AnalysisCaptureScreen> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(analysisControllerProvider);
    final online = ref.watch(connectivityProvider).asData?.value ?? true;

    ref.listen<AnalysisState>(analysisControllerProvider, (_, next) {
      if (next is AnalysisSuccess) {
        context.go('/analysis/result', extra: next.result);
      } else if (next is AnalysisUploading || next is AnalysisAnalysing) {
        context.go('/analysis/loading');
      } else if (next is AnalysisFailedState &&
          next.kind == AnalyzeFailureKind.quotaExceeded) {
        // Quota exhausted → paywall. The controller stays in the failed
        // state so a back-navigation back to the capture screen still
        // shows the error message in context.
        context.go('/paywall');
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('Check on ${widget.pet.name}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!online)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfflineBanner(theme: theme),
                ),
              _ImageArea(state: state),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          state is AnalysisIdle || state is AnalysisPreparing
                          ? () => ref
                                .read(analysisControllerProvider.notifier)
                                .pickImage(fromCamera: true)
                          : null,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          state is AnalysisIdle || state is AnalysisPreparing
                          ? () => ref
                                .read(analysisControllerProvider.notifier)
                                .pickImage(fromCamera: false)
                          : null,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('From library'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('What did you notice?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _textCtrl,
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. limping on her left front leg since this morning',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (state is AnalysisFailedState)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: (online && _canSubmit(state))
                    ? () => ref
                          .read(analysisControllerProvider.notifier)
                          .submit(pet: widget.pet, text: _textCtrl.text)
                    : null,
                child: const Text('Analyze'),
              ),
              const SizedBox(height: 16),
              const DisclaimerCaption(),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSubmit(AnalysisState state) {
    if (state is AnalysisUploading || state is AnalysisAnalysing) return false;
    // Belt-and-braces against the 1-frame double-tap window — the
    // controller's `isBusy` flips before the state transition.
    if (ref.read(analysisControllerProvider.notifier).isBusy) return false;
    final hasImage = state is AnalysisPreparing && state.image != null;
    final hasText = _textCtrl.text.trim().isNotEmpty;
    return hasImage || hasText;
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're offline. Reconnect to analyze.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageArea extends StatelessWidget {
  const _ImageArea({required this.state});
  final AnalysisState state;

  @override
  Widget build(BuildContext context) {
    final preview = state is AnalysisPreparing
        ? (state as AnalysisPreparing).image
        : null;
    final theme = Theme.of(context);
    if (preview == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            'Photo or description below',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        preview.bytes,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

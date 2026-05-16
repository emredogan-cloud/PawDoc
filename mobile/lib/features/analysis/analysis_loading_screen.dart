/// Loading screen displayed while the analyze pipeline runs (upload +
/// AI call). Rotates contextual messages so the user perceives progress
/// regardless of actual latency.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'analysis_controller.dart';

class AnalysisLoadingScreen extends ConsumerStatefulWidget {
  const AnalysisLoadingScreen({super.key});

  @override
  ConsumerState<AnalysisLoadingScreen> createState() =>
      _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends ConsumerState<AnalysisLoadingScreen> {
  static const _messages = [
    'Examining the photo…',
    'Checking breed-specific risks…',
    'Cross-referencing common symptoms…',
    'Finalising recommendations…',
  ];

  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      setState(() => _idx = (_idx + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AnalysisState>(analysisControllerProvider, (_, next) {
      if (next is AnalysisSuccess) {
        context.go('/analysis/result', extra: next.result);
      } else if (next is AnalysisFailedState) {
        // Bounce back to capture; the failure message is in the
        // controller state and will render on the capture screen.
        context.go('/analysis/new');
      } else if (next is AnalysisIdle) {
        context.go('/analysis/new');
      }
    });

    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _messages[_idx],
                    key: ValueKey(_idx),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This usually takes a few seconds.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

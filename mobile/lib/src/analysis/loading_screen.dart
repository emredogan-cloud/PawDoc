import 'dart:async';

import 'package:flutter/material.dart';

/// Analysis loading view with 4 rotating contextual messages.
class AnalysisLoadingView extends StatefulWidget {
  const AnalysisLoadingView({super.key});

  static const messages = [
    'Looking at the details…',
    'Checking for anything concerning…',
    'Comparing against common conditions…',
    'Putting together your guidance…',
  ];

  @override
  State<AnalysisLoadingView> createState() => _AnalysisLoadingViewState();
}

class _AnalysisLoadingViewState extends State<AnalysisLoadingView> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() => _i = (_i + 1) % AnalysisLoadingView.messages.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              AnalysisLoadingView.messages[_i],
              key: ValueKey(_i),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

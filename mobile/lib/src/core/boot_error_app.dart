import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_views.dart';

/// Shown when the app fails to initialize before the real UI can mount (e.g.
/// `Supabase.initialize` throws). Renders a calm "Couldn't start — tap to retry"
/// screen via [AppErrorView] instead of a raw red Flutter stack trace.
///
/// Closes runtime finding R09 (the Supabase-not-initialized crash screen).
class BootErrorApp extends StatelessWidget {
  const BootErrorApp({super.key, this.onRetry});

  /// Re-attempts initialization. Null hides the retry button.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: AppErrorView(
            message: 'PawDoc couldn’t start.\n'
                'Please check your connection and try again.',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}

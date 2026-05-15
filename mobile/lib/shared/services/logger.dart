/// Thin wrapper around `package:logging` that the rest of the codebase uses.
///
/// Reasons we don't print:
///   - prints fire even in release builds, leaking diagnostics
///   - they don't include level, source, or timestamp
///   - they bypass Sentry breadcrumb capture (which we wire in Phase 1)
library;

import 'dart:developer' as developer;

import 'package:logging/logging.dart';

import '../../app/config.dart';

class AppLogger {
  AppLogger._();

  /// Configure logging once at startup. Idempotent.
  static void configure(AppConfig config) {
    Logger.root.level = config.isProduction ? Level.INFO : Level.ALL;

    Logger.root.onRecord.listen((record) {
      // `dart:developer.log` is the framework-correct sink: shows up in IDEs,
      // gets bridged to OS-level logs on iOS/Android, and is structured enough
      // for our needs at this stage.
      developer.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  /// Return a named logger; convention is to use the dotted module path.
  static Logger of(String name) => Logger(name);
}

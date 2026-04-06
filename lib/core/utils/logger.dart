import 'package:flutter/foundation.dart';
/// Lightweight debug-only logger to avoid release IO overhead.
void logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

/// Log an error with stack trace in debug builds.
void logError(String message, [Object? error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('[Error] $message');
    if (error != null) {
      debugPrint('  error: $error');
    }
    if (stackTrace != null) {
      debugPrint('  stack: $stackTrace');
    }
  }
}

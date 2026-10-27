import 'dart:async';
import 'dart:io';

import 'failures.dart';

/// Maps technical exceptions, failures, and raw error strings into clean,
/// human-friendly messages for toasts, snackbars, and banners.
class ErrorMessageMapper {
  const ErrorMessageMapper._();

  /// Converts any [error] (Exception, Failure, or String) into a user-friendly string.
  static String map(dynamic error, {String? defaultMessage}) {
    if (error == null) {
      return defaultMessage ?? 'An unexpected error occurred. Please try again.';
    }

    // 1. Direct Typed Failures
    if (error is NetworkFailure) {
      return 'Unable to connect to the internet. Please check your network connection.';
    }
    if (error is ServerFailure) {
      return 'Music service is temporarily unavailable. Please try again later.';
    }
    if (error is RateLimitFailure) {
      return 'Too many requests. Please wait a moment before trying again.';
    }
    if (error is StreamNotFoundFailure) {
      return 'No playable audio stream available for this track.';
    }
    if (error is AudioFailure) {
      return 'Unable to play this track. Audio stream could not be loaded.';
    }
    if (error is PermissionFailure) {
      return 'Permission required to perform this action.';
    }

    // 2. Direct Dart Exceptions
    if (error is TimeoutException) {
      return 'Connection timed out. Please check your internet connection.';
    }
    if (error is SocketException) {
      return 'Unable to connect to the internet. Please check your network connection.';
    }
    if (error is HttpException) {
      return 'Network communication failed. Please try again later.';
    }
    if (error is FormatException) {
      return 'Could not process music data. Please try again.';
    }

    // 3. String representation pattern matching
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();

    // Timeout patterns
    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return 'Connection timed out. Please check your internet connection.';
    }

    // Network & Socket patterns
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception')) {
      return 'Unable to connect to the internet. Please check your network connection.';
    }

    // HTTP status codes
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Audio stream access was restricted. Attempting alternative audio source.';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'The requested track could not be found.';
    }
    if (lower.contains('429') || lower.contains('too many requests') || lower.contains('ratelimit')) {
      return 'Too many requests. Please wait a moment before trying again.';
    }
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('server error') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable')) {
      return 'Music service is temporarily unavailable. Please try again later.';
    }

    // Audio stream & playback pipeline errors
    if (lower.contains('failed to load audio') ||
        lower.contains('exoplayer') ||
        lower.contains('audioplayer') ||
        lower.contains('player pipeline') ||
        lower.contains('platformexception')) {
      return 'Unable to load or play audio stream. Please try again or switch sources.';
    }

    if (lower.contains('audio focus denied')) {
      return 'Audio playback focus was denied by another running app.';
    }

    if (lower.contains('unable to resolve audio stream') ||
        lower.contains('no stream found')) {
      return 'Could not find a playable stream for this track.';
    }

    // Sanitize technical prefixes if present (e.g. "Exception: ...", "StateError: ...")
    String sanitized = raw;
    final prefixRegex = RegExp(r'^[A-Za-z0-9_]*Exception:\s*|^[A-Za-z0-9_]*Error:\s*');
    sanitized = sanitized.replaceAll(prefixRegex, '');

    // Strip raw URLs if present
    sanitized = sanitized.replaceAll(RegExp(r'https?://\S+'), '').trim();

    // Strip stack trace lines
    if (sanitized.contains('\n')) {
      sanitized = sanitized.split('\n').first.trim();
    }

    // If sanitized string is clean, relatively short, and human readable, return it
    if (sanitized.isNotEmpty &&
        sanitized.length < 120 &&
        !sanitized.contains('{') &&
        !sanitized.contains('(') &&
        !sanitized.contains('XMLHttpRequest') &&
        !sanitized.contains('OS Error')) {
      return sanitized;
    }

    return defaultMessage ?? 'Could not complete action. Please check your connection and try again.';
  }
}

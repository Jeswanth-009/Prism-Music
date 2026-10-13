import 'package:intl/intl.dart';

/// Centralized, locale-aware formatting helpers for dates, counts, sizes, and durations.
class Formatters {
  Formatters._();

  /// Format byte counts into human-readable B, KB, MB, or GB strings.
  static String formatBytes(int bytes, {String? locale}) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';

    final formatter = NumberFormat('0.0', locale);
    if (bytes < 1024 * 1024) {
      return '${formatter.format(bytes / 1024)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${formatter.format(bytes / (1024 * 1024))} MB';
    }
    return '${formatter.format(bytes / (1024 * 1024 * 1024))} GB';
  }

  /// Format numeric counts with locale grouping and proper pluralization.
  ///
  /// Example:
  /// `formatCount(1, 'song')` => `'1 song'`
  /// `formatCount(1250, 'song')` => `'1,250 songs'`
  static String formatCount(
    int count,
    String singular, [
    String? plural,
    String? locale,
  ]) {
    final formattedNumber = NumberFormat.decimalPattern(locale).format(count);
    final noun = count == 1 ? singular : (plural ?? '${singular}s');
    return '$formattedNumber $noun';
  }

  /// Format date using standard localized month, day, and year.
  ///
  /// Example: `'Jan 15, 2024'`
  static String formatDate(DateTime date, {String? locale}) {
    return DateFormat.yMMMd(locale).format(date);
  }

  /// Format relative date (Today, Yesterday, X days ago, or standard date).
  static String formatRelativeDate(
    DateTime date, {
    DateTime? now,
    String? locale,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final target = DateTime(date.year, date.month, date.day);
    final daysDiff = today.difference(target).inDays;

    if (daysDiff == 0) return 'Today';
    if (daysDiff == 1) return 'Yesterday';
    if (daysDiff > 1 && daysDiff < 30) return '$daysDiff days ago';
    if (daysDiff < 0 && daysDiff > -30) return 'in ${-daysDiff} days';
    return formatDate(date, locale: locale);
  }

  /// Format a duration into a readable `X hr Y min` or `Y min` string.
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    if (minutes > 0) {
      return '$minutes min';
    }
    final seconds = duration.inSeconds % 60;
    return '$seconds sec';
  }
}

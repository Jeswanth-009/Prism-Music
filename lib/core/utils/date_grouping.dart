import 'package:intl/intl.dart';

/// Helper utility for organizing chronological records (search queries, listening history)
/// into human-friendly time periods.
abstract final class DateGrouping {
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String thisWeek = 'This week';
  static const String earlier = 'Earlier';

  /// How long ago a timestamp may be and still count as part of the current
  /// \"Today\" session. A listening session that runs past midnight is still
  /// today for the listener, so elapsed time decides this, not the calendar.
  static const Duration _todayWindow = Duration(hours: 6);

  /// Classifies a [DateTime] into a standard period header.
  ///
  /// Classification is elapsed-time first so that a track played at 23:45 and
  /// viewed at 00:05 is still reported as [today] instead of [yesterday].
  static String getPeriodLabel(DateTime dateTime, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final local = dateTime.toLocal();
    final diff = current.difference(local);

    // An active session that crosses midnight stays under Today.
    if (!diff.isNegative && diff < _todayWindow) {
      return today;
    }

    // Timestamps later today (clock skew) also belong to Today.
    if (local.isAfter(DateTime(current.year, current.month, current.day))) {
      return today;
    }

    if (!diff.isNegative && diff < const Duration(hours: 48)) {
      return yesterday;
    }

    if (!diff.isNegative && diff < const Duration(days: 7)) {
      return thisWeek;
    }

    return earlier;
  }

  /// Formats a [DateTime] into a concise relative description (e.g. "Just now", "12m ago", "3h ago", "Yesterday", "Oct 18").
  static String formatRelativeTime(DateTime dateTime, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final local = dateTime.toLocal();
    final diff = current.difference(local);

    if (diff.isNegative) {
      return 'Just now';
    }

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      // Elapsed hours win over the calendar day: a track from 23:45 is still
      // \"2h ago\" at 01:45, not \"Yesterday\".
      return '${diff.inHours}h ago';
    }

    final yesterdayDate = DateTime(current.year, current.month, current.day)
        .subtract(const Duration(days: 1));
    final isCalendarYesterday = local.year == yesterdayDate.year &&
        local.month == yesterdayDate.month &&
        local.day == yesterdayDate.day;

    if (isCalendarYesterday || diff.inHours < 48) {
      final timeStr = DateFormat('h:mm a').format(local);
      return 'Yesterday, $timeStr';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (local.year == current.year) {
      return DateFormat('MMM d').format(local);
    } else {
      return DateFormat('MMM d, yyyy').format(local);
    }
  }

  /// Groups a list of items of type [T] by period label based on a timestamp extractor.
  static Map<String, List<T>> groupByPeriod<T>(
    Iterable<T> items,
    DateTime Function(T item) getTimestamp,
  ) {
    final map = <String, List<T>>{
      today: <T>[],
      yesterday: <T>[],
      thisWeek: <T>[],
      earlier: <T>[],
    };

    for (final item in items) {
      final label = getPeriodLabel(getTimestamp(item));
      map[label]?.add(item);
    }

    // Return only non-empty groups in chronological order
    final result = <String, List<T>>{};
    for (final key in [today, yesterday, thisWeek, earlier]) {
      final list = map[key];
      if (list != null && list.isNotEmpty) {
        result[key] = list;
      }
    }
    return result;
  }
}

import 'package:intl/intl.dart';

/// Helper utility for organizing chronological records (search queries, listening history)
/// into human-friendly time periods.
abstract final class DateGrouping {
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String thisWeek = 'This week';
  static const String earlier = 'Earlier';

  /// Classifies a [DateTime] into a standard period header.
  static String getPeriodLabel(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 7));

    if (local.isAfter(todayStart)) {
      return today;
    } else if (local.isAfter(yesterdayStart)) {
      return yesterday;
    } else if (local.isAfter(weekStart)) {
      return thisWeek;
    } else {
      return earlier;
    }
  }

  /// Formats a [DateTime] into a concise relative description (e.g. "Just now", "12m ago", "3h ago", "Yesterday", "Oct 18").
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.isNegative) {
      return 'Just now';
    }

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && dateTime.day == now.day) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays <= 1 || (diff.inHours < 48 && dateTime.day == now.subtract(const Duration(days: 1)).day)) {
      final timeStr = DateFormat('h:mm a').format(dateTime);
      return 'Yesterday, $timeStr';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (dateTime.year == now.year) {
      return DateFormat('MMM d').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
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

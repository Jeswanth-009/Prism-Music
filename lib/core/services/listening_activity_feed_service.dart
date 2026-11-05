import '../../domain/entities/listening_stats.dart';
import '../../domain/entities/song.dart';

/// Weekly listening summary derived from listening history.
class WeeklyRecap {
  final DateTime startDate;
  final DateTime endDate;
  final int totalPlays;
  final Duration totalListeningTime;
  final List<MapEntry<String, int>> topArtists;
  final List<MapEntry<Song, int>> topSongs;
  final List<int> dailyPlays; // 7 entries, trailing 7 days
  final int previousWeekPlays;
  final double trendPercentage;

  const WeeklyRecap({
    required this.startDate,
    required this.endDate,
    required this.totalPlays,
    required this.totalListeningTime,
    required this.topArtists,
    required this.topSongs,
    required this.dailyPlays,
    required this.previousWeekPlays,
    required this.trendPercentage,
  });

  bool get isEmpty => totalPlays == 0;
}

/// Comprehensive annual "Year in Music" summary.
class YearInReview {
  final int year;
  final int totalPlays;
  final Duration totalListeningTime;
  final int uniqueSongs;
  final int uniqueArtists;
  final List<MapEntry<Song, int>> topSongs;
  final List<MapEntry<String, int>> topArtists;
  final List<MapEntry<String, int>> topGenres;
  final String personalityBadge;
  final String personalityDescription;
  final String? mostActiveMonth;
  final int mostActiveMonthPlays;

  const YearInReview({
    required this.year,
    required this.totalPlays,
    required this.totalListeningTime,
    required this.uniqueSongs,
    required this.uniqueArtists,
    required this.topSongs,
    required this.topArtists,
    required this.topGenres,
    required this.personalityBadge,
    required this.personalityDescription,
    this.mostActiveMonth,
    this.mostActiveMonthPlays = 0,
  });

  bool get isEmpty => totalPlays == 0;
}

/// Service computing weekly recaps and "Your Year in Music" summaries
/// from raw playback history.
class ListeningActivityFeedService {
  const ListeningActivityFeedService();

  /// Computes a 7-day weekly recap relative to [referenceDate] (defaults to now).
  WeeklyRecap generateWeeklyRecap(
    List<HistoryEntry> entries, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // Trailing 7 full days window including today
    final windowStart = todayStart.subtract(const Duration(days: 6));
    final windowEnd = todayStart.add(const Duration(days: 1));

    // Previous 7-day window for comparison
    final prevStart = windowStart.subtract(const Duration(days: 7));
    final prevEnd = windowStart;

    final weekEntries = <HistoryEntry>[];
    var prevWeekCount = 0;

    for (final entry in entries) {
      if (entry.playedAt.isAfter(windowStart) && entry.playedAt.isBefore(windowEnd)) {
        weekEntries.add(entry);
      } else if (entry.playedAt.isAfter(prevStart) && entry.playedAt.isBefore(prevEnd)) {
        prevWeekCount++;
      }
    }

    if (weekEntries.isEmpty) {
      return WeeklyRecap(
        startDate: windowStart,
        endDate: todayStart,
        totalPlays: 0,
        totalListeningTime: Duration.zero,
        topArtists: const [],
        topSongs: const [],
        dailyPlays: List<int>.filled(7, 0),
        previousWeekPlays: prevWeekCount,
        trendPercentage: prevWeekCount > 0 ? -100.0 : 0.0,
      );
    }

    // Daily distribution (7 days: index 0 = 6 days ago, index 6 = today)
    final dailyCounts = List<int>.filled(7, 0);
    var totalSeconds = 0;
    final songCounts = <String, ({Song song, int count})>{};
    final artistCounts = <String, int>{};

    for (final entry in weekEntries) {
      final playedDay = DateTime(entry.playedAt.year, entry.playedAt.month, entry.playedAt.day);
      final dayOffset = playedDay.difference(windowStart).inDays;
      if (dayOffset >= 0 && dayOffset < 7) {
        dailyCounts[dayOffset]++;
      }

      totalSeconds += entry.song.duration.inSeconds;

      // Track counts
      final sKey = entry.song.id;
      final current = songCounts[sKey];
      if (current == null) {
        songCounts[sKey] = (song: entry.song, count: 1);
      } else {
        songCounts[sKey] = (song: current.song, count: current.count + 1);
      }

      // Artist counts
      final artist = entry.song.artist.trim();
      if (artist.isNotEmpty) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      }
    }

    // Sort songs by play count
    final sortedSongs = songCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final topSongs = sortedSongs
        .take(5)
        .map((e) => MapEntry(e.song, e.count))
        .toList();

    // Sort artists by play count
    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(5).toList();

    final totalPlays = weekEntries.length;
    double trend = 0.0;
    if (prevWeekCount > 0) {
      trend = ((totalPlays - prevWeekCount) / prevWeekCount) * 100;
    } else if (totalPlays > 0) {
      trend = 100.0;
    }

    return WeeklyRecap(
      startDate: windowStart,
      endDate: todayStart,
      totalPlays: totalPlays,
      totalListeningTime: Duration(seconds: totalSeconds),
      topArtists: topArtists,
      topSongs: topSongs,
      dailyPlays: dailyCounts,
      previousWeekPlays: prevWeekCount,
      trendPercentage: double.parse(trend.toStringAsFixed(1)),
    );
  }

  /// Computes a comprehensive "Your Year in Music" recap for the given [year].
  YearInReview generateYearInReview(
    List<HistoryEntry> entries, {
    int? year,
    DateTime? referenceDate,
  }) {
    final targetYear = year ?? (referenceDate ?? DateTime.now()).year;
    final yearEntries = entries.where((e) => e.playedAt.year == targetYear).toList();

    if (yearEntries.isEmpty) {
      return YearInReview(
        year: targetYear,
        totalPlays: 0,
        totalListeningTime: Duration.zero,
        uniqueSongs: 0,
        uniqueArtists: 0,
        topSongs: const [],
        topArtists: const [],
        topGenres: const [],
        personalityBadge: 'Fresh Listener',
        personalityDescription: 'Start listening to unlock your annual music identity.',
      );
    }

    var totalSeconds = 0;
    final songCounts = <String, ({Song song, int count})>{};
    final artistCounts = <String, int>{};
    final genreCounts = <String, int>{};
    final monthCounts = <int, int>{};
    final hourCounts = <int, int>{};

    for (final entry in yearEntries) {
      totalSeconds += entry.song.duration.inSeconds;

      final sKey = entry.song.id;
      final current = songCounts[sKey];
      if (current == null) {
        songCounts[sKey] = (song: entry.song, count: 1);
      } else {
        songCounts[sKey] = (song: current.song, count: current.count + 1);
      }

      final artist = entry.song.artist.trim();
      if (artist.isNotEmpty) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      }

      final genre = entry.song.genre?.trim();
      if (genre != null && genre.isNotEmpty) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }

      final m = entry.playedAt.month;
      monthCounts[m] = (monthCounts[m] ?? 0) + 1;

      final h = entry.playedAt.hour;
      hourCounts[h] = (hourCounts[h] ?? 0) + 1;
    }

    final sortedSongs = songCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final topSongs = sortedSongs
        .take(10)
        .map((e) => MapEntry(e.song, e.count))
        .toList();

    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(10).toList();

    final sortedGenres = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(5).toList();

    // Determine peak month
    String? peakMonthName;
    var peakMonthPlays = 0;
    if (monthCounts.isNotEmpty) {
      final sortedMonths = monthCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topMonthNum = sortedMonths.first.key;
      peakMonthPlays = sortedMonths.first.value;
      peakMonthName = _monthNames[topMonthNum - 1];
    }

    // Determine personality badge based on listening patterns
    final (badge, desc) = _computePersonality(
      totalPlays: yearEntries.length,
      uniqueArtists: artistCounts.length,
      uniqueSongs: songCounts.length,
      hourCounts: hourCounts,
      topArtistPlays: sortedArtists.isNotEmpty ? sortedArtists.first.value : 0,
    );

    return YearInReview(
      year: targetYear,
      totalPlays: yearEntries.length,
      totalListeningTime: Duration(seconds: totalSeconds),
      uniqueSongs: songCounts.length,
      uniqueArtists: artistCounts.length,
      topSongs: topSongs,
      topArtists: topArtists,
      topGenres: topGenres,
      personalityBadge: badge,
      personalityDescription: desc,
      mostActiveMonth: peakMonthName,
      mostActiveMonthPlays: peakMonthPlays,
    );
  }

  (String badge, String description) _computePersonality({
    required int totalPlays,
    required int uniqueArtists,
    required int uniqueSongs,
    required Map<int, int> hourCounts,
    required int topArtistPlays,
  }) {
    if (totalPlays < 5) {
      return ('Music Explorer', 'Beginning a journey through sound and melody.');
    }

    // Late night plays (10 PM to 4 AM)
    var lateNightPlays = 0;
    for (final hour in [22, 23, 0, 1, 2, 3, 4]) {
      lateNightPlays += hourCounts[hour] ?? 0;
    }

    if (lateNightPlays > totalPlays * 0.4) {
      return (
        'Night Owl',
        'Over 40% of your listening happens in the quiet midnight hours.',
      );
    }

    // Loyalty test
    if (topArtistPlays > totalPlays * 0.35) {
      return (
        'Devoted Superfan',
        'One artist reigns supreme in your rotation, commanding a massive share of your plays.',
      );
    }

    // Variety test
    if (uniqueArtists > 20 && (uniqueSongs / totalPlays) > 0.7) {
      return (
        'Genre Wanderer',
        'Constantly seeking fresh sounds without ever getting stuck on repeat.',
      );
    }

    if (totalPlays > 100) {
      return (
        'Audio Virtuoso',
        'Music is your constant companion through every moment of the day.',
      );
    }

    return (
      'Melody Enthusiast',
      'Curating a balanced, personal soundtrack across your favorite tunes.',
    );
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
}

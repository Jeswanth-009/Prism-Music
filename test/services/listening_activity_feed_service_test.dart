import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/listening_activity_feed_service.dart';
import 'package:prism_music/domain/entities/listening_stats.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  const service = ListeningActivityFeedService();

  Song makeSong(String id, String title, String artist, {int durationSeconds = 180, String? genre}) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Test Album',
      duration: Duration(seconds: durationSeconds),
      thumbnails: const Thumbnails(),
      source: MusicSource.youtube,
      genre: genre,
    );
  }

  group('ListeningActivityFeedService - Weekly Recap', () {
    test('returns empty recap when entries are empty', () {
      final now = DateTime(2026, 11, 5, 12, 0);
      final recap = service.generateWeeklyRecap([], referenceDate: now);

      expect(recap.isEmpty, isTrue);
      expect(recap.totalPlays, 0);
      expect(recap.totalListeningTime, Duration.zero);
      expect(recap.topArtists, isEmpty);
      expect(recap.topSongs, isEmpty);
      expect(recap.dailyPlays.length, 7);
    });

    test('aggregates plays within the 7-day window and calculates trend', () {
      final now = DateTime(2026, 11, 5, 12, 0);
      final songA = makeSong('s1', 'Starboy', 'The Weeknd', durationSeconds: 200);
      final songB = makeSong('s2', 'Blinding Lights', 'The Weeknd', durationSeconds: 200);
      final songC = makeSong('s3', 'Levitating', 'Dua Lipa', durationSeconds: 180);

      final entries = [
        // Within current week (Nov 5 down to Oct 30)
        HistoryEntry(song: songA, playedAt: DateTime(2026, 11, 5, 10, 0)),
        HistoryEntry(song: songA, playedAt: DateTime(2026, 11, 4, 15, 0)),
        HistoryEntry(song: songB, playedAt: DateTime(2026, 11, 3, 11, 0)),
        HistoryEntry(song: songC, playedAt: DateTime(2026, 11, 2, 9, 0)),
        HistoryEntry(song: songA, playedAt: DateTime(2026, 10, 31, 20, 0)),
        // Within previous week (Oct 23 to Oct 29)
        HistoryEntry(song: songC, playedAt: DateTime(2026, 10, 28, 14, 0)),
        HistoryEntry(song: songC, playedAt: DateTime(2026, 10, 27, 12, 0)),
        // Older than 2 weeks
        HistoryEntry(song: songA, playedAt: DateTime(2026, 10, 1, 10, 0)),
      ];

      final recap = service.generateWeeklyRecap(entries, referenceDate: now);

      expect(recap.isEmpty, isFalse);
      expect(recap.totalPlays, 5);
      expect(recap.previousWeekPlays, 2);
      // ((5 - 2) / 2) * 100 = 150.0%
      expect(recap.trendPercentage, 150.0);
      expect(recap.totalListeningTime.inSeconds, (200 * 3) + 200 + 180);
      expect(recap.topArtists.first.key, 'The Weeknd');
      expect(recap.topArtists.first.value, 4);
      expect(recap.topSongs.first.key.title, 'Starboy');
      expect(recap.topSongs.first.value, 3);
      expect(recap.dailyPlays.reduce((a, b) => a + b), 5);
    });
  });

  group('ListeningActivityFeedService - Year in Review', () {
    test('returns empty review when no entries match target year', () {
      final now = DateTime(2026, 11, 5);
      final review = service.generateYearInReview([], year: 2026, referenceDate: now);

      expect(review.isEmpty, isTrue);
      expect(review.totalPlays, 0);
      expect(review.totalListeningTime, Duration.zero);
      expect(review.personalityBadge, 'Fresh Listener');
    });

    test('generates comprehensive Year in Review with personality and peak month', () {
      final song1 = makeSong('1', 'After Hours', 'The Weeknd', genre: 'R&B');
      final song2 = makeSong('2', 'Save Your Tears', 'The Weeknd', genre: 'Pop');
      final song3 = makeSong('3', 'Cruel Summer', 'Taylor Swift', genre: 'Pop');

      final entries = <HistoryEntry>[
        // October plays (late night 23:00)
        HistoryEntry(song: song1, playedAt: DateTime(2026, 10, 10, 23, 15)),
        HistoryEntry(song: song1, playedAt: DateTime(2026, 10, 11, 23, 40)),
        HistoryEntry(song: song1, playedAt: DateTime(2026, 10, 12, 1, 10)),
        HistoryEntry(song: song2, playedAt: DateTime(2026, 10, 15, 23, 50)),
        // September plays
        HistoryEntry(song: song3, playedAt: DateTime(2026, 9, 5, 14, 0)),
        HistoryEntry(song: song3, playedAt: DateTime(2026, 9, 6, 15, 0)),
        HistoryEntry(song: song3, playedAt: DateTime(2026, 9, 7, 16, 0)),
        // 2025 play (should be ignored for 2026)
        HistoryEntry(song: song1, playedAt: DateTime(2025, 12, 31, 23, 0)),
      ];

      final review = service.generateYearInReview(entries, year: 2026);

      expect(review.isEmpty, isFalse);
      expect(review.year, 2026);
      expect(review.totalPlays, 7);
      expect(review.uniqueSongs, 3);
      expect(review.uniqueArtists, 2);
      expect(review.topSongs.first.key.title, 'After Hours');
      expect(review.topSongs.first.value, 3);
      expect(review.topArtists.first.key, 'The Weeknd');
      expect(review.topArtists.first.value, 4);
      expect(review.topGenres.first.key, 'Pop');
      expect(review.mostActiveMonth, 'October');
      expect(review.mostActiveMonthPlays, 4);
      // 4 out of 6 plays were late night -> Night Owl
      expect(review.personalityBadge, 'Night Owl');
    });
  });
}

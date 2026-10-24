import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/stats_export_service.dart';
import 'package:prism_music/domain/entities/listening_stats.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSong = Song(
    id: 's_01',
    title: 'Neon Nights',
    artist: 'Prism Wave',
    album: 'City Lights',
    duration: Duration(seconds: 240),
    youtubeId: 'neon123',
    thumbnails: Thumbnails(),
  );

  final testStats = ListeningStats(
    totalPlays: 42,
    totalListeningTime: const Duration(hours: 3, minutes: 15),
    uniqueSongs: 28,
    topArtist: 'Prism Wave',
    topArtistCount: 15,
    mostPlayedSong: testSong,
    mostPlayedCount: 9,
    topGenre: 'Electronic',
    topGenreCount: 20,
    firstPlayed: DateTime(2026, 1, 15),
    lastPlayed: DateTime(2026, 10, 24),
  );

  group('StatsExportService', () {
    test('buildShareableSummary produces structured card with accurate values', () {
      final summary = StatsExportService.instance.buildShareableSummary(testStats);

      expect(summary, contains('My Prism Music Listening Stats'));
      expect(summary, contains('Total Listening Time: 3h 15m'));
      expect(summary, contains('Total Plays: 42'));
      expect(summary, contains('Unique Songs: 28'));
      expect(summary, contains('Top Artist: Prism Wave (15 plays)'));
      expect(summary, contains('Most Played Song: Neon Nights by Prism Wave (9 plays)'));
      expect(summary, contains('Top Genre: Electronic (20 plays)'));
      expect(summary, contains('Listening Since: 2026-01-15'));
      expect(summary, contains('Listen on Prism Music'));
    });

    test('buildShareableSummary formats minutes when listening time is under an hour', () {
      const shortStats = ListeningStats(
        totalPlays: 5,
        totalListeningTime: Duration(minutes: 25),
        uniqueSongs: 5,
      );

      final summary = StatsExportService.instance.buildShareableSummary(shortStats);
      expect(summary, contains('Total Listening Time: 25m'));
      expect(summary, contains('Total Plays: 5'));
      expect(summary, contains('Unique Songs: 5'));
    });
  });
}

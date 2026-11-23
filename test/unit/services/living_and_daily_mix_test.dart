import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/daily_mix_service.dart';
import 'package:prism_music/core/services/living_time_service.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  group('LivingTimeService', () {
    final service = LivingTimeService.instance;

    test('classifies dawn at 06:30 with morning greeting', () {
      final dt = DateTime(2026, 11, 23, 6, 30); // Monday
      final phase = service.getCurrentPhase(dt);
      final soundscape = service.getSoundscape(dt);

      expect(phase, LivingPhase.dawn);
      expect(soundscape.greeting, 'Good morning');
      expect(soundscape.uppercaseTagline, contains('START YOUR DAY'));
      expect(soundscape.moodQueries, isNotEmpty);
    });

    test('classifies weekend dawn with weekend tagline', () {
      final dt = DateTime(2026, 11, 22, 7, 0); // Sunday
      final soundscape = service.getSoundscape(dt);

      expect(soundscape.uppercaseTagline, contains('WEEKEND'));
    });

    test('classifies mid-morning focus at 10:00', () {
      final dt = DateTime(2026, 11, 23, 10, 0);
      final phase = service.getCurrentPhase(dt);
      final soundscape = service.getSoundscape(dt);

      expect(phase, LivingPhase.focus);
      expect(soundscape.title, contains('Deep Work'));
    });

    test('classifies afternoon boost at 14:00', () {
      final dt = DateTime(2026, 11, 23, 14, 0);
      final phase = service.getCurrentPhase(dt);
      final soundscape = service.getSoundscape(dt);

      expect(phase, LivingPhase.afternoon);
      expect(soundscape.greeting, 'Good afternoon');
    });

    test('classifies sunset sessions at 18:30', () {
      final dt = DateTime(2026, 11, 23, 18, 30);
      final phase = service.getCurrentPhase(dt);
      final soundscape = service.getSoundscape(dt);

      expect(phase, LivingPhase.sunset);
      expect(soundscape.greeting, 'Good evening');
    });

    test('classifies prime night lounge at 21:30', () {
      final dt = DateTime(2026, 11, 23, 21, 30);
      final phase = service.getCurrentPhase(dt);
      final soundscape = service.getSoundscape(dt);

      expect(phase, LivingPhase.primeNight);
      expect(soundscape.title, contains('Late Night Lounge'));
    });

    test('classifies midnight dreamscapes at 02:00', () {
      final dt = DateTime(2026, 11, 23, 2, 0);
      final phase = service.getCurrentPhase(dt);
      final soundscape = service.getSoundscape(dt);

      expect(phase, LivingPhase.midnight);
      expect(soundscape.greeting, 'Late night listening');
      expect(soundscape.title, contains('Sweet Dreams'));
    });
  });

  group('DailyMixService', () {
    final service = DailyMixService.instance;

    Song testSong(String id, String title, String artist, String thumb) {
      return Song(
        id: id,
        title: title,
        artist: artist,
        duration: const Duration(minutes: 3),
        thumbnails: Thumbnails.fromUrl(thumb),
      );
    }

    test('returns empty when no songs provided', () {
      final mixes = service.generateDailyMixes(
        history: const [],
        likedSongs: const [],
        seedTracks: const [],
      );
      expect(mixes, isEmpty);
    });

    test('clusters songs by artist with 2x2 collage artwork and subtitles', () {
      final songs = [
        testSong('1', 'Song 1', 'Anirudh Ravichander', 'https://img.com/1.jpg'),
        testSong('2', 'Song 2', 'Anirudh Ravichander', 'https://img.com/2.jpg'),
        testSong('3', 'Song 3', 'KR\$NA', 'https://img.com/3.jpg'),
        testSong('4', 'Song 4', 'KR\$NA', 'https://img.com/4.jpg'),
        testSong('5', 'Song 5', 'Shubh', 'https://img.com/5.jpg'),
        testSong('6', 'Song 6', 'Maanu', 'https://img.com/6.jpg'),
        testSong('7', 'Song 7', 'Imran Khan', 'https://img.com/7.jpg'),
        testSong('8', 'Song 8', 'The Weeknd', 'https://img.com/8.jpg'),
        testSong('9', 'Song 9', 'Dua Lipa', 'https://img.com/9.jpg'),
        testSong('10', 'Song 10', 'Taylor Swift', 'https://img.com/10.jpg'),
      ];

      final mixes = service.generateDailyMixes(
        history: songs.take(5).toList(),
        likedSongs: songs.skip(5).toList(),
      );

      expect(mixes, isNotEmpty);
      expect(mixes.first.title, 'Daily Mix 1');
      expect(mixes.first.topArtists, isNotEmpty);
      expect(mixes.first.subtitle, contains('and more'));
      expect(mixes.first.artworkUrls.length, equals(4));
      expect(mixes.first.songs, isNotEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  group('JioSaavnDataSourceImpl.scoreCandidate', () {
    test('returns 1.0 for verified provider ID match', () {
      final target = Song(
        id: 'yt-123',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        duration: const Duration(seconds: 268),
        thumbnails: const Thumbnails(),
        jioSaavnId: 'jio-verified-999',
      );

      final candidate = {
        'id': 'jio-verified-999',
        'title': 'Kesariya (From "Brahmastra")',
        'more_info': {
          'primary_artists': 'Arijit Singh, Pritam',
          'duration': '268',
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, 1.0);
    });

    test('rejects remix candidate when original song is requested', () {
      final target = Song(
        id: 'yt-1',
        title: 'Levitating',
        artist: 'Dua Lipa',
        album: 'Future Nostalgia',
        duration: const Duration(seconds: 203),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-remix-1',
        'title': 'Levitating (The Blessed Madonna Remix)',
        'more_info': {
          'primary_artists': 'Dua Lipa',
          'duration': '250',
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, 0.0);
    });

    test('rejects instrumental candidate when vocal track is requested', () {
      final target = Song(
        id: 'yt-2',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: const Duration(seconds: 262),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-inst-1',
        'title': 'Tum Hi Ho (Instrumental)',
        'more_info': {
          'primary_artists': 'Mithoon',
          'duration': '262',
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, 0.0);
    });

    test('rejects live recording when studio track is requested', () {
      final target = Song(
        id: 'yt-3',
        title: 'Hotel California',
        artist: 'Eagles',
        album: 'Hotel California',
        duration: const Duration(seconds: 390),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-live-1',
        'title': 'Hotel California (Live On MTV)',
        'more_info': {
          'primary_artists': 'Eagles',
          'duration': '430',
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, 0.0);
    });

    test('rejects cover candidate when original track is requested', () {
      final target = Song(
        id: 'yt-4',
        title: 'Someone Like You',
        artist: 'Adele',
        album: '21',
        duration: const Duration(seconds: 285),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-cover-1',
        'title': 'Someone Like You (Acoustic Cover)',
        'more_info': {
          'primary_artists': 'Various Artists',
          'duration': '280',
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, 0.0);
    });

    test('rejects candidate with excessive duration discrepancy (> 30s)', () {
      final target = Song(
        id: 'yt-5',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: const Duration(seconds: 200),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-dur-1',
        'title': 'Blinding Lights',
        'more_info': {
          'primary_artists': 'The Weeknd',
          'duration': '340', // 140s difference
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, 0.0);
    });

    test('rejects different artist with same track title', () {
      final target = Song(
        id: 'yt-6',
        title: 'Hello',
        artist: 'Adele',
        album: '25',
        duration: const Duration(seconds: 295),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-diff-1',
        'title': 'Hello',
        'more_info': {
          'primary_artists': 'Lionel Richie',
          'duration': '245', // 50s difference
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, 0.0);
    });

    test('matches regional Indic script tracks without dropping characters', () {
      final target = Song(
        id: 'yt-hindi-1',
        title: 'तुम ही हो',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: const Duration(seconds: 262),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-hindi-1',
        'title': 'तुम ही हो',
        'more_info': {
          'primary_artists': 'Arijit Singh',
          'duration': '262',
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, greaterThanOrEqualTo(0.85));
    });

    test('successfully accepts clean original recording with high confidence', () {
      final target = Song(
        id: 'yt-7',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: 'Divide',
        duration: const Duration(seconds: 233),
        thumbnails: const Thumbnails(),
      );

      final candidate = {
        'id': 'jio-valid-1',
        'title': 'Shape of You',
        'more_info': {
          'primary_artists': 'Ed Sheeran',
          'duration': '233',
        },
      };

      final score = JioSaavnDataSourceImpl.scoreCandidate(target, candidate);
      expect(score, greaterThanOrEqualTo(0.80));
    });
  });
}

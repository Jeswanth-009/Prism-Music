import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('JioSaavnDataSourceImpl.getStreamUrl (3DES decryption)', () {
    // Ciphertext for 'https://aac.saavncdn.com/123/test_track_96.mp4'
    // encrypted with 3DES-ECB key '38346591' * 3 and PKCS#5/PKCS#7 padding.
    const encryptedMediaUrl =
        'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDybI4qOHxaPPPR5DQmqZ2zzPFZKh9h83D9';

    test('decrypts 3DES encrypted_media_url and upgrades to 320kbps', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.host == 'www.jiosaavn.com') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'results': [
                {
                  'id': 'jio-dec-1',
                  'title': 'Shape of You',
                  'more_info': {
                    'primary_artists': 'Ed Sheeran',
                    'duration': '233',
                    'encrypted_media_url': encryptedMediaUrl,
                  },
                },
              ],
            })),
            200,
          );
        }
        if (request.method == 'HEAD' && request.url.host == 'aac.saavncdn.com') {
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final datasource = JioSaavnDataSourceImpl(client: mockClient);
      final song = Song(
        id: 'yt-7',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: 'Divide',
        duration: const Duration(seconds: 233),
        thumbnails: const Thumbnails(),
      );

      final streamInfo = await datasource.getStreamUrl(
        song,
        preferredQuality: AudioQuality.high,
      );

      expect(streamInfo, isNotNull);
      expect(streamInfo!.url, 'https://aac.saavncdn.com/123/test_track_320.mp4');
      expect(streamInfo.bitrate, 320);
      expect(streamInfo.quality, AudioQuality.high);
      expect(streamInfo.streamProvenance, 'jiosaavn_matched');
    });
  });
}

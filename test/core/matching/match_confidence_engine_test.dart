import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/matching/match_confidence_engine.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  group('MatchConfidenceEngine', () {
    const defaultThumbnail = Thumbnails(low: 'http://img.jpg');

    Song createSong({
      required String title,
      required String artist,
      Duration duration = const Duration(seconds: 210), // 3m 30s
      String? jioSaavnId,
    }) {
      return Song(
        id: 'test_id',
        title: title,
        artist: artist,
        duration: duration,
        thumbnails: defaultThumbnail,
        jioSaavnId: jioSaavnId,
      );
    }

    test('exact match produces high confidence and is acceptable', () {
      final target = createSong(title: 'Starboy', artist: 'The Weeknd');
      final result = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Starboy',
        candidateArtistRaw: 'The Weeknd',
        candidateDuration: const Duration(seconds: 210),
      );

      expect(result.isAcceptable, isTrue);
      expect(result.score, greaterThanOrEqualTo(0.95));
      expect(result.durationDelta, Duration.zero);
    });

    test('strips promotional tags and matches cleanly', () {
      final target = createSong(
        title: 'Blinding Lights [Official Music Video] (HD)',
        artist: 'The Weeknd - Topic',
      );
      final result = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Blinding Lights',
        candidateArtistRaw: 'The Weeknd',
        candidateDuration: const Duration(seconds: 211),
      );

      expect(result.isAcceptable, isTrue);
      expect(result.score, greaterThanOrEqualTo(0.85));
    });

    test('strips featuring artists from titles', () {
      final target = createSong(
        title: 'Levitating (feat. DaBaby)',
        artist: 'Dua Lipa',
      );
      final result = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Levitating',
        candidateArtistRaw: 'Dua Lipa feat. DaBaby',
        candidateDuration: const Duration(seconds: 209),
      );

      expect(result.isAcceptable, isTrue);
      expect(result.score, greaterThanOrEqualTo(0.80));
    });

    test('strictly rejects unwanted remix / live version tags', () {
      final target = createSong(title: 'Hotel California', artist: 'Eagles');
      final remixResult = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Hotel California (Remix)',
        candidateArtistRaw: 'Eagles',
        candidateDuration: const Duration(seconds: 210),
      );
      expect(remixResult.isAcceptable, isFalse);
      expect(remixResult.score, 0.0);

      final liveResult = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Hotel California (Live at MTV 1994)',
        candidateArtistRaw: 'Eagles',
        candidateDuration: const Duration(seconds: 210),
      );
      expect(liveResult.isAcceptable, isFalse);
      expect(liveResult.score, 0.0);

      final karaokeResult = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Hotel California [Karaoke / Instrumental]',
        candidateArtistRaw: 'Eagles',
        candidateDuration: const Duration(seconds: 210),
      );
      expect(karaokeResult.isAcceptable, isFalse);
      expect(karaokeResult.score, 0.0);
    });

    test('allows remix tag when target explicitly requests remix', () {
      final target = createSong(
        title: 'Levitating (Remix)',
        artist: 'Dua Lipa',
      );
      final result = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Levitating (Remix feat. DaBaby)',
        candidateArtistRaw: 'Dua Lipa',
        candidateDuration: const Duration(seconds: 210),
      );

      expect(result.isAcceptable, isTrue);
      expect(result.score, greaterThanOrEqualTo(0.75));
    });

    test('strictly rejects candidate with large duration discrepancy (>15s)', () {
      final target = createSong(
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        duration: const Duration(seconds: 355), // 5:55
      );
      final result = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Bohemian Rhapsody',
        candidateArtistRaw: 'Queen',
        candidateDuration: const Duration(seconds: 220), // 3:40 (short radio cut or wrong song)
      );

      expect(result.isAcceptable, isFalse);
      expect(result.score, 0.0);
      expect(result.durationDelta.inSeconds, 135);
    });

    test('strictly rejects candidate when known artist has zero overlap', () {
      final target = createSong(
        title: 'Hello',
        artist: 'Adele',
      );
      final result = MatchConfidenceEngine.evaluate(
        target: target,
        candidateTitleRaw: 'Hello',
        candidateArtistRaw: 'Lionel Richie',
        candidateDuration: const Duration(seconds: 210),
      );

      // Unrelated artists with the same title must be rejected
      expect(result.isAcceptable, isFalse);
      expect(result.score, 0.0);
    });

    group('Multilingual Script Support', () {
      test('preserves Devanagari (Hindi) in titles and artists', () {
        final target = createSong(
          title: 'केसरिया (फ्रॉम ब्रह्मास्त्र)',
          artist: 'अरिजीत सिंह',
        );
        final result = MatchConfidenceEngine.evaluate(
          target: target,
          candidateTitleRaw: 'केसरिया',
          candidateArtistRaw: 'अरिजीत सिंह',
          candidateDuration: const Duration(seconds: 210),
        );

        expect(result.isAcceptable, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.80));
      });

      test('preserves Tamil script in titles and artists', () {
        final target = createSong(
          title: 'வாத்தி கமிங் (Official Video)',
          artist: 'அனிருத் ரவிச்சந்தர்',
        );
        final result = MatchConfidenceEngine.evaluate(
          target: target,
          candidateTitleRaw: 'வாத்தி கமிங்',
          candidateArtistRaw: 'அனிருத் ரவிச்சந்தர்',
          candidateDuration: const Duration(seconds: 210),
        );

        expect(result.isAcceptable, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.80));
      });

      test('preserves Korean (Hangul) in titles and artists', () {
        final target = createSong(
          title: '봄날 (Spring Day) [Official MV]',
          artist: '방탄소년단',
        );
        final result = MatchConfidenceEngine.evaluate(
          target: target,
          candidateTitleRaw: '봄날',
          candidateArtistRaw: '방탄소년단',
          candidateDuration: const Duration(seconds: 210),
        );

        expect(result.isAcceptable, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.80));
      });

      test('preserves Japanese (Kanji/Kana) in titles', () {
        final target = createSong(
          title: '夜に駆ける 【Official Music Video】',
          artist: 'YOASOBI',
        );
        final result = MatchConfidenceEngine.evaluate(
          target: target,
          candidateTitleRaw: '夜に駆ける',
          candidateArtistRaw: 'YOASOBI',
          candidateDuration: const Duration(seconds: 210),
        );

        expect(result.isAcceptable, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.85));
      });
    });

    group('evaluateMap', () {
      test('correctly parses JioSaavn / streaming raw map payload', () {
        final target = createSong(
          title: 'Kesariya',
          artist: 'Arijit Singh',
          duration: const Duration(seconds: 268),
        );

        final candidateMap = {
          'id': 'jio_123',
          'title': 'Kesariya (From &quot;Brahmastra&quot;)',
          'more_info': {
            'primary_artists': 'Arijit Singh, Pritam',
            'singers': 'Arijit Singh',
            'duration': '270',
            'encrypted_media_url': 'some_encrypted_url',
          },
        };

        final result = MatchConfidenceEngine.evaluateMap(
          target: target,
          candidateMap: candidateMap,
          provenance: 'jiosaavn_matched',
        );

        expect(result.isAcceptable, isTrue);
        expect(result.provenance, 'jiosaavn_matched');
        expect(result.durationDelta.inSeconds, 2);
        expect(result.score, greaterThanOrEqualTo(0.75));
      });
    });
  });
}

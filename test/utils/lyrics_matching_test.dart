import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/lyrics_matching.dart';

void main() {
  group('lyrics_matching - Unicode and Regional Script Support (F11)', () {
    test('preserves Hindi (Devanagari) script characters and matches correctly', () {
      const queryTitle = 'तुम ही हो';
      const candidateTitle = 'तुम ही हो (Aashiqui 2)';
      const artist = 'अरिजीत सिंह';

      final normalizedQuery = normalizeTrackTitle(queryTitle);
      final normalizedCandidate = normalizeTrackTitle(candidateTitle);
      final normalizedArtist = normalizeArtistName(artist);

      expect(normalizedQuery, equals('तुम ही हो'));
      expect(normalizedCandidate, contains('तुम ही हो'));
      expect(normalizedArtist, equals('अरिजीत सिंह'));

      final score = scoreLyricsCandidate(
        const LyricsQuery(title: queryTitle, artist: artist),
        const LyricsCandidate(
          trackName: candidateTitle,
          artistName: artist,
          syncedLyrics: '[00:10.00]हम तेरे बिन',
        ),
      );

      expect(score, greaterThanOrEqualTo(lyricsAcceptScore));
    });

    test('preserves Tamil script characters in title and artist', () {
      const title = 'அரபிக் குத்து';
      const artist = 'அனிருத் ரவிச்சந்தர்';

      final normalizedTitle = normalizeTrackTitle(title);
      final normalizedArtist = normalizeArtistName(artist);

      expect(normalizedTitle, equals('அரபிக் குத்து'));
      expect(normalizedArtist, equals('அனிருத் ரவிச்சந்தர்'));

      final score = scoreLyricsCandidate(
        const LyricsQuery(title: title, artist: artist),
        const LyricsCandidate(
          trackName: title,
          artistName: artist,
          plainLyrics: 'Lyrics in Tamil',
        ),
      );

      expect(score, greaterThanOrEqualTo(lyricsAcceptScore));
    });

    test('preserves Telugu script characters in title and artist', () {
      const title = 'సామజవరగమన';
      const artist = 'సిద్ శ్రీరామ్';

      final normalizedTitle = normalizeTrackTitle(title);
      final normalizedArtist = normalizeArtistName(artist);

      expect(normalizedTitle, equals('సామజవరగమన'));
      expect(normalizedArtist, equals('సిద్ శ్రీరామ్'));

      final score = scoreLyricsCandidate(
        const LyricsQuery(title: title, artist: artist),
        const LyricsCandidate(
          trackName: title,
          artistName: artist,
        ),
      );

      expect(score, greaterThanOrEqualTo(lyricsAcceptScore));
    });

    test('preserves Korean (Hangul) script characters', () {
      const title = '강남스타일';
      const artist = '싸이';

      final normalizedTitle = normalizeTrackTitle(title);
      final normalizedArtist = normalizeArtistName(artist);

      expect(normalizedTitle, equals('강남스타일'));
      expect(normalizedArtist, equals('싸이'));

      final score = scoreLyricsCandidate(
        const LyricsQuery(title: title, artist: artist),
        const LyricsCandidate(
          trackName: title,
          artistName: artist,
        ),
      );

      expect(score, greaterThanOrEqualTo(lyricsAcceptScore));
    });

    test('preserves Japanese Kanji and Kana characters', () {
      const title = '夜に駆ける';
      const artist = 'YOASOBI';

      final normalizedTitle = normalizeTrackTitle(title);
      expect(normalizedTitle, equals('夜に駆ける'));

      final score = scoreLyricsCandidate(
        const LyricsQuery(title: title, artist: artist),
        const LyricsCandidate(
          trackName: title,
          artistName: artist,
        ),
      );

      expect(score, greaterThanOrEqualTo(lyricsAcceptScore));
    });

    test('pure punctuation inputs collapse to empty and never match as false positives', () {
      const queryTitle = '???';
      const candidateTitle = '!!!';

      final score = scoreLyricsCandidate(
        const LyricsQuery(title: queryTitle, artist: 'Artist'),
        const LyricsCandidate(
          trackName: candidateTitle,
          artistName: 'Artist',
        ),
      );

      expect(score, equals(0.0));
    });

    test('mixed regional and English titles normalize and score properly', () {
      const queryTitle = 'Kesariya (केसरिया)';
      const candidateTitle = 'Kesariya';

      final score = scoreLyricsCandidate(
        const LyricsQuery(title: queryTitle, artist: 'Arijit Singh'),
        const LyricsCandidate(
          trackName: candidateTitle,
          artistName: 'Arijit Singh',
        ),
      );

      expect(score, greaterThanOrEqualTo(lyricsAcceptScore));
    });
  });
}

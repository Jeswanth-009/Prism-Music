import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/unicode_search_matcher.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  group('UnicodeSearchMatcher', () {
    test('normalizes zero-width and invisible characters', () {
      // String with ZWSP (\u200B), ZWNJ (\u200C), ZWJ (\u200D), and BOM (\uFEFF)
      const input = 'Ke\u200Csa\u200Briy\u200Da\uFEFF';
      expect(UnicodeSearchMatcher.normalize(input), 'kesariya');
    });

    test('folds Latin accents and diacritics', () {
      expect(UnicodeSearchMatcher.normalize('Café Música'), 'cafe musica');
      expect(UnicodeSearchMatcher.normalize('Señorita Über'), 'senorita uber');
      expect(UnicodeSearchMatcher.normalize('Mötorhead'), 'motorhead');
    });

    test('normalizes Indic script nuktas', () {
      // Hindi nukta \u093C on क (फ़ -> ph/f)
      const input = 'फ़िल्म';
      final norm = UnicodeSearchMatcher.normalize(input);
      expect(norm.contains('\u093C'), isFalse);
    });

    test('folds regional phonetic transliterations for Indian music', () {
      final folded1 = UnicodeSearchMatcher.phoneticFold('shanthi');
      final folded2 = UnicodeSearchMatcher.phoneticFold('santi');
      expect(folded1, folded2);

      final foldedGeetha = UnicodeSearchMatcher.phoneticFold('geetha');
      final foldedGita = UnicodeSearchMatcher.phoneticFold('gita');
      expect(foldedGeetha, foldedGita);

      final foldedDhoom = UnicodeSearchMatcher.phoneticFold('dhoom');
      final foldedDhum = UnicodeSearchMatcher.phoneticFold('dhum');
      expect(foldedDhoom, foldedDhum);
    });

    test('matches queries with mixed cases and accents', () {
      expect(
        UnicodeSearchMatcher.matches('Despacito (Remix)', 'despacito'),
        isTrue,
      );
      expect(
        UnicodeSearchMatcher.matches('Café del Mar', 'cafe'),
        isTrue,
      );
      expect(
        UnicodeSearchMatcher.matches('Kesariya (Brahmāstra)', 'kesariya'),
        isTrue,
      );
      expect(
        UnicodeSearchMatcher.matches('Shreya Ghoshal Hits', 'sreya gosal'),
        isTrue,
      );
    });

    test('computes similarity scores accurately', () {
      final exact = UnicodeSearchMatcher.computeSimilarity('Kesariya', 'Kesariya');
      expect(exact, 1.0);

      final phonetic =
          UnicodeSearchMatcher.computeSimilarity('Shreya Ghoshal', 'Sreya Goshal');
      expect(phonetic, greaterThanOrEqualTo(0.9));

      final unrelated =
          UnicodeSearchMatcher.computeSimilarity('Kesariya', 'Bohemian Rhapsody');
      expect(unrelated, lessThan(0.3));
    });

    test('filters songs across title, artist, and album', () {
      final songs = [
        const Song(
          id: '1',
          title: 'Kesariya',
          artist: 'Arijit Singh',
          album: 'Brahmāstra',
          duration: Duration(minutes: 4),
          thumbnails: Thumbnails(),
        ),
        const Song(
          id: '2',
          title: 'Channa Mereya',
          artist: 'Arijit Singh',
          album: 'Ae Dil Hai Mushkil',
          duration: Duration(minutes: 5),
          thumbnails: Thumbnails(),
        ),
        const Song(
          id: '3',
          title: 'Shape of You',
          artist: 'Ed Sheeran',
          album: 'Divide',
          duration: Duration(minutes: 3),
          thumbnails: Thumbnails(),
        ),
      ];

      // Match by title
      final matchTitle = UnicodeSearchMatcher.filterSongs(songs, 'kesariya');
      expect(matchTitle.length, 1);
      expect(matchTitle.first.id, '1');

      // Match by album with diacritics
      final matchAlbum = UnicodeSearchMatcher.filterSongs(songs, 'brahmastra');
      expect(matchAlbum.length, 1);
      expect(matchAlbum.first.id, '1');

      // Match by artist across songs
      final matchArtist = UnicodeSearchMatcher.filterSongs(songs, 'arijit');
      expect(matchArtist.length, 2);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/lyrics_matching.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  group('TTML and Karaoke Lyrics Parsing', () {
    test('parseTtmlTimeMs parses MM:SS.mmm, HH:MM:SS.mmm, and seconds', () {
      expect(parseTtmlTimeMs('01:23.450'), 83450);
      expect(parseTtmlTimeMs('00:01:23.450'), 83450);
      expect(parseTtmlTimeMs('12.5s'), 12500);
      expect(parseTtmlTimeMs('500ms'), 500);
      expect(parseTtmlTimeMs(''), 0);
    });

    test('parseTtmlLyrics parses lines and span words with syllable timestamps', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:01.000" end="00:04.000">
        <span begin="00:01.000" end="00:02.000">Never </span>
        <span begin="00:02.000" end="00:03.000">gonna </span>
        <span begin="00:03.000" end="00:04.000">give</span>
      </p>
      <p begin="00:04.500" end="00:06.000">
        <span begin="00:04.500" end="00:05.500">you </span>
        <span begin="00:05.500" end="00:06.000">up</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = parseTtmlLyrics(ttml);
      expect(lines.length, 2);

      final line1 = lines[0];
      expect(line1.startTimeMs, 1000);
      expect(line1.text, 'Never gonna give');
      expect(line1.isWordSynced, isTrue);
      expect(line1.words!.length, 3);
      expect(line1.words![0].text, 'Never');
      expect(line1.words![0].startTimeMs, 1000);
      expect(line1.words![0].endTimeMs, 2000);

      final line2 = lines[1];
      expect(line2.startTimeMs, 4500);
      expect(line2.text, 'you up');
      expect(line2.words!.length, 2);
      expect(line2.words![1].text, 'up');
      expect(line2.words![1].startTimeMs, 5500);
      expect(line2.words![1].endTimeMs, 6000);
    });

    test('parseLyricsPlusJson extracts word-by-word syllabus structure', () {
      final json = {
        'lines': [
          {
            'time': 12000,
            'duration': 3500,
            'syllabus': [
              {'time': 12000, 'duration': 800, 'text': 'Shape '},
              {'time': 12800, 'duration': 400, 'text': 'of '},
              {'time': 13200, 'duration': 1000, 'text': 'you'},
            ]
          }
        ]
      };

      final lines = parseLyricsPlusJson(json);
      expect(lines.length, 1);
      final line = lines.first;
      expect(line.startTimeMs, 12000);
      expect(line.text, 'Shape of you');
      expect(line.isWordSynced, isTrue);
      expect(line.words!.length, 3);
      expect(line.words![0].startTimeMs, 12000);
      expect(line.words![0].endTimeMs, 12800);
      expect(line.words![1].startTimeMs, 12800);
      expect(line.words![1].endTimeMs, 13200);
      expect(line.words![2].startTimeMs, 13200);
      expect(line.words![2].endTimeMs, 14200);
    });

    test('Lyrics entity accurately identifies karaoke capability', () {
      final wordLine = LyricLine(
        startTimeMs: 1000,
        text: 'Hello world',
        words: [
          const LyricWord(startTimeMs: 1000, endTimeMs: 1500, text: 'Hello'),
          const LyricWord(startTimeMs: 1500, endTimeMs: 2000, text: 'world'),
        ],
      );

      final karaokeLyrics = Lyrics(
        songId: 'test_song',
        plainLyrics: 'Hello world',
        syncedLyrics: [wordLine],
        source: 'Better Lyrics',
        syncType: LyricsSyncType.wordSynced,
        providerId: 'better_lyrics',
      );

      expect(karaokeLyrics.isKaraoke, isTrue);
      expect(karaokeLyrics.isWordSynced, isTrue);
      expect(karaokeLyrics.isSynced, isTrue);
    });
  });
}

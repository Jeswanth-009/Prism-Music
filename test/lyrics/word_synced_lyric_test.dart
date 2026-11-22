import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/lyrics/word_synced_lyric.dart';

void main() {
  group('WordSyncedLyricParser', () {
    test('parses Apple TTML word-level timestamps', () {
      const rawTtml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:10.000" end="00:00:14.000">
        <span begin="00:00:10.000" end="00:00:10.500">Hello </span>
        <span begin="00:00:10.500" end="00:00:11.200">world </span>
        <span begin="00:00:11.200" end="00:00:12.000">today</span>
      </p>
    </div>
  </body>
</tt>
''';

      final parsed = WordSyncedLyricParser.parse(rawTtml);
      expect(parsed.hasWordTiming, isTrue);
      expect(parsed.lines.length, equals(1));

      final line = parsed.lines.first;
      expect(line.text, equals('Hello world today'));
      expect(line.words.length, equals(3));
      expect(line.words[0].word, equals('Hello '));
      expect(line.words[0].startTime, equals(const Duration(seconds: 10)));
      expect(line.words[0].endTime, equals(const Duration(milliseconds: 10500)));

      // Check syllable progress
      expect(line.words[0].getProgress(const Duration(seconds: 9)), equals(0.0));
      expect(line.words[0].getProgress(const Duration(milliseconds: 10250)), equals(0.5));
      expect(line.words[0].getProgress(const Duration(seconds: 11)), equals(1.0));
    });

    test('parses NetEase YRC format', () {
      const rawYrc = '''
[00:05.120](0,400,0)Prism (400,600,0)Music
[00:08.500](0,500,0)Next (500,700,0)Track
''';

      final parsed = WordSyncedLyricParser.parse(rawYrc);
      expect(parsed.hasWordTiming, isTrue);
      expect(parsed.lines.length, equals(2));

      final firstLine = parsed.lines[0];
      expect(firstLine.text, equals('Prism Music'));
      expect(firstLine.words.length, equals(2));
      expect(firstLine.words[0].startTime, equals(const Duration(milliseconds: 5120)));
      expect(firstLine.words[0].endTime, equals(const Duration(milliseconds: 5520)));
      expect(firstLine.words[1].startTime, equals(const Duration(milliseconds: 5520)));
      expect(firstLine.words[1].endTime, equals(const Duration(milliseconds: 6120)));
    });

    test('parses QQ Music QRC format', () {
      const rawQrc = '''
[1000,400]Sing [1400,600]along
''';

      final parsed = WordSyncedLyricParser.parse(rawQrc);
      expect(parsed.hasWordTiming, isTrue);
      expect(parsed.lines.length, equals(1));
      expect(parsed.lines[0].text, equals('Sing along'));
      expect(parsed.lines[0].words[0].duration, equals(const Duration(milliseconds: 400)));
    });

    test('falls back cleanly to standard line-synced LRC', () {
      const rawLrc = '''
[00:02.50]Line one of song
[00:06.00]Line two of song
''';

      final parsed = WordSyncedLyricParser.parse(rawLrc);
      expect(parsed.hasWordTiming, isFalse);
      expect(parsed.lines.length, equals(2));
      expect(parsed.lines[0].text, equals('Line one of song'));
      expect(parsed.lines[0].startTime, equals(const Duration(milliseconds: 2500)));
      expect(parsed.lines[0].endTime, equals(const Duration(seconds: 6)));
      expect(parsed.lines[1].text, equals('Line two of song'));
    });
  });
}

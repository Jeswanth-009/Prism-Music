/// Represents a single word/syllable with precise timing.
class WordLyric {
  final String word;
  final Duration startTime;
  final Duration endTime;

  const WordLyric({
    required this.word,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration => endTime - startTime;

  /// Returns highlight progress [0.0 - 1.0] for the given [position].
  double getProgress(Duration position) {
    if (position < startTime) return 0.0;
    if (position >= endTime) return 1.0;
    final total = duration.inMilliseconds;
    if (total <= 0) return 1.0;
    final elapsed = (position - startTime).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

/// Represents a line composed of word-level syllables or a line-level timestamp.
class LineLyric {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final List<WordLyric> words;

  const LineLyric({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.words = const [],
  });

  bool get hasWordTiming => words.isNotEmpty;

  /// Word index currently active at [position], or -1 if none.
  int getActiveWordIndex(Duration position) {
    if (words.isEmpty) return -1;
    for (int i = 0; i < words.length; i++) {
      if (position >= words[i].startTime && position <= words[i].endTime) {
        return i;
      }
    }
    return -1;
  }
}

/// Parsed song lyrics containing timed lines and word-level accuracy.
class ParsedLyrics {
  final List<LineLyric> lines;
  final bool hasWordTiming;

  const ParsedLyrics({
    required this.lines,
    required this.hasWordTiming,
  });

  bool get isEmpty => lines.isEmpty;

  /// Returns the line index active at [position], or -1.
  int getActiveLineIndex(Duration position) {
    if (lines.isEmpty) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].startTime) {
        return i;
      }
    }
    return -1;
  }
}

/// Clean-room unified parser for TTML, YRC, QRC, KRC, and LRC formats.
class WordSyncedLyricParser {
  /// Parses raw lyric text into [ParsedLyrics] with word-level timing when available.
  static ParsedLyrics parse(String raw) {
    if (raw.trim().isEmpty) {
      return const ParsedLyrics(lines: [], hasWordTiming: false);
    }

    // 1. Check for Apple TTML format
    if (raw.contains('<tt') || raw.contains('<span begin=')) {
      final ttmlLines = _parseTtml(raw);
      if (ttmlLines.isNotEmpty) {
        return ParsedLyrics(lines: ttmlLines, hasWordTiming: true);
      }
    }

    // 2. Check for NetEase YRC format: [mm:ss.xxx](start,duration,0)word...
    if (raw.contains(RegExp(r'\[\d+:\d+\.\d+\]\(\d+,\d+,\d+\)'))) {
      final yrcLines = _parseYrc(raw);
      if (yrcLines.isNotEmpty) {
        return ParsedLyrics(lines: yrcLines, hasWordTiming: true);
      }
    }

    // 3. Check for QQ Music QRC format: [offset,duration]word...
    if (raw.contains(RegExp(r'\[\d+,\d+\][^\n\r]+'))) {
      final qrcLines = _parseQrc(raw);
      if (qrcLines.isNotEmpty) {
        return ParsedLyrics(lines: qrcLines, hasWordTiming: true);
      }
    }

    // 4. Fallback to standard line-synced LRC: [mm:ss.xx]Text
    final lrcLines = _parseStandardLrc(raw);
    return ParsedLyrics(lines: lrcLines, hasWordTiming: false);
  }

  static List<LineLyric> _parseTtml(String ttml) {
    final lines = <LineLyric>[];
    // Find each <p begin="..." end="...">
    final pRegex = RegExp(r'<p\s+begin="([^"]+)"\s+end="([^"]+)"[^>]*>(.*?)</p>', dotAll: true);
    final spanRegex = RegExp(r'<span\s+begin="([^"]+)"\s+end="([^"]+)"[^>]*>([^<]+)</span>');

    for (final pMatch in pRegex.allMatches(ttml)) {
      final lineStart = _parseClockTime(pMatch.group(1) ?? '0');
      final lineEnd = _parseClockTime(pMatch.group(2) ?? '0');
      final pContent = pMatch.group(3) ?? '';

      final words = <WordLyric>[];
      final textBuf = StringBuffer();

      for (final spanMatch in spanRegex.allMatches(pContent)) {
        final wStart = _parseClockTime(spanMatch.group(1) ?? '0');
        final wEnd = _parseClockTime(spanMatch.group(2) ?? '0');
        final wordText = spanMatch.group(3) ?? '';

        words.add(WordLyric(word: wordText, startTime: wStart, endTime: wEnd));
        textBuf.write(wordText);
      }

      final text = textBuf.toString().trim();
      if (text.isNotEmpty) {
        lines.add(
          LineLyric(
            text: text,
            startTime: lineStart,
            endTime: lineEnd,
            words: words,
          ),
        );
      }
    }

    return lines;
  }

  static List<LineLyric> _parseYrc(String yrc) {
    final lines = <LineLyric>[];
    final lineRegex = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');
    final syllableRegex = RegExp(r'\((\d+),(\d+),\d+\)([^\(]+)');

    for (final rawLine in yrc.split('\n')) {
      final match = lineRegex.firstMatch(rawLine.trim());
      if (match == null) continue;

      final min = int.tryParse(match.group(1) ?? '0') ?? 0;
      final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
      final ms = _parseSubSecondsMs(match.group(3) ?? '0');
      final lineBase = Duration(minutes: min, seconds: sec, milliseconds: ms);

      final content = match.group(4) ?? '';
      final words = <WordLyric>[];
      final textBuf = StringBuffer();

      for (final sylMatch in syllableRegex.allMatches(content)) {
        final relOffset = int.tryParse(sylMatch.group(1) ?? '0') ?? 0;
        final dur = int.tryParse(sylMatch.group(2) ?? '0') ?? 0;
        final word = sylMatch.group(3) ?? '';

        final wStart = lineBase + Duration(milliseconds: relOffset);
        final wEnd = wStart + Duration(milliseconds: dur);

        words.add(WordLyric(word: word, startTime: wStart, endTime: wEnd));
        textBuf.write(word);
      }

      final text = textBuf.toString().trim();
      if (text.isNotEmpty) {
        final lineEnd = words.isNotEmpty ? words.last.endTime : lineBase + const Duration(seconds: 4);
        lines.add(
          LineLyric(
            text: text,
            startTime: lineBase,
            endTime: lineEnd,
            words: words,
          ),
        );
      }
    }

    return lines;
  }

  static List<LineLyric> _parseQrc(String qrc) {
    final lines = <LineLyric>[];
    final syllableRegex = RegExp(r'\[(\d+),(\d+)\]([^\[]+)');

    for (final rawLine in qrc.split('\n')) {
      final lineText = rawLine.trim();
      if (lineText.isEmpty) continue;

      final words = <WordLyric>[];
      final textBuf = StringBuffer();
      Duration? lineStart;
      Duration? lineEnd;

      for (final match in syllableRegex.allMatches(lineText)) {
        final startMs = int.tryParse(match.group(1) ?? '0') ?? 0;
        final durMs = int.tryParse(match.group(2) ?? '0') ?? 0;
        final word = match.group(3) ?? '';

        final wStart = Duration(milliseconds: startMs);
        final wEnd = wStart + Duration(milliseconds: durMs);

        lineStart ??= wStart;
        lineEnd = wEnd;

        words.add(WordLyric(word: word, startTime: wStart, endTime: wEnd));
        textBuf.write(word);
      }

      final text = textBuf.toString().trim();
      if (text.isNotEmpty && lineStart != null && lineEnd != null) {
        lines.add(
          LineLyric(
            text: text,
            startTime: lineStart,
            endTime: lineEnd,
            words: words,
          ),
        );
      }
    }

    return lines;
  }

  static List<LineLyric> _parseStandardLrc(String lrc) {
    final lines = <LineLyric>[];
    final lineRegex = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\](.*)');

    for (final rawLine in lrc.split('\n')) {
      final match = lineRegex.firstMatch(rawLine.trim());
      if (match == null) continue;

      final min = int.tryParse(match.group(1) ?? '0') ?? 0;
      final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
      final ms = _parseSubSecondsMs(match.group(3) ?? '0');

      final startTime = Duration(minutes: min, seconds: sec, milliseconds: ms);
      final text = (match.group(4) ?? '').trim();

      if (text.isNotEmpty) {
        lines.add(
          LineLyric(
            text: text,
            startTime: startTime,
            endTime: startTime + const Duration(seconds: 4), // Placeholder until next line
          ),
        );
      }
    }

    // Fix end times to equal next line start time
    for (int i = 0; i < lines.length - 1; i++) {
      final nextStart = lines[i + 1].startTime;
      lines[i] = LineLyric(
        text: lines[i].text,
        startTime: lines[i].startTime,
        endTime: nextStart,
        words: lines[i].words,
      );
    }

    return lines;
  }

  static int _parseSubSecondsMs(String raw) {
    if (raw.isEmpty) return 0;
    if (raw.length == 1) return (int.tryParse(raw) ?? 0) * 100;
    if (raw.length == 2) return (int.tryParse(raw) ?? 0) * 10;
    return int.tryParse(raw.substring(0, 3)) ?? 0;
  }

  static Duration _parseClockTime(String time) {
    // Parses "00:01:23.456", "123ms", or "12.345s"
    if (time.endsWith('ms')) {
      final ms = double.tryParse(time.substring(0, time.length - 2)) ?? 0.0;
      return Duration(milliseconds: ms.round());
    }
    if (time.endsWith('s')) {
      final sec = double.tryParse(time.substring(0, time.length - 1)) ?? 0.0;
      return Duration(milliseconds: (sec * 1000).round());
    }
    final parts = time.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final secondsPart = double.tryParse(parts[2]) ?? 0.0;
      final ms = (secondsPart * 1000).round();
      return Duration(hours: hours, minutes: minutes, milliseconds: ms);
    } else if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final secondsPart = double.tryParse(parts[1]) ?? 0.0;
      final ms = (secondsPart * 1000).round();
      return Duration(minutes: minutes, milliseconds: ms);
    }
    return Duration.zero;
  }
}

/// Track-title / artist normalization and candidate scoring for lyrics
/// lookup.
///
/// YouTube and YT Music titles are full of promotional suffixes ("Official
/// Video", "(Lyrics)", "ft. …") and channel artifacts (" - Topic", "VEVO")
/// that break exact matching against LRCLIB's clean track names. Everything
/// here is pure string/number work so it can be unit-tested without HTTP.
library;

import '../../../../domain/entities/entities.dart';

/// Tags that commonly trail YouTube music titles inside brackets or
/// parentheses, case-insensitively.
/// Tags that commonly trail YouTube music titles inside brackets or
/// parentheses, case-insensitively, including regional and non-Latin tags.
const List<String> _junkPhrases = [
  'official video',
  'official music video',
  'official audio',
  'official visualizer',
  'official lyric video',
  'official mv',
  'lyric video',
  'lyrics',
  'lyrics video',
  'audio',
  'audio song',
  'video',
  'video song',
  'full video',
  'full audio',
  'visualizer',
  'mv',
  'm/v',
  'hd',
  'hq',
  '4k',
  '4k 60fps',
  'remaster', // also matches "remastered" via prefix matching below
  'remastered',
  'color coded',
  'explicit',
  'clean',
  'performance video',
  'live', // "(Live)" — LRCLIB keeps live versions distinct via duration
  'snippet',
  'preview',
  'full episode', // music-show uploads ("BRS Episode 3")
  '가사', // Korean: lyrics
  '뮤직비디오', // Korean: music video
  '歌詞', // Japanese/Chinese: lyrics
  '官方mv', // Chinese: official MV
  '完整版', // Chinese: full version
];

/// Known version keywords to distinguish live/remix/acoustic/remaster
/// recordings from studio versions.
const List<String> _versionKeywords = [
  'live',
  'remix',
  'acoustic',
  'instrumental',
  'remaster',
  'remastered',
  'deluxe',
  'radio edit',
  'extended',
  'orchestral',
  'unplugged',
  'version',
  'session',
];

/// Stop-words to filter when computing token overlap for artists.
const Set<String> _artistStopWords = {
  'the',
  'and',
  '&',
  'feat',
  'ft',
  'featuring',
  'with',
  'or',
  'of',
  'band',
  'orchestra',
};

/// Regex for bracketed/parenthesized segments: (…), […], {…}, as well as
/// full-width and CJK bracket types: （…）, 【…】, 〔…〕, 《…》, 「…」, 『…』, 〖…〗, ［…］, ｛…｝.
final RegExp _bracketSegment = RegExp(
  r'[\(\[\{\uFF08\uFF3B\uFF5B\u3010\u3014\u300A\u300C\u300E\u3016\u3008]'
  r'[^\)\]\}\uFF09\uFF3D\uFF5D\u3011\u3015\u300B\u300D\u300F\u3017\u3009]*'
  r'[\)\]\}\uFF09\uFF3D\uFF5D\u3011\u3015\u300B\u300D\u300F\u3017\u3009]',
);

/// Extract version signature from raw track title for cache partitioning.
String extractVersionTag(String rawTitle) {
  final lower = rawTitle.toLowerCase();
  for (final keyword in _versionKeywords) {
    if (lower.contains(keyword)) {
      return keyword;
    }
  }
  return 'standard';
}

/// Strip the noise that keeps YouTube titles from matching clean track
/// names: bracketed junk segments, trailing "ft. …" suffixes (both
/// bracketed and dash-separated), separators and extra whitespace.
///
/// "Shape of You (Official Video)" -> "shape of you"
/// "Levitating (feat. DaBaby)"     -> "levitating"
/// "Blinding Lights [Lyrics]"      -> "blinding lights"
/// "夜に駆ける 【Official Music Video】" -> "夜に駆ける"
String normalizeTrackTitle(String rawTitle) {
  var title = rawTitle.replaceAll('\u3000', ' ').trim();

  // Repeatedly drop bracketed segments whose content is junk. Iterative
  // because tags nest or stack: "(Official Video) [HD]".
  for (var pass = 0; pass < 4; pass++) {
    var changed = false;
    title = title.replaceAllMapped(_bracketSegment, (match) {
      final fullMatch = match.group(0)!;
      final inner = fullMatch
          .substring(1, fullMatch.length - 1)
          .trim()
          .toLowerCase();
      // Keep segments that look like real title content (e.g. "(Live from
      // Paris)" or "(Deluxe)").
      final isJunk = _junkPhrases.any(
        (phrase) => inner == phrase || inner.startsWith('$phrase '),
      );
      changed = changed || isJunk;
      return isJunk ? ' ' : fullMatch;
    });
    if (!changed) break;
  }

  // Trailing "feat. X" / "ft. X" / "(with X)" after the title.
  var candidate = _stripTrailingFeat(title);

  // Strip leftover separator tails and squeeze whitespace. Separator-heavy
  // shapes like "Artist - Song" vs "Song - Artist" are the scorer's job;
  // here we only remove obvious clutter.
  candidate = candidate
      .replaceAll(RegExp(r'\s*[-–—|]\s*$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  return _collapseForMatch(candidate);
}

/// Strip trailing "feat. …"/"ft. …" markers and trailing bracketed
/// "(with …)" segments from a title (recursively, so "feat. A ft. B"
/// collapses too).
String _stripTrailingFeat(String input) {
  var text = input.replaceAll('\u3000', ' ').trim();
  var previous = '';
  while (text != previous) {
    previous = text;
    text = text.replaceAll(
      RegExp(
        r'[\(\[\{\uFF08\uFF3B\u3010]?\s*(feat\.?|ft\.?|featuring)\s+.*$',
        caseSensitive: false,
      ),
      '',
    ).trim();
    // "(with X)" / "[with X]" at the very end — bracketed only, so plain
    // titles like "With or Without You" are never touched.
    text = text.replaceAll(
      RegExp(
        r'\s*[\(\[\{\uFF08\uFF3B\u3010]\s*with\s+.*[\)\]\}\uFF09\uFF3D\u3011]\s*$',
        caseSensitive: false,
      ),
      '',
    ).trim();
  }
  return text;
}

/// Strip channel artifacts from artist names: " - Topic" and "VEVO".
String normalizeArtistName(String rawArtist) {
  var artist = rawArtist.replaceAll('\u3000', ' ').trim();
  artist = artist.replaceAll(
    RegExp(r'\s*-\s*Topic$', caseSensitive: false),
    '',
  );
  artist = artist.replaceAll(RegExp(r'VEVO$', caseSensitive: false), '');
  artist = artist.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return _collapseForMatch(artist);
}

/// Split a normalized string into comparable tokens: lowercase, Unicode
/// letters, marks (vowel signs/accents) and digits only, preserving regional
/// scripts (Tamil, Telugu, Hindi, Korean, etc.).
String _collapseForMatch(String input) => input
    .toLowerCase()
    .replaceAll('\u3000', ' ')
    .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Parse an LRC document into timed lines. Handles multiple timestamps per
/// line (`[00:12.00][00:45.10]text`), comma decimal separators
/// (`[00:12,50]`), LRC offset metadata (`[offset:+/-ms]`), and skips metadata
/// lines ([ti:], [ar:] …) and empty lines.
List<LyricLine> parseLrc(String lrc) {
  final lines = <LyricLine>[];
  final timestamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.,:](\d{1,3}))?\]');
  final offsetRegex =
      RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

  int offsetMs = 0;
  for (final rawLine in lrc.split('\n')) {
    final offsetMatch = offsetRegex.firstMatch(rawLine);
    if (offsetMatch != null) {
      offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
    }
  }

  for (final rawLine in lrc.split('\n')) {
    final matches = timestamp.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;

    final text = rawLine.substring(matches.last.end).trim();
    if (text.isEmpty) continue;

    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3) ?? '0';
      final milliseconds =
          int.parse(fraction.padRight(3, '0').substring(0, 3));
      final lineTimeMs =
          (minutes * 60 + seconds) * 1000 + milliseconds + offsetMs;
      lines.add(LyricLine(
        startTimeMs: lineTimeMs < 0 ? 0 : lineTimeMs,
        text: text,
      ));
    }
  }

  // LRC files are not guaranteed sorted when timestamps repeat.
  lines.sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));
  return lines;
}

/// A lyrics candidate as returned by LRCLIB's search endpoint, reduced to
/// the fields the scorer needs.
class LyricsCandidate {
  final String trackName;
  final String artistName;
  final int? durationSeconds;
  final String? plainLyrics;
  final String? syncedLyrics;

  const LyricsCandidate({
    required this.trackName,
    required this.artistName,
    this.durationSeconds,
    this.plainLyrics,
    this.syncedLyrics,
  });

  bool get hasSynced =>
      syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;

  bool get hasPlain => plainLyrics != null && plainLyrics!.trim().isNotEmpty;
}

/// The query a lookup was made with, used to score candidates against.
class LyricsQuery {
  final String title;
  final String artist;
  final Duration? duration;

  const LyricsQuery({
    required this.title,
    required this.artist,
    this.duration,
  });

  /// Duration used for scoring — only when plausible (>= 30s). YouTube
  /// songs sometimes carry 0 or a placeholder; matching on those hurts.
  int? get plausibleSeconds {
    final seconds = duration?.inSeconds ?? 0;
    return seconds >= 30 ? seconds : null;
  }
}

/// Minimum score for a search candidate to be accepted.
const double lyricsAcceptScore = 0.60;

/// Score how well a candidate matches the query on a 0..1 scale:
/// - title (0–0.45): exact normalized match, then containment
/// - artist (0–0.35): exact normalized match, then containment/token overlap
/// - duration (0–0.15): proximity so studio/live/remastered versions stay
///   distinguishable
/// - +0.05 bonus for synced lyrics (capped at 1.0)
///
/// If [query.artist] is non-empty, the candidate MUST have positive artist
/// match confidence; unrelated artists with identical song titles are
/// disqualified immediately (return 0.0).
double scoreLyricsCandidate(LyricsQuery query, LyricsCandidate candidate) {
  final normalizedQueryTitle = normalizeTrackTitle(query.title);
  final normalizedCandidateTitle = normalizeTrackTitle(candidate.trackName);
  var score = 0.0;

  if (normalizedQueryTitle.isEmpty || normalizedCandidateTitle.isEmpty) {
    return 0.0;
  }

  if (normalizedCandidateTitle == normalizedQueryTitle) {
    score += 0.45;
  } else if (normalizedCandidateTitle.contains(normalizedQueryTitle) ||
      normalizedQueryTitle.contains(normalizedCandidateTitle)) {
    // Partial containment — long descriptive queries against short
    // canonical titles still deserve credit.
    score += 0.30;
  }

  final normalizedQueryArtist = normalizeArtistName(query.artist);
  final normalizedCandidateArtist = normalizeArtistName(candidate.artistName);

  var artistScore = 0.0;
  if (normalizedQueryArtist.isNotEmpty &&
      normalizedCandidateArtist.isNotEmpty) {
    if (normalizedCandidateArtist == normalizedQueryArtist) {
      artistScore = 0.35;
    } else if (normalizedCandidateArtist.contains(normalizedQueryArtist) ||
        normalizedQueryArtist.contains(normalizedCandidateArtist)) {
      artistScore = 0.25;
    } else {
      // Shared non-stopword tokens (e.g. "Arijit Singh" vs "Singh, Arijit").
      final queryTokens = normalizedQueryArtist
          .split(' ')
          .where((t) => t.isNotEmpty && !_artistStopWords.contains(t))
          .toSet();
      final candidateTokens = normalizedCandidateArtist
          .split(' ')
          .where((t) => t.isNotEmpty && !_artistStopWords.contains(t))
          .toSet();
      if (queryTokens.isNotEmpty &&
          candidateTokens.isNotEmpty &&
          queryTokens.intersection(candidateTokens).isNotEmpty) {
        artistScore = 0.15;
      }
    }

    // When query artist is given, a candidate with zero artist confidence
    // is disqualified to prevent false positive matches on common titles.
    if (artistScore == 0.0) {
      return 0.0;
    }
  }

  score += artistScore;

  final querySeconds = query.plausibleSeconds;
  final candidateSeconds = candidate.durationSeconds;
  if (querySeconds != null && candidateSeconds != null && candidateSeconds > 0) {
    final difference = (querySeconds - candidateSeconds).abs();
    if (difference <= 2) {
      score += 0.15;
    } else if (difference <= 7) {
      score += 0.08;
    }
    // Greater differences receive 0 bonus to separate versions.
  }

  if (candidate.hasSynced) score += 0.05;

  return score.clamp(0.0, 1.0);
}

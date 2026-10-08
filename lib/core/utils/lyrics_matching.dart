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
const List<String> _junkPhrases = [
  'official video',
  'official music video',
  'official audio',
  'official visualizer',
  'official lyric video',
  'lyric video',
  'lyrics',
  'lyrics video',
  'audio',
  'video',
  'visualizer',
  'mv',
  'm/v',
  'hd',
  'hq',
  '4k',
  'remaster', // also matches "remastered" via prefix matching below
  'color coded',
  'explicit',
  'clean',
  'performance video',
  'live', // "(Live)" — LRCLIB keeps live versions distinct via duration
  'snippet',
  'preview',
  'full episode', // music-show uploads ("BRS Episode 3")
];

/// Regex for bracketed/parenthesized segments: (…), […], {…}
final RegExp _bracketSegment = RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]');

/// Strip the noise that keeps YouTube titles from matching clean track
/// names: bracketed junk segments, trailing "ft. …" suffixes (both
/// bracketed and dash-separated), separators and extra whitespace.
///
/// "Shape of You (Official Video)" -> "shape of you"
/// "Levitating (feat. DaBaby)"     -> "levitating"
/// "Blinding Lights [Lyrics]"      -> "blinding lights"
String normalizeTrackTitle(String rawTitle) {
  var title = rawTitle.trim();

  // Repeatedly drop bracketed segments whose content is junk. Iterative
  // because tags nest or stack: "(Official Video) [HD]".
  for (var pass = 0; pass < 4; pass++) {
    var changed = false;
    title = title.replaceAllMapped(_bracketSegment, (match) {
      final inner = match.group(0)!
          .substring(1, match.group(0)!.length - 1)
          .trim()
          .toLowerCase();
      // Keep segments that look like real title content (e.g. "(Live from
      // Paris)" or "(Deluxe)").
      final isJunk = _junkPhrases.any(
        (phrase) => inner == phrase || inner.startsWith('$phrase '),
      );
      changed = changed || isJunk;
      return isJunk ? ' ' : match.group(0)!;
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
  var text = input.trim();
  var previous = '';
  while (text != previous) {
    previous = text;
    text = text.replaceAll(
      RegExp(
        r'[\(\[\{]?\s*(feat\.?|ft\.?|featuring)\s+.*$',
        caseSensitive: false,
      ),
      '',
    ).trim();
    // "(with X)" / "[with X]" at the very end — bracketed only, so plain
    // titles like "With or Without You" are never touched.
    text = text.replaceAll(
      RegExp(r'\s*[\(\[\{]\s*with\s+.*[\)\]\}]\s*$', caseSensitive: false),
      '',
    ).trim();
  }
  return text;
}

/// Strip channel artifacts from artist names: " - Topic" and "VEVO".
String normalizeArtistName(String rawArtist) {
  var artist = rawArtist.trim();
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
    .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Parse an LRC document into timed lines. Handles multiple timestamps per
/// line (`[00:12.00][00:45.10]text`), comma decimal separators
/// (`[00:12,50]`), and skips metadata lines ([ti:], [ar:] …) and empty
/// lines.
List<LyricLine> parseLrc(String lrc) {
  final lines = <LyricLine>[];
  final timestamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.,:](\d{1,3}))?\]');

  for (final rawLine in lrc.split('\n')) {
    final matches = timestamp.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;

    final text = rawLine.substring(matches.last.end).trim();
    if (text.isEmpty) continue;

    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3) ?? '0';
      final milliseconds = int.parse(fraction.padRight(3, '0').substring(0, 3));
      lines.add(LyricLine(
        startTimeMs: (minutes * 60 + seconds) * 1000 + milliseconds,
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
const double lyricsAcceptScore = 0.55;

/// Score how well a candidate matches the query on a 0..1 scale:
/// - title (0–0.5): exact normalized match, then containment
/// - artist (0–0.3): exact normalized match, then any-token overlap
/// - duration (0–0.2): proximity so studio/live/remastered versions stay
///   distinguishable
/// - +0.05 bonus for synced lyrics (capped at 1.0)
double scoreLyricsCandidate(LyricsQuery query, LyricsCandidate candidate) {
  final normalizedQueryTitle = normalizeTrackTitle(query.title);
  final normalizedCandidateTitle = normalizeTrackTitle(candidate.trackName);
  var score = 0.0;

  if (normalizedQueryTitle.isEmpty || normalizedCandidateTitle.isEmpty) {
    return 0.0;
  }

  if (normalizedCandidateTitle == normalizedQueryTitle) {
    score += 0.5;
  } else if (normalizedCandidateTitle.contains(normalizedQueryTitle) ||
      normalizedQueryTitle.contains(normalizedCandidateTitle)) {
    // Partial containment — long descriptive queries against short
    // canonical titles still deserve credit.
    score += 0.35;
  }

  final normalizedQueryArtist = normalizeArtistName(query.artist);
  final normalizedCandidateArtist = normalizeArtistName(candidate.artistName);
  if (normalizedQueryArtist.isNotEmpty &&
      normalizedCandidateArtist.isNotEmpty) {
    if (normalizedCandidateArtist == normalizedQueryArtist) {
      score += 0.3;
    } else {
      // Any shared artist token (e.g. "Arijit Singh" vs "Singh, Arijit").
      final queryTokens = normalizedQueryArtist.split(' ').toSet();
      final candidateTokens = normalizedCandidateArtist.split(' ').toSet();
      if (queryTokens.intersection(candidateTokens).isNotEmpty) {
        score += 0.15;
      }
    }
  }

  final querySeconds = query.plausibleSeconds;
  final candidateSeconds = candidate.durationSeconds;
  if (querySeconds != null && candidateSeconds != null && candidateSeconds > 0) {
    final difference = (querySeconds - candidateSeconds).abs();
    if (difference <= 2) {
      score += 0.2;
    } else if (difference <= 7) {
      score += 0.12;
    } else {
      // Right title, wrong version (live vs studio) — heavy penalty.
      score += 0.02;
    }
  }

  if (candidate.hasSynced) score += 0.05;

  return score.clamp(0.0, 1.0);
}

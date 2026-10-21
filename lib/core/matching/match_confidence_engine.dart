import 'dart:math';
import '../../../domain/entities/song.dart';

/// Detailed result of evaluating how well an alternative candidate matches
/// a target song.
class MatchResult {
  /// Composite score between 0.0 and 1.0.
  final double score;

  /// Whether the match meets or exceeds the confidence threshold
  /// and passes all safety gates (duration, version, artist).
  final bool isAcceptable;

  /// Absolute duration discrepancy between target and candidate.
  final Duration durationDelta;

  /// Cleaned/normalized target title.
  final String targetTitle;

  /// Cleaned/normalized candidate title.
  final String candidateTitle;

  /// Cleaned/normalized candidate artist.
  final String candidateArtist;

  /// Human-readable explanations of why the candidate was accepted/rejected.
  final List<String> reasons;

  /// Identified provenance tag (e.g. 'jiosaavn_matched', 'piped_fallback').
  final String? provenance;

  const MatchResult({
    required this.score,
    required this.isAcceptable,
    required this.durationDelta,
    required this.targetTitle,
    required this.candidateTitle,
    required this.candidateArtist,
    required this.reasons,
    this.provenance,
  });

  @override
  String toString() =>
      'MatchResult(score: ${score.toStringAsFixed(2)}, acceptable: $isAcceptable, '
      'delta: ${durationDelta.inSeconds}s, candidate: "$candidateTitle" by "$candidateArtist")';
}

/// Production-ready confidence and provenance engine that prevents
/// incorrect song substitutions, live/remix cut mismatches, and
/// false-positive audio substitutions.
class MatchConfidenceEngine {
  /// Baseline confidence threshold required to treat candidate as a valid match.
  static const double defaultThreshold = 0.75;

  /// Maximum allowed duration discrepancy for identical studio tracks.
  static const int maxAllowedDurationDeltaSeconds = 15;

  /// Strict duration delta where tracks receive full duration credit.
  static const int strictDurationDeltaSeconds = 5;

  /// Tags that commonly trail YouTube / streaming music titles inside brackets or
  /// parentheses, case-insensitively.
  static const List<String> _junkPhrases = [
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
    'color coded',
    'explicit',
    'clean',
    'performance video',
    'snippet',
    'preview',
    'full episode',
    '가사', // Korean: lyrics
    '뮤직비디오', // Korean: music video
    '歌詞', // Japanese/Chinese: lyrics
    '官方mv', // Chinese: official MV
    '完整版', // Chinese: full version
  ];

  /// Keywords indicating specific recordings/edits that must not be substituted
  /// for standard/studio tracks.
  static const Set<String> _versionKeywords = {
    'remix',
    'live',
    'cover',
    'acoustic',
    'instrumental',
    'karaoke',
    'tribute',
    'slowed',
    'reverb',
    'sped up',
    'lofi',
    'lo-fi',
    'mashup',
    'unplugged',
    'orchestral',
    'radio edit',
    'extended mix',
    'club mix',
  };

  /// Common artist stop-words.
  static const Set<String> _artistStopWords = {
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
    'topic',
    'vevo',
  };

  /// Bracket regex supporting standard and full-width/CJK brackets.
  static final RegExp _bracketSegment = RegExp(
    r'[\(\[\{\uFF08\uFF3B\uFF5B\u3010\u3014\u300A\u300C\u300E\u3016\u3008]'
    r'[^\)\]\}\uFF09\uFF3D\uFF5D\u3011\u3015\u300B\u300D\u300F\u3017\u3009]*'
    r'[\)\]\}\uFF09\uFF3D\uFF5D\u3011\u3015\u300B\u300D\u300F\u3017\u3009]',
  );

  /// Convenience evaluation comparing two [Song] entities.
  static MatchResult evaluateSong({
    required Song target,
    required Song candidate,
    double threshold = defaultThreshold,
    String? provenance,
  }) {
    return evaluate(
      target: target,
      candidateTitleRaw: candidate.title,
      candidateArtistRaw: candidate.artist,
      candidateDuration: candidate.duration,
      threshold: threshold,
      provenance: provenance,
    );
  }

  /// Evaluate match confidence between a [target] song and candidate metadata.
  static MatchResult evaluate({
    required Song target,
    required String candidateTitleRaw,
    required String candidateArtistRaw,
    required Duration candidateDuration,
    double threshold = defaultThreshold,
    String? provenance,
  }) {
    final reasons = <String>[];
    final cleanTargetTitle = cleanTitle(target.title);
    final cleanCandidateTitle = cleanTitle(candidateTitleRaw);

    if (cleanCandidateTitle.isEmpty || cleanTargetTitle.isEmpty) {
      return MatchResult(
        score: 0.0,
        isAcceptable: false,
        durationDelta: Duration.zero,
        targetTitle: cleanTargetTitle,
        candidateTitle: cleanCandidateTitle,
        candidateArtist: cleanArtist(candidateArtistRaw),
        reasons: ['Empty normalized title'],
        provenance: provenance,
      );
    }

    // 1. Version gate: ensure candidate doesn't introduce unwanted remixes, live, etc.
    final targetVersions = extractVersionTags(target.title);
    final candidateVersions = extractVersionTags(candidateTitleRaw);

    final unwantedVersions = candidateVersions.difference(targetVersions);
    if (unwantedVersions.isNotEmpty) {
      reasons.add('Version mismatch: candidate has unwanted tag(s) ${unwantedVersions.toList()}');
      return MatchResult(
        score: 0.0,
        isAcceptable: false,
        durationDelta: Duration.zero,
        targetTitle: cleanTargetTitle,
        candidateTitle: cleanCandidateTitle,
        candidateArtist: cleanArtist(candidateArtistRaw),
        reasons: reasons,
        provenance: provenance,
      );
    }

    final missingVersions = targetVersions.difference(candidateVersions);
    if (missingVersions.isNotEmpty) {
      reasons.add('Version mismatch: candidate lacks required tag(s) ${missingVersions.toList()}');
      return MatchResult(
        score: 0.0,
        isAcceptable: false,
        durationDelta: Duration.zero,
        targetTitle: cleanTargetTitle,
        candidateTitle: cleanCandidateTitle,
        candidateArtist: cleanArtist(candidateArtistRaw),
        reasons: reasons,
        provenance: provenance,
      );
    }

    // 2. Duration Gate
    final targetDurationSec = target.duration.inSeconds;
    final candidateDurationSec = candidateDuration.inSeconds;
    final deltaSec = (targetDurationSec - candidateDurationSec).abs();
    final durationDelta = Duration(seconds: deltaSec);

    double durationScore = 0.5; // neutral if duration unknown
    if (targetDurationSec >= 30 && candidateDurationSec > 0) {
      if (deltaSec > maxAllowedDurationDeltaSeconds) {
        reasons.add('Duration discrepancy too high ($deltaSec seconds > $maxAllowedDurationDeltaSeconds max)');
        return MatchResult(
          score: 0.0,
          isAcceptable: false,
          durationDelta: durationDelta,
          targetTitle: cleanTargetTitle,
          candidateTitle: cleanCandidateTitle,
          candidateArtist: cleanArtist(candidateArtistRaw),
          reasons: reasons,
          provenance: provenance,
        );
      } else if (deltaSec <= strictDurationDeltaSeconds) {
        durationScore = 1.0;
        reasons.add('Duration exact/within ${strictDurationDeltaSeconds}s ($deltaSec sec delta)');
      } else if (deltaSec <= 10) {
        durationScore = 0.8;
        reasons.add('Duration close ($deltaSec sec delta)');
      } else {
        durationScore = 0.4;
        reasons.add('Duration acceptable with slight variation ($deltaSec sec delta)');
      }
    }

    // 3. Title Similarity (Token Jaccard + Levenshtein fuzzy)
    final titleScore = calculateTitleSimilarity(cleanTargetTitle, cleanCandidateTitle);
    reasons.add('Title similarity: ${(titleScore * 100).toStringAsFixed(1)}%');

    if (titleScore < 0.35) {
      reasons.add('Title similarity below minimum allowable 35%');
      return MatchResult(
        score: 0.0,
        isAcceptable: false,
        durationDelta: durationDelta,
        targetTitle: cleanTargetTitle,
        candidateTitle: cleanCandidateTitle,
        candidateArtist: cleanArtist(candidateArtistRaw),
        reasons: reasons,
        provenance: provenance,
      );
    }

    // 4. Artist Similarity
    final cleanTargetArtist = cleanArtist(target.artist);
    final cleanCandidateArtist = cleanArtist(candidateArtistRaw);
    double artistScore = 0.5; // neutral if artist unknown

    final isKnownTargetArtist = cleanTargetArtist.isNotEmpty &&
        cleanTargetArtist != 'unknown' &&
        cleanTargetArtist != 'various artists';

    final isKnownCandidateArtist = cleanCandidateArtist.isNotEmpty &&
        cleanCandidateArtist != 'unknown' &&
        cleanCandidateArtist != 'various artists';

    if (isKnownTargetArtist) {
      artistScore = calculateArtistSimilarity(cleanTargetArtist, cleanCandidateArtist);
      reasons.add('Artist similarity: ${(artistScore * 100).toStringAsFixed(1)}%');

      // If both target and candidate have known artists, but ZERO overlap,
      // strictly disqualify to prevent false positive matches on common titles
      // (e.g. "Hello" by Adele vs "Hello" by Lionel Richie).
      if (isKnownCandidateArtist && artistScore <= 0.05) {
        reasons.add('Strict artist mismatch: target "$cleanTargetArtist" vs candidate "$cleanCandidateArtist"');
        return MatchResult(
          score: 0.0,
          isAcceptable: false,
          durationDelta: durationDelta,
          targetTitle: cleanTargetTitle,
          candidateTitle: cleanCandidateTitle,
          candidateArtist: cleanCandidateArtist,
          reasons: reasons,
          provenance: provenance,
        );
      }
    }

    // 5. Composite Score Calculation
    // Title: 45%, Artist: 35%, Duration: 20%
    final compositeScore = (titleScore * 0.45) + (artistScore * 0.35) + (durationScore * 0.20);
    final clampedScore = double.parse(compositeScore.clamp(0.0, 1.0).toStringAsFixed(4));
    final isAcceptable = clampedScore >= threshold;

    if (isAcceptable) {
      reasons.add('Match passed confidence threshold (${(clampedScore * 100).toStringAsFixed(1)}% >= ${(threshold * 100).toInt()}%)');
    } else {
      reasons.add('Match score ${(clampedScore * 100).toStringAsFixed(1)}% below required ${(threshold * 100).toInt()}%');
    }

    return MatchResult(
      score: clampedScore,
      isAcceptable: isAcceptable,
      durationDelta: durationDelta,
      targetTitle: cleanTargetTitle,
      candidateTitle: cleanCandidateTitle,
      candidateArtist: cleanCandidateArtist,
      reasons: reasons,
      provenance: provenance,
    );
  }

  /// Evaluate from a generic map payload (e.g. JioSaavn or YouTube search result).
  static MatchResult evaluateMap({
    required Song target,
    required Map<String, dynamic> candidateMap,
    double threshold = defaultThreshold,
    String? provenance,
  }) {
    final title = candidateMap['title']?.toString() ??
        candidateMap['song']?.toString() ??
        candidateMap['name']?.toString() ??
        '';

    final moreInfo = candidateMap['more_info'] as Map<String, dynamic>?;
    final primaryArtists = moreInfo?['primary_artists']?.toString() ??
        candidateMap['primaryArtists']?.toString() ??
        candidateMap['primary_artists']?.toString();
    final singers = moreInfo?['singers']?.toString() ??
        candidateMap['singers']?.toString();
    final directArtist = candidateMap['artist']?.toString();
    final subtitle = candidateMap['subtitle']?.toString();

    final String artist;
    if (primaryArtists != null && primaryArtists.trim().isNotEmpty) {
      artist = primaryArtists.trim();
    } else if (singers != null && singers.trim().isNotEmpty) {
      artist = singers.trim();
    } else if (directArtist != null && directArtist.trim().isNotEmpty) {
      artist = directArtist.trim();
    } else if (subtitle != null && subtitle.trim().isNotEmpty) {
      final split = subtitle.split('-');
      artist = split.first.trim();
    } else {
      artist = '';
    }

    final rawDuration = moreInfo?['duration'] ?? candidateMap['duration'];
    final durationSeconds = int.tryParse(rawDuration?.toString() ?? '0') ?? 0;

    return evaluate(
      target: target,
      candidateTitleRaw: title,
      candidateArtistRaw: artist,
      candidateDuration: Duration(seconds: durationSeconds),
      threshold: threshold,
      provenance: provenance,
    );
  }

  static String _unescapeHtml(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  /// Clean title by removing junk tags, bracketed suffixes, and collapsing spaces.
  static String cleanTitle(String raw) {
    var title = _unescapeHtml(raw).replaceAll('\u3000', ' ').trim();

    // Repeatedly drop bracketed junk and soundtrack segments
    for (var pass = 0; pass < 3; pass++) {
      var changed = false;
      title = title.replaceAllMapped(_bracketSegment, (match) {
        final fullMatch = match.group(0)!;
        final inner = fullMatch
            .substring(1, fullMatch.length - 1)
            .trim()
            .toLowerCase();

        final isSoundtrackCredit = inner.startsWith('from ') ||
            inner.startsWith('from:') ||
            inner.startsWith('from"') ||
            inner.startsWith("from'") ||
            inner.startsWith('फ्रॉम') ||
            inner.startsWith('ost') ||
            inner.startsWith('soundtrack') ||
            inner.startsWith('original motion picture soundtrack');

        final isJunk = isSoundtrackCredit || _junkPhrases.any(
          (phrase) =>
              inner == phrase ||
              inner.startsWith('$phrase ') ||
              inner.startsWith('$phrase:') ||
              inner.startsWith('$phrase"') ||
              inner.startsWith("$phrase'"),
        );
        changed = changed || isJunk;
        return isJunk ? ' ' : fullMatch;
      });
      if (!changed) break;
    }

    // Strip trailing feat / ft / with
    title = title.replaceAll(
      RegExp(r'[\(\[\{\uFF08\uFF3B\u3010]?\s*(feat\.?|ft\.?|featuring)\s+.*$', caseSensitive: false),
      '',
    );
    title = title.replaceAll(RegExp(r'\s*[-–—|]\s*$'), '');

    return _collapseUnicode(title);
  }

  /// Clean artist by removing channel artifacts and stop words.
  static String cleanArtist(String raw) {
    var artist = _unescapeHtml(raw).replaceAll('\u3000', ' ').trim();
    artist = artist.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '');
    artist = artist.replaceAll(RegExp(r'VEVO$', caseSensitive: false), '');
    return _collapseUnicode(artist);
  }

  /// Extract version signatures (live, remix, acoustic, cover, etc.).
  static Set<String> extractVersionTags(String raw) {
    final lower = raw.toLowerCase();
    final tags = <String>{};
    for (final kw in _versionKeywords) {
      if (lower.contains(kw)) {
        tags.add(kw);
      }
    }
    return tags;
  }

  /// Calculate title similarity combining token overlap, subset coverage, and Levenshtein distance.
  static double calculateTitleSimilarity(String cleanA, String cleanB) {
    if (cleanA.isEmpty || cleanB.isEmpty) return 0.0;
    if (cleanA == cleanB) return 1.0;

    // Substring containment check: if one is entirely within the other
    if (cleanA.contains(cleanB) || cleanB.contains(cleanA)) {
      final ratio = min(cleanA.length, cleanB.length) / max(cleanA.length, cleanB.length);
      if (ratio > 0.6) return max(0.85, ratio);
    }

    final tokensA = cleanA.split(' ').where((t) => t.isNotEmpty).toSet();
    final tokensB = cleanB.split(' ').where((t) => t.isNotEmpty).toSet();

    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

    // Token Jaccard
    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    final jaccard = union > 0 ? intersection / union : 0.0;

    // Subset coverage: when all tokens of the shorter title are present in the longer title
    // (e.g. "봄날" inside "봄날 spring day")
    final minTokens = min(tokensA.length, tokensB.length);
    final coverage = minTokens > 0 ? intersection / minTokens : 0.0;

    if (coverage == 1.0) {
      final tokenRatio = minTokens / max(tokensA.length, tokensB.length);
      return max(0.80, 0.70 + (tokenRatio * 0.25));
    }

    // Levenshtein similarity on character sequence
    final editDist = _levenshtein(cleanA, cleanB);
    final maxLen = max(cleanA.length, cleanB.length);
    final charSimilarity = maxLen > 0 ? (1.0 - (editDist / maxLen)) : 0.0;

    // 50% Coverage + 30% Jaccard + 20% Char similarity
    return (coverage * 0.50) + (jaccard * 0.30) + (charSimilarity * 0.20);
  }

  /// Calculate artist similarity across multi-artist tokens.
  static double calculateArtistSimilarity(String cleanA, String cleanB) {
    if (cleanA.isEmpty || cleanB.isEmpty) return 0.5;
    if (cleanA == cleanB) return 1.0;

    // Lead artist match (candidate starts with target artist or vice versa)
    if (cleanB.startsWith(cleanA) || cleanA.startsWith(cleanB)) {
      return 1.0;
    }

    if (cleanA.contains(cleanB) || cleanB.contains(cleanA)) {
      return 0.90;
    }

    final tokensA = cleanA
        .split(' ')
        .where((t) => t.length >= 2 && !_artistStopWords.contains(t))
        .toSet();
    final tokensB = cleanB
        .split(' ')
        .where((t) => t.length >= 2 && !_artistStopWords.contains(t))
        .toSet();

    if (tokensA.isEmpty || tokensB.isEmpty) return 0.2;

    final matches = tokensA.intersection(tokensB).length;
    if (matches > 0) {
      final coverage = matches / min(tokensA.length, tokensB.length);
      return (coverage * 0.7) + 0.3; // between 0.3 and 1.0
    }

    return 0.0;
  }

  /// Unicode-aware string normalizer that preserves non-Latin scripts
  /// (Devanagari, Tamil, Telugu, CJK, Hangul, Cyrillic, Arabic, etc.).
  static String _collapseUnicode(String input) {
    return input
        .toLowerCase()
        .replaceAll('\u3000', ' ')
        // Preserve all Unicode letters (\p{L}), marks (\p{M}), numbers (\p{N}), and spaces
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Fast Levenshtein distance calculation.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = (a.codeUnitAt(i) == b.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[b.length];
  }
}

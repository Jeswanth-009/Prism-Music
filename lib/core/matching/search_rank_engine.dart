import 'dart:math' as math;

import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/search_results_bundle.dart';
import '../../domain/entities/song.dart';

/// Clean-room ranking engine for search results.
/// Evaluates queries against songs, artists, and albums using title normalization,
/// core title extraction, knockoff penalization, and category weighting.
class SearchRankEngine {
  static final RegExp _bracketedRegex = RegExp(r'\s*[(\[][^()\[\]]*[)\]]');
  static final RegExp _dashTailRegex = RegExp(r'\s+-\s+.*$');
  static final RegExp _knockoffRegex = RegExp(
    r'\b(instrumental|karaoke|cover|tribute|sped up|slowed|nightcore|8d|lofi|lo fi|piano version|remix|mashup|bootleg)\b',
    caseSensitive: false,
  );

  /// Lowercases string, cleans accents, maps & to and, removes punctuation.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    var s = input.toLowerCase().trim();
    s = s.replaceAll('&', ' and ');
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extracts the core title by stripping bracketed versions and dash tails:
  /// e.g. "1989 (Taylor's Version)" -> "1989", "Song - Remastered" -> "Song".
  static String coreTitle(String title) {
    final stripped = title.replaceAll(_bracketedRegex, '').replaceAll(_dashTailRegex, '');
    return normalize(stripped);
  }

  /// Checks if the title contains knockoff markers (karaoke, cover, sped up, etc.)
  /// that were NOT explicitly typed by the user in the query.
  static bool hasKnockoffMarkers(String title, String normalizedQuery) {
    final tails = [
      ..._bracketedRegex.allMatches(title).map((m) => m.group(0) ?? ''),
      ..._dashTailRegex.allMatches(title).map((m) => m.group(0) ?? ''),
    ].join(' ');

    final knockoffMatches = _knockoffRegex.allMatches(tails).map((m) => m.group(0)?.toLowerCase() ?? '');
    final queryTokens = normalizedQuery.split(' ').toSet();

    return knockoffMatches.any((marker) => !queryTokens.contains(marker));
  }

  /// Calculates initials of a multi-word phrase: e.g. "A Day To Remember" -> "adtr".
  static String? initialsOf(String title) {
    final words = coreTitle(title).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return null;
    return words.map((w) => w[0]).join();
  }

  /// Computes string similarity score (0.0 to 1.0) between query and candidate title.
  static double matchScore(String query, String title, {String extra = ''}) {
    final q = normalize(query);
    if (q.isEmpty) return 0.0;
    final t = normalize(title);
    if (t == q) return 1.0;

    final c = coreTitle(title);
    if (c == q) {
      return hasKnockoffMarkers(title, q) ? 0.70 : 0.98;
    }

    final qWords = q.split(' ').where((w) => w.isNotEmpty).toList();
    final combinedTokens = normalize('$title $extra').split(' ').toSet();

    // Query covers both title and artist ("do i wanna know arctic monkeys")
    if (qWords.every((w) => combinedTokens.contains(w)) &&
        c.split(' ').every((w) => qWords.contains(w))) {
      return 0.95;
    }

    // Initials match (e.g. "adtr" -> "A Day To Remember")
    final initials = initialsOf(title);
    if (initials != null && initials == q) {
      return 0.90;
    }

    if (t.startsWith(q)) return 0.75;
    if (qWords.every((w) => combinedTokens.any((t) => t.startsWith(w)))) {
      return 0.60;
    }
    if (t.contains(q)) return 0.45;

    return 0.20;
  }

  /// Evaluates and selects the authoritative top result from raw search candidates.
  static SearchTopResult? evaluateTopResult({
    required String query,
    required List<Song> songs,
    required List<Artist> artists,
    required List<Album> albums,
    List<Playlist> playlists = const [],
  }) {
    final q = normalize(query);
    if (q.isEmpty) return null;

    double bestScore = -1.0;
    SearchTopResult? bestCandidate;

    // 1. Evaluate top songs
    for (int i = 0; i < math.min(songs.length, 5); i++) {
      final song = songs[i];
      final m = matchScore(query, song.title, extra: song.artist);
      final weight = (song.source == MusicSource.jiosaavn) ? 0.92 : 0.88;
      final score = m * weight - (i * 0.04);

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = SearchTopResult.song(song);
      }
    }

    // 2. Evaluate top artists
    for (int i = 0; i < math.min(artists.length, 3); i++) {
      final artist = artists[i];
      final m = matchScore(query, artist.name);
      final weight = 0.95;
      final score = m * weight - (i * 0.04);

      // Give exact artist match strong priority unless a hit song exact matches
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = SearchTopResult.artist(artist);
      }
    }

    // 3. Evaluate top albums
    for (int i = 0; i < math.min(albums.length, 3); i++) {
      final album = albums[i];
      final m = matchScore(query, album.title, extra: album.artist);
      final weight = 0.90;
      final score = m * weight - (i * 0.04);

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = SearchTopResult.album(album);
      }
    }

    return bestCandidate;
  }

  /// Sorts songs so exact matches and non-knockoffs rank first.
  static List<Song> rankSongs(List<Song> songs, String query) {
    final q = normalize(query);
    final ranked = List<Song>.from(songs);

    ranked.sort((a, b) {
      final scoreA = matchScore(query, a.title, extra: a.artist);
      final scoreB = matchScore(query, b.title, extra: b.artist);

      final isKnockoffA = hasKnockoffMarkers(a.title, q);
      final isKnockoffB = hasKnockoffMarkers(b.title, q);

      if (isKnockoffA != isKnockoffB) {
        return isKnockoffA ? 1 : -1;
      }
      return scoreB.compareTo(scoreA);
    });

    return ranked;
  }
}

import 'package:dio/dio.dart';

import '../../../../core/utils/lyrics_matching.dart';
import '../../../../domain/entities/entities.dart';
import 'lyrics_local_cache.dart';

/// Data source for fetching lyrics from LRCLIB (free, no API key required).
///
/// Lookup strategy:
/// 1. Local cache of previous successful lookups.
/// 2. LRCLIB `/get` — exact match, with the song duration when plausible so
///    studio, live and remastered versions stay distinguishable.
/// 3. LRCLIB `/search` — candidate list, scored on title / artist /
///    duration proximity.
///
/// A second provider will only be added if its licensing and API terms
/// permit redistribution.
abstract class LyricsDataSource {
  /// Get synced lyrics for a song
  Future<Lyrics?> getSyncedLyrics(
    String title,
    String artist, {
    Duration? duration,
    bool forceRefresh = false,
  });

  /// Get plain text lyrics for a song
  Future<String?> getPlainLyrics(String title, String artist);
}

/// Thrown when the lyrics service is unreachable or encounters an outage
/// (5xx, timeouts, connection errors).
class LyricsOutageException implements Exception {
  final String message;
  const LyricsOutageException(this.message);

  @override
  String toString() => 'LyricsOutageException: $message';
}

/// Implementation using the public LRCLIB API.
class LyricsDataSourceImpl implements LyricsDataSource {
  final Dio _dio;
  final LyricsLocalCache _cache;

  LyricsDataSourceImpl({required Dio dio, LyricsLocalCache? cache})
      : _dio = dio,
        _cache = cache ?? LyricsLocalCache();

  static const String _lrclibBaseUrl = 'https://lrclib.net/api';

  /// LRCLIB asks automated clients to identify themselves; the shared Dio
  /// keeps its browser UA for other providers, so override per request.
  static const Map<String, String> _lrclibHeaders = {
    'User-Agent': 'PrismMusic/1.0 (https://github.com/Jeswanth-009/Prism-Music)',
  };

  @override
  Future<Lyrics?> getSyncedLyrics(
    String title,
    String artist, {
    Duration? duration,
    bool forceRefresh = false,
  }) async {
    final songId = '${artist}_$title';

    if (!forceRefresh) {
      final cached = await _cache.get(
        title,
        artist,
        songId,
        duration: duration,
      );
      if (cached != null) return cached;
    }

    final query = LyricsQuery(title: title, artist: artist, duration: duration);

    // 1. Exact lookup. Duration only when plausible — YouTube-sourced songs
    //    sometimes carry 0 or a placeholder that would poison matching.
    final exact = await _fetchFromGet(query);
    if (exact != null) {
      await _cacheSuccess(title, artist, exact, duration: duration);
      return exact;
    }

    // 2. Candidate search with scoring.
    final scored = await _fetchFromSearch(query);
    if (scored != null) {
      await _cacheSuccess(title, artist, scored, duration: duration);
      return scored;
    }

    return null;
  }

  @override
  Future<String?> getPlainLyrics(String title, String artist) async {
    final lyrics = await getSyncedLyrics(title, artist);
    return lyrics?.plainLyrics;
  }

  Future<Lyrics?> _fetchFromGet(LyricsQuery query) async {
    try {
      final response = await _dio.get(
        '$_lrclibBaseUrl/get',
        queryParameters: {
          'track_name': _usable(query.title) ?? query.title,
          'artist_name': _usableArtist(query.artist) ?? query.artist,
          if (query.plausibleSeconds != null)
            'duration': query.plausibleSeconds,
        },
        options: Options(headers: _lrclibHeaders),
      );

      if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
        return null;
      }
      return _mapLrclibEntry(response.data as Map<String, dynamic>, query);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      if (_isOutage(e)) {
        throw LyricsOutageException(
          'Lyrics service temporarily unavailable (${e.response?.statusCode ?? e.type.name})',
        );
      }
      return null;
    } catch (e) {
      if (e is LyricsOutageException) rethrow;
      return null;
    }
  }

  Future<Lyrics?> _fetchFromSearch(LyricsQuery query) async {
    try {
      final response = await _dio.get(
        '$_lrclibBaseUrl/search',
        queryParameters: {
          'track_name': _usable(query.title) ?? query.title,
          'artist_name': _usableArtist(query.artist) ?? query.artist,
        },
        options: Options(headers: _lrclibHeaders),
      );

      if (response.statusCode != 200 || response.data is! List) {
        return null;
      }

      Lyrics? best;
      var bestScore = 0.0;
      for (final entry in response.data as List) {
        if (entry is! Map<String, dynamic>) continue;
        final candidate = LyricsCandidate(
          trackName: (entry['trackName'] ?? '').toString(),
          artistName: (entry['artistName'] ?? '').toString(),
          durationSeconds: (entry['duration'] as num?)?.toInt(),
          plainLyrics: entry['plainLyrics'] as String?,
          syncedLyrics: entry['syncedLyrics'] as String?,
        );
        if (!candidate.hasSynced && !candidate.hasPlain) continue;

        final score = scoreLyricsCandidate(query, candidate);
        if (score > bestScore && score >= lyricsAcceptScore) {
          bestScore = score;
          best = _lyricsFromCandidate(candidate, query);
        }
      }
      return best;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      if (_isOutage(e)) {
        throw LyricsOutageException(
          'Lyrics service temporarily unavailable (${e.response?.statusCode ?? e.type.name})',
        );
      }
      return null;
    } catch (e) {
      if (e is LyricsOutageException) rethrow;
      return null;
    }
  }

  bool _isOutage(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        (e.response?.statusCode != null && e.response!.statusCode! >= 500);
  }

  Lyrics? _mapLrclibEntry(
    Map<String, dynamic> data,
    LyricsQuery query,
  ) {
    final candidate = LyricsCandidate(
      trackName: (data['trackName'] ?? '').toString(),
      artistName: (data['artistName'] ?? '').toString(),
      durationSeconds: (data['duration'] as num?)?.toInt(),
      plainLyrics: data['plainLyrics'] as String?,
      syncedLyrics: data['syncedLyrics'] as String?,
    );
    if (!candidate.hasSynced && !candidate.hasPlain) return null;

    // /get can still return a differently-titled record (LRCLIB falls back
    // loosely) — sanity-check before accepting.
    final score = scoreLyricsCandidate(query, candidate);
    if (score < lyricsAcceptScore) return null;

    return _lyricsFromCandidate(candidate, query);
  }

  Lyrics _lyricsFromCandidate(LyricsCandidate candidate, LyricsQuery query) {
    return Lyrics(
      songId: '${query.artist}_${query.title}',
      plainLyrics: candidate.plainLyrics,
      syncedLyrics:
          candidate.hasSynced ? parseLrc(candidate.syncedLyrics!) : null,
      source: 'LRCLIB',
    );
  }

  Future<void> _cacheSuccess(
    String title,
    String artist,
    Lyrics lyrics, {
    Duration? duration,
  }) async {
    await _cache.put(
      title,
      artist,
      duration: duration,
      plainLyrics: lyrics.plainLyrics,
      syncedLrc: _encodeLrc(lyrics.syncedLyrics),
    );
  }

  /// Re-encode parsed lines back into LRC so the cache stores compact raw
  /// data that future parser upgrades can re-interpret.
  String? _encodeLrc(List<LyricLine>? lines) {
    if (lines == null || lines.isEmpty) return null;
    return lines.map((line) {
      final ms = line.startTimeMs;
      final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
      final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
      return '[$minutes:$seconds.$hundredths]${line.text}';
    }).join('\n');
  }

  /// Normalized value for an LRCLIB track title query parameter, or null when
  /// normalization emptied the string (then the caller sends the raw one).
  String? _usable(String raw) {
    final normalized = normalizeTrackTitle(raw);
    return normalized.isEmpty ? null : normalized;
  }

  /// Normalized value for an LRCLIB artist query parameter using artist-specific
  /// normalization (stripping channel suffixes like " - Topic" and "VEVO").
  String? _usableArtist(String raw) {
    final normalized = normalizeArtistName(raw);
    return normalized.isEmpty ? null : normalized;
  }
}

import 'package:dio/dio.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../../core/utils/lyrics_matching.dart';
import '../../../../../domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider querying LRCLIB (open-source community synchronized lyrics library).
class LrclibLyricsProvider implements LyricsProvider {
  final Dio _dio;
  final String _baseUrl;

  LrclibLyricsProvider({
    required Dio dio,
    String baseUrl = 'https://lrclib.net/api',
  })  : _dio = dio,
        _baseUrl = baseUrl;

  static const Map<String, String> _headers = {
    'User-Agent': 'PrismMusic/1.0 (https://github.com/Jeswanth-009/Prism-Music)',
  };

  @override
  String get id => 'lrclib';

  @override
  String get displayName => 'LRCLIB';

  @override
  LyricsSyncType get syncType => LyricsSyncType.lineSynced;

  @override
  int get priorityTier => 2;

  @override
  Future<Lyrics?> fetchLyrics(
    String title,
    String artist, {
    Duration? duration,
    String? songId,
  }) async {
    final query = LyricsQuery(title: title, artist: artist, duration: duration);

    // 1. Exact match attempt via /get
    try {
      final getResp = await _dio.get(
        '$_baseUrl/get',
        queryParameters: {
          'track_name': _usable(query.title) ?? query.title,
          'artist_name': _usableArtist(query.artist) ?? query.artist,
          if (query.plausibleSeconds != null) 'duration': query.plausibleSeconds,
        },
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (getResp.statusCode == 200 && getResp.data is Map<String, dynamic>) {
        final result = _mapLrclibEntry(getResp.data as Map<String, dynamic>, query, songId);
        if (result != null) return result;
      }
    } catch (_) {}

    // 2. Scored candidate search via /search
    try {
      final searchResp = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'track_name': _usable(query.title) ?? query.title,
          'artist_name': _usableArtist(query.artist) ?? query.artist,
        },
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (searchResp.statusCode == 200 && searchResp.data is List) {
        Lyrics? best;
        double bestScore = 0.0;
        for (final entry in searchResp.data as List) {
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
            final isSynced = candidate.hasSynced;
            best = Lyrics(
              songId: songId ?? '${query.artist}_${query.title}',
              plainLyrics: candidate.plainLyrics,
              syncedLyrics: isSynced ? parseLrc(candidate.syncedLyrics!) : null,
              source: 'LRCLIB',
              syncType: isSynced ? LyricsSyncType.lineSynced : LyricsSyncType.plain,
              providerId: id,
            );
          }
        }
        if (best != null) return best;
      }
    } catch (e) {
      logDebug('LrclibLyricsProvider: Error during search for "${query.title}": $e');
    }

    return null;
  }

  Lyrics? _mapLrclibEntry(Map<String, dynamic> data, LyricsQuery query, String? songId) {
    final plain = data['plainLyrics'] as String?;
    final synced = data['syncedLyrics'] as String?;

    if ((plain == null || plain.isEmpty) && (synced == null || synced.isEmpty)) {
      return null;
    }

    final isSynced = synced != null && synced.trim().isNotEmpty;
    return Lyrics(
      songId: songId ?? '${query.artist}_${query.title}',
      plainLyrics: plain,
      syncedLyrics: isSynced ? parseLrc(synced) : null,
      source: 'LRCLIB',
      syncType: isSynced ? LyricsSyncType.lineSynced : LyricsSyncType.plain,
      providerId: id,
    );
  }

  String? _usable(String s) {
    final trimmed = s.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }

  String? _usableArtist(String s) {
    final trimmed = s.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }
}

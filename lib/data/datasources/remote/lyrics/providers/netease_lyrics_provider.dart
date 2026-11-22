import 'package:dio/dio.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../../core/utils/lyrics_matching.dart';
import '../../../../../domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider querying NetEase Cloud Music for high-precision time-synced lyrics.
class NetEaseLyricsProvider implements LyricsProvider {
  final Dio _dio;

  NetEaseLyricsProvider({required Dio dio}) : _dio = dio;

  static const String _searchUrl = 'https://music.163.com/api/search/get/web';
  static const String _lyricUrl = 'https://music.163.com/api/song/lyric';

  static const Map<String, String> _headers = {
    'Referer': 'https://music.163.com',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  @override
  String get id => 'netease';

  @override
  String get displayName => 'NetEase';

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
    final cleanTitle = normalizeTrackTitle(title);
    final cleanArtist = normalizeArtistName(artist);
    if (cleanTitle.isEmpty) return null;

    try {
      // 1. Search NetEase for matching song ID
      final searchResp = await _dio.get(
        _searchUrl,
        queryParameters: {
          's': '$cleanTitle $cleanArtist',
          'type': 1,
          'limit': 3,
        },
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (searchResp.statusCode != 200 || searchResp.data is! Map) {
        return null;
      }

      final data = searchResp.data as Map;
      final result = data['result'];
      if (result is! Map || result['songs'] is! List) return null;

      final songs = result['songs'] as List;
      if (songs.isEmpty) return null;

      final firstSong = songs.first;
      if (firstSong is! Map) return null;

      final neteaseSongId = firstSong['id']?.toString();
      if (neteaseSongId == null) return null;

      // 2. Fetch lyrics payload by song ID
      final lyricResp = await _dio.get(
        _lyricUrl,
        queryParameters: {
          'id': neteaseSongId,
          'lv': 1,
          'kv': 1,
          'tv': -1,
        },
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (lyricResp.statusCode != 200 || lyricResp.data is! Map) {
        return null;
      }

      final lyricData = lyricResp.data as Map;
      final lrcBlock = lyricData['lrc'];
      if (lrcBlock is! Map) return null;

      final rawLyric = lrcBlock['lyric'] as String?;
      if (rawLyric == null || rawLyric.trim().isEmpty) return null;

      final parsedLines = parseLrc(rawLyric);
      if (parsedLines.isEmpty) return null;

      final plain = parsedLines.map((l) => l.text).join('\n');

      return Lyrics(
        songId: songId ?? '${cleanArtist}_$cleanTitle',
        plainLyrics: plain,
        syncedLyrics: parsedLines,
        source: 'NetEase',
        syncType: LyricsSyncType.lineSynced,
        providerId: id,
      );
    } catch (e) {
      logDebug('NetEaseLyricsProvider: Failed fetching lyrics for "$cleanTitle": $e');
      return null;
    }
  }
}

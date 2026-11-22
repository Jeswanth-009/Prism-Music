import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../../core/utils/lyrics_matching.dart';
import '../../../../../domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider querying KuGou's public search and download endpoints for time-synced lyrics.
class KuGouLyricsProvider implements LyricsProvider {
  final Dio _dio;

  KuGouLyricsProvider({required Dio dio}) : _dio = dio;

  static const String _searchUrl = 'https://lyrics.kugou.com/search';
  static const String _downloadUrl = 'https://lyrics.kugou.com/download';

  @override
  String get id => 'kugou';

  @override
  String get displayName => 'KuGou';

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
      // 1. Candidate Search
      final searchResp = await _dio.get(
        _searchUrl,
        queryParameters: {
          'ver': 1,
          'man': 'yes',
          'client': 'pc',
          'keyword': '$cleanTitle $cleanArtist',
          if (duration != null && duration.inSeconds >= 30)
            'duration': duration.inMilliseconds,
        },
        options: Options(sendTimeout: const Duration(seconds: 4)),
      );

      if (searchResp.statusCode != 200 || searchResp.data is! Map) {
        return null;
      }

      final data = searchResp.data as Map;
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;

      final firstCandidate = candidates.first;
      if (firstCandidate is! Map) return null;

      final candId = firstCandidate['id']?.toString();
      final accessKey = firstCandidate['accesskey']?.toString();
      if (candId == null || accessKey == null) return null;

      // 2. Download Lyric Payload
      final dlResp = await _dio.get(
        _downloadUrl,
        queryParameters: {
          'ver': 1,
          'client': 'pc',
          'id': candId,
          'accesskey': accessKey,
          'fmt': 'lrc',
          'charset': 'utf8',
        },
        options: Options(sendTimeout: const Duration(seconds: 4)),
      );

      if (dlResp.statusCode != 200 || dlResp.data is! Map) {
        return null;
      }

      final dlData = dlResp.data as Map;
      final base64Content = dlData['content'] as String?;
      if (base64Content == null || base64Content.isEmpty) return null;

      // Base64 decode the LRC content
      final lrcDecoded = utf8.decode(base64.decode(base64Content));
      if (lrcDecoded.trim().isEmpty) return null;

      final parsedLines = parseLrc(lrcDecoded);
      if (parsedLines.isEmpty) return null;

      final plain = parsedLines.map((l) => l.text).join('\n');

      return Lyrics(
        songId: songId ?? '${cleanArtist}_$cleanTitle',
        plainLyrics: plain,
        syncedLyrics: parsedLines,
        source: 'KuGou',
        syncType: LyricsSyncType.lineSynced,
        providerId: id,
      );
    } catch (e) {
      logDebug('KuGouLyricsProvider: Failed fetching lyrics for "$cleanTitle": $e');
      return null;
    }
  }
}

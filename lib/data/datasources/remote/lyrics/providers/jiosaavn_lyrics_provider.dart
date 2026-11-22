import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../../core/utils/lyrics_matching.dart';
import '../../../../../domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider querying JioSaavn's official lyrics API for Indian regional tracks.
class JioSaavnLyricsProvider implements LyricsProvider {
  final Dio _dio;
  static const String _baseUrl = 'https://www.jiosaavn.com/api.php';

  JioSaavnLyricsProvider({required Dio dio}) : _dio = dio;

  @override
  String get id => 'jiosaavn';

  @override
  String get displayName => 'JioSaavn';

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
      // Step 1: If songId is a JioSaavn song ID, try getLyrics directly
      String? lyricsId;
      if (songId != null && !songId.startsWith('unknown') && !songId.contains('_')) {
        lyricsId = songId;
      }

      // Step 2: Otherwise, query JioSaavn song search
      if (lyricsId == null) {
        final searchResp = await _dio.get(
          _baseUrl,
          queryParameters: {
            '__call': 'search.getResults',
            'q': '$cleanTitle $cleanArtist',
            '_format': 'json',
            '_marker': '0',
            'api_version': '4',
            'ctx': 'web6dot0',
            'p': '1',
            'n': '3',
          },
          options: Options(sendTimeout: const Duration(seconds: 4)),
        );

        if (searchResp.statusCode == 200 && searchResp.data != null) {
          dynamic data = searchResp.data;
          if (data is String) {
            data = jsonDecode(data);
          }
          if (data is Map && data['results'] is List) {
            final results = data['results'] as List;
            for (final item in results) {
              if (item is Map && (item['has_lyrics'] == 'true' || item['has_lyrics'] == true)) {
                lyricsId = item['id']?.toString();
                break;
              }
            }
          }
        }
      }

      if (lyricsId == null) return null;

      // Step 3: Fetch the lyrics payload
      final lyricsResp = await _dio.get(
        _baseUrl,
        queryParameters: {
          '__call': 'lyrics.getLyrics',
          'lyrics_id': lyricsId,
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
        },
        options: Options(sendTimeout: const Duration(seconds: 4)),
      );

      if (lyricsResp.statusCode != 200 || lyricsResp.data == null) {
        return null;
      }

      dynamic payload = lyricsResp.data;
      if (payload is String) {
        payload = jsonDecode(payload);
      }
      if (payload is! Map) return null;

      final rawText = (payload['lyrics'] ?? '').toString();
      if (rawText.trim().isEmpty) return null;

      // Clean HTML tags (<br>, <br/>, &amp;, &quot;)
      final cleanText = rawText
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&')
          .replaceAll('&apos;', "'")
          .trim();

      // Check if text has LRC timestamps [00:12.34]
      List<LyricLine>? synced;
      LyricsSyncType type = LyricsSyncType.plain;
      if (cleanText.contains(RegExp(r'\[\d{1,2}:\d{2}'))) {
        synced = parseLrc(cleanText);
        if (synced.isNotEmpty) {
          type = LyricsSyncType.lineSynced;
        }
      }

      return Lyrics(
        songId: lyricsId,
        plainLyrics: cleanText,
        syncedLyrics: synced,
        source: 'JioSaavn',
        syncType: type,
        providerId: id,
      );
    } catch (e) {
      logDebug('JioSaavnLyricsProvider: Failed fetching lyrics for "$cleanTitle": $e');
      return null;
    }
  }
}

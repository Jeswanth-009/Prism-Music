import 'package:dio/dio.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../../core/utils/lyrics_matching.dart';
import '../../../../../domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider querying the Better Lyrics public API (Apple Music-style TTML word-by-word karaoke).
class BetterLyricsProvider implements LyricsProvider {
  final Dio _dio;
  final String _baseUrl;

  BetterLyricsProvider({
    required Dio dio,
    String baseUrl = 'https://api.betterlyrics.org',
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  String get id => 'better_lyrics';

  @override
  String get displayName => 'Better Lyrics';

  @override
  LyricsSyncType get syncType => LyricsSyncType.wordSynced;

  @override
  int get priorityTier => 1;

  @override
  Future<Lyrics?> fetchLyrics(
    String title,
    String artist, {
    Duration? duration,
    String? songId,
  }) async {
    final cleanTitle = normalizeTrackTitle(title);
    final cleanArtist = normalizeArtistName(artist);
    if (cleanTitle.isEmpty || cleanArtist.isEmpty) return null;

    try {
      final response = await _dio.get(
        '$_baseUrl/getLyrics',
        queryParameters: {
          's': cleanTitle,
          'a': cleanArtist,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: const {
            'User-Agent': 'PrismMusic/1.0',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final ttml = data['ttml'] as String?;
      if (ttml == null || ttml.trim().isEmpty) return null;

      final lines = parseTtmlLyrics(ttml);
      if (lines.isEmpty) return null;

      final plain = lines.map((l) => l.text).join('\n');
      final hasWords = lines.any((l) => l.isWordSynced);

      return Lyrics(
        songId: songId ?? '${cleanArtist}_$cleanTitle',
        plainLyrics: plain,
        syncedLyrics: lines,
        source: 'Better Lyrics',
        syncType: hasWords ? LyricsSyncType.wordSynced : LyricsSyncType.lineSynced,
        providerId: id,
      );
    } on DioException catch (e) {
      logDebug('BetterLyricsProvider: Request failed for "$cleanTitle": ${e.message}');
      return null;
    } catch (e, st) {
      logError('BetterLyricsProvider: Unexpected error for "$cleanTitle"', e, st);
      return null;
    }
  }
}

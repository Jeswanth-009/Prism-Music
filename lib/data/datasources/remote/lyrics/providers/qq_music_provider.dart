import 'package:dio/dio.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../../core/utils/lyrics_matching.dart';
import '../../../../../domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider querying QQ Music for word-by-word karaoke & translated lyrics.
class QqMusicLyricsProvider implements LyricsProvider {
  final Dio _dio;
  final String _baseUrl;

  QqMusicLyricsProvider({
    required Dio dio,
    String baseUrl = 'https://lyricsplus.prjktla.my.id',
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  String get id => 'qq_music';

  @override
  String get displayName => 'QQ Music';

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
        '$_baseUrl/v2/lyrics/get',
        queryParameters: {
          'title': cleanTitle,
          'artist': cleanArtist,
          'source': 'qq',
          if (duration != null && duration.inSeconds >= 30)
            'duration': duration.inSeconds,
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
      final lines = parseLyricsPlusJson(data);
      if (lines.isEmpty) return null;

      final plain = lines.map((l) => l.text).join('\n');
      final hasWords = lines.any((l) => l.isWordSynced);

      return Lyrics(
        songId: songId ?? '${cleanArtist}_$cleanTitle',
        plainLyrics: plain,
        syncedLyrics: lines,
        source: 'QQ Music',
        syncType: hasWords ? LyricsSyncType.wordSynced : LyricsSyncType.lineSynced,
        providerId: id,
      );
    } on DioException catch (e) {
      logDebug('QqMusicLyricsProvider: Request failed for "$cleanTitle": ${e.message}');
      return null;
    } catch (e, st) {
      logError('QqMusicLyricsProvider: Error parsing lyrics for "$cleanTitle"', e, st);
      return null;
    }
  }
}

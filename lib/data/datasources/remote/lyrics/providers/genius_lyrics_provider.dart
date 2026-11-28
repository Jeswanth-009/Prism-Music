import 'package:dio/dio.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider for Genius plain text lyrics.
class GeniusLyricsProvider implements LyricsProvider {
  final Dio _dio;

  GeniusLyricsProvider({required Dio dio}) : _dio = dio;

  static const String _baseUrl = 'https://api.genius.com/search';

  @override
  String get id => 'genius';

  @override
  String get displayName => 'Genius';

  @override
  LyricsSyncType get syncType => LyricsSyncType.plain;

  @override
  int get priorityTier => 3;

  @override
  Future<Lyrics?> fetchLyrics(
    String title,
    String artist, {
    Duration? duration,
    String? songId,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    if (cleanTitle.isEmpty) return null;

    try {
      final query = '$cleanTitle $cleanArtist';
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {'q': query},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        ),
      );

      if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
        return null;
      }

      final hits = response.data['response']?['hits'] as List?;
      if (hits == null || hits.isEmpty) return null;

      final firstHit = hits.first as Map<String, dynamic>;
      final result = firstHit['result'] as Map<String, dynamic>?;
      if (result == null) return null;

      final songPath = result['path'] as String?;
      if (songPath == null) return null;

      // Genius Search API does not return full lyrics text; return null rather than
      // polluting the lyrics cache/UI with a placeholder URL string.
      return null;
    } catch (_) {
      return null;
    }
  }
}

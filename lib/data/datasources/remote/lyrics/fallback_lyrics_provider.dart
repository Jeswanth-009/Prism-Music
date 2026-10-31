import 'package:dio/dio.dart';

/// Contract for fallback lyrics providers when LRCLIB has no lyrics
/// or suffers transient downtime.
abstract class FallbackLyricsProvider {
  /// Fetch plain lyrics for a song, returning null if not found.
  Future<String?> fetchLyrics(String title, String artist);
}

/// Fallback lyrics provider querying the public lyrics.ovh API:
/// https://api.lyrics.ovh/v1/{artist}/{title}
class LyricsOvhFallbackProvider implements FallbackLyricsProvider {
  final Dio _dio;

  LyricsOvhFallbackProvider({required Dio dio}) : _dio = dio;

  static const String _baseUrl = 'https://api.lyrics.ovh/v1';

  @override
  Future<String?> fetchLyrics(String title, String artist) async {
    final cleanArtist = artist.trim();
    final cleanTitle = title.trim();
    if (cleanArtist.isEmpty || cleanTitle.isEmpty) return null;

    try {
      final encodedArtist = Uri.encodeComponent(cleanArtist);
      final encodedTitle = Uri.encodeComponent(cleanTitle);

      final response = await _dio.get(
        '$_baseUrl/$encodedArtist/$encodedTitle',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final rawLyrics = response.data['lyrics'] as String?;
        if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
          return rawLyrics.trim();
        }
      }
      return null;
    } on DioException {
      // 404, timeouts, or network issues are caught gracefully so LRCLIB
      // or other fallbacks remain unaffected.
      return null;
    } catch (_) {
      return null;
    }
  }
}

import 'package:dio/dio.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider for Unison lyrics API.
class UnisonLyricsProvider implements LyricsProvider {
  final Dio _dio;

  UnisonLyricsProvider({required Dio dio}) : _dio = dio;

  static const String _baseUrl = 'https://unison-lyrics.org/api/v1/lyrics';

  @override
  String get id => 'unison';

  @override
  String get displayName => 'Unison';

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
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    if (cleanTitle.isEmpty) return null;

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'track': cleanTitle,
          'artist': cleanArtist,
          if (duration != null) 'duration': duration.inSeconds,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final linesData = data['lyrics'] ?? data['lines'];
        if (linesData is List && linesData.isNotEmpty) {
          final lines = <LyricLine>[];
          for (final item in linesData) {
            if (item is! Map<String, dynamic>) continue;
            final lineText = (item['text'] ?? '').toString();
            final startTimeMs = (item['time'] as num?)?.toInt() ?? 0;
            lines.add(LyricLine(
              startTimeMs: startTimeMs,
              text: lineText,
            ));
          }

          return Lyrics(
            songId: songId ?? '${artist}_$title',
            plainLyrics: lines.map((l) => l.text).join('\n'),
            syncedLyrics: lines,
            source: displayName,
            syncType: LyricsSyncType.lineSynced,
            providerId: id,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

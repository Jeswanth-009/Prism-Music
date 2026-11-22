import 'package:dio/dio.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'lyrics_provider.dart';

/// Provider for Bini lyrics API (word-by-word karaoke and line-synced).
class BiniLyricsProvider implements LyricsProvider {
  final Dio _dio;

  BiniLyricsProvider({required Dio dio}) : _dio = dio;

  static const String _baseUrl = 'https://api.bini.dev/lyrics';

  @override
  String get id => 'bini';

  @override
  String get displayName => 'Bini';

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
          'title': cleanTitle,
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
        final linesData = data['lines'];
        if (linesData is List && linesData.isNotEmpty) {
          final lines = <LyricLine>[];
          for (final item in linesData) {
            if (item is! Map<String, dynamic>) continue;
            final lineText = (item['text'] ?? '').toString();
            final startTimeMs = (item['startTimeMs'] as num?)?.toInt() ?? 0;
            final wordsData = item['words'];
            List<LyricWord>? words;
            if (wordsData is List && wordsData.isNotEmpty) {
              words = [];
              for (final w in wordsData) {
                if (w is! Map<String, dynamic>) continue;
                words.add(LyricWord(
                  startTimeMs: (w['startTimeMs'] as num?)?.toInt() ?? startTimeMs,
                  endTimeMs: (w['endTimeMs'] as num?)?.toInt() ?? startTimeMs + 500,
                  text: (w['text'] ?? '').toString(),
                ));
              }
            }
            lines.add(LyricLine(
              startTimeMs: startTimeMs,
              text: lineText,
              words: words,
            ));
          }

          final plain = data['plainLyrics'] as String? ??
              lines.map((l) => l.text).join('\n');
          final isWord = lines.any((l) => l.isWordSynced);

          return Lyrics(
            songId: songId ?? '${artist}_$title',
            plainLyrics: plain,
            syncedLyrics: lines,
            source: displayName,
            syncType: isWord ? LyricsSyncType.wordSynced : LyricsSyncType.lineSynced,
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

import 'package:dio/dio.dart';
import '../../../../domain/entities/entities.dart';

/// Data source for fetching lyrics
abstract class LyricsDataSource {
  /// Get synced lyrics for a song
  Future<Lyrics?> getSyncedLyrics(
    String title,
    String artist, {
    Duration? duration,
  });

  /// Get plain text lyrics for a song
  Future<String?> getPlainLyrics(String title, String artist);
}

/// Implementation using LRCLIB (free, no API key required)
class LyricsDataSourceImpl implements LyricsDataSource {
  final Dio _dio;

  LyricsDataSourceImpl({required Dio dio}) : _dio = dio;

  static const String _lrclibBaseUrl = 'https://lrclib.net/api';

  @override
  Future<Lyrics?> getSyncedLyrics(
    String title,
    String artist, {
    Duration? duration,
  }) async {
    try {
      final response = await _dio.get(
        '$_lrclibBaseUrl/get',
        queryParameters: {
          'track_name': title,
          'artist_name': artist,
          if (duration != null) 'duration': duration.inSeconds,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Parse synced lyrics if available
        final syncedLyrics = data['syncedLyrics'] as String?;
        final plainLyrics = data['plainLyrics'] as String?;
        
        if (syncedLyrics != null || plainLyrics != null) {
          return Lyrics(
            songId: '${artist}_$title',
            plainLyrics: plainLyrics,
            syncedLyrics: syncedLyrics != null 
                ? _parseLrcLyrics(syncedLyrics) 
                : null,
            source: 'LRCLIB',
          );
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> getPlainLyrics(String title, String artist) async {
    final lyrics = await getSyncedLyrics(title, artist);
    return lyrics?.plainLyrics;
  }

  /// Parse LRC format lyrics into LyricLine list
  List<LyricLine> _parseLrcLyrics(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    
    for (final line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)?.trim() ?? '';
        
        final startTimeMs = (minutes * 60 + seconds) * 1000 + milliseconds;
        
        lines.add(LyricLine(
          startTimeMs: startTimeMs,
          text: text,
        ));
      }
    }
    
    return lines;
  }
}

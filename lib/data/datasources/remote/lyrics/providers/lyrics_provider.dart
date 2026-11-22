import 'package:prism_music/domain/entities/entities.dart';

export 'package:prism_music/domain/entities/lyrics_source_descriptor.dart';

/// Abstract contract implemented by every lyrics provider.
abstract class LyricsProvider {
  /// Unique identifier (e.g. 'better_lyrics', 'lyrics_plus', 'qq_music', 'lrclib')
  String get id;

  /// User-facing display name
  String get displayName;

  /// Highest synchronization quality provided
  LyricsSyncType get syncType;

  /// Quality priority (1 = Word Karaoke, 2 = Line Synced, 3 = Plain text)
  int get priorityTier;

  /// Queries the remote source and returns parsed [Lyrics], or null if not found.
  Future<Lyrics?> fetchLyrics(
    String title,
    String artist, {
    Duration? duration,
    String? songId,
  });
}

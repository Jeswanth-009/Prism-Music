import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/utils/lyrics_matching.dart';
import '../../../../domain/entities/stream_info.dart';

/// Local persistent storage for user-edited or manually corrected lyrics.
///
/// User edits are saved to a dedicated Hive box (`custom_lyrics`) and take
/// immediate precedence over remote lookups from LRCLIB or fallbacks.
class CustomLyricsStorage {
  CustomLyricsStorage._();

  static final CustomLyricsStorage instance = CustomLyricsStorage._();

  static const String boxName = 'custom_lyrics';
  Box<Map>? _box;

  Future<Box<Map>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Map>(boxName);
    return _box!;
  }

  /// Primary lookup key based on unique song ID with normalized artist|title fallback.
  String storageKey(String title, String artist, String songId) {
    if (songId.isNotEmpty && !songId.startsWith('unknown')) {
      return 'id:$songId';
    }
    final t = normalizeTrackTitle(title);
    final a = normalizeArtistName(artist);
    return 'query:${a.isEmpty ? "unknown" : a}|${t.isEmpty ? title.trim() : t}';
  }

  /// Retrieves user-edited lyrics if present for this song.
  Future<Lyrics?> getCustomLyrics(
    String title,
    String artist,
    String songId,
  ) async {
    try {
      final box = await _getBox();
      final key = storageKey(title, artist, songId);
      final entry = box.get(key);
      if (entry == null) return null;

      final plain = entry['plainLyrics'] as String?;
      final syncedLrc = entry['syncedLrc'] as String?;

      if ((plain == null || plain.trim().isEmpty) &&
          (syncedLrc == null || syncedLrc.trim().isEmpty)) {
        return null;
      }

      return Lyrics(
        songId: songId,
        plainLyrics: plain,
        syncedLyrics: syncedLrc != null && syncedLrc.trim().isNotEmpty
            ? parseLrc(syncedLrc)
            : null,
        source: 'User Edited',
      );
    } catch (_) {
      return null;
    }
  }

  /// Saves user-edited plain or LRC synced lyrics.
  Future<void> saveCustomLyrics(
    String songId,
    String title,
    String artist, {
    String? plainLyrics,
    String? syncedLrc,
  }) async {
    try {
      final box = await _getBox();
      final key = storageKey(title, artist, songId);
      await box.put(key, <String, dynamic>{
        'plainLyrics': plainLyrics?.trim(),
        'syncedLrc': syncedLrc?.trim(),
        'editedAt': DateTime.now().toIso8601String(),
        'title': title,
        'artist': artist,
      });
    } catch (_) {}
  }

  /// Deletes user-edited lyrics and restores remote provider lyrics.
  Future<void> clearCustomLyrics(
    String songId,
    String title,
    String artist,
  ) async {
    try {
      final box = await _getBox();
      final key = storageKey(title, artist, songId);
      await box.delete(key);
    } catch (_) {}
  }

  /// Checks if the given song has a user-saved local lyrics override.
  Future<bool> hasCustomLyrics(
    String songId,
    String title,
    String artist,
  ) async {
    try {
      final box = await _getBox();
      final key = storageKey(title, artist, songId);
      return box.containsKey(key);
    } catch (_) {
      return false;
    }
  }
}

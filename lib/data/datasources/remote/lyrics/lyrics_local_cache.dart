import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/utils/lyrics_matching.dart';
import '../../../../domain/entities/entities.dart';

/// Local cache for successful lyrics lookups.
///
/// Keyed by the *normalized* "artist|title" pair so "Song (Official Video)"
/// and "Song" share an entry. Stores raw LRCLIB data (plain text + LRC) and
/// re-parses on read so cache entries survive parser upgrades.
class LyricsLocalCache {
  static const String _boxName = 'lyrics_cache';
  static const int _maxEntries = 200;

  Box<Map>? _box;

  Future<Box<Map>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  /// Stable cache key for a lookup.
  String cacheKey(String title, String artist) {
    final t = normalizeTrackTitle(title);
    final a = normalizeArtistName(artist);
    return '${a.isEmpty ? 'unknown' : a}|${t.isEmpty ? title.trim() : t}';
  }

  Future<Lyrics?> get(String title, String artist, String songId) async {
    try {
      final box = await _getBox();
      final entry = box.get(cacheKey(title, artist));
      if (entry == null) return null;

      final syncedLrc = entry['syncedLrc'] as String?;
      final plain = entry['plainLyrics'] as String?;
      if ((syncedLrc == null || syncedLrc.isEmpty) &&
          (plain == null || plain.isEmpty)) {
        return null;
      }

      return Lyrics(
        songId: songId,
        plainLyrics: plain,
        syncedLyrics:
            syncedLrc == null || syncedLrc.isEmpty ? null : parseLrc(syncedLrc),
        source: entry['source'] as String? ?? 'LRCLIB',
      );
    } catch (_) {
      // Cache is best-effort — never block a lookup on it.
      return null;
    }
  }

  Future<void> put(
    String title,
    String artist, {
    String? plainLyrics,
    String? syncedLrc,
  }) async {
    if ((plainLyrics == null || plainLyrics.isEmpty) &&
        (syncedLrc == null || syncedLrc.isEmpty)) {
      return;
    }
    try {
      final box = await _getBox();
      // Trim before inserting so the box stays bounded even when writes
      // race past the cap.
      if (box.length >= _maxEntries) {
        final keys = box.keys.toList();
        final toRemove = keys.take(box.length - _maxEntries + 1);
        for (final key in toRemove) {
          await box.delete(key);
        }
      }
      await box.put(cacheKey(title, artist), <String, dynamic>{
        'plainLyrics': plainLyrics,
        'syncedLrc': syncedLrc,
        'source': 'LRCLIB',
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort.
    }
  }
}

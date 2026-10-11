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

  /// Default TTL for cached lyrics (7 days).
  static const Duration defaultTtl = Duration(days: 7);

  Box<Map>? _box;

  Future<Box<Map>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  /// Stable cache key for a lookup, partitioning by artist, normalized title,
  /// version discriminant (live, remaster, acoustic, etc.), plausible duration,
  /// and provider record.
  String cacheKey(
    String title,
    String artist, {
    Duration? duration,
    String? version,
    String provider = 'LRCLIB',
  }) {
    final t = normalizeTrackTitle(title);
    final a = normalizeArtistName(artist);
    final v = version ?? extractVersionTag(title);
    final d = duration != null && duration.inSeconds >= 30
        ? duration.inSeconds.toString()
        : 'any';
    return '${a.isEmpty ? 'unknown' : a}|${t.isEmpty ? title.trim() : t}|v:$v|d:$d|p:$provider';
  }

  Future<Lyrics?> get(
    String title,
    String artist,
    String songId, {
    Duration? duration,
    String? version,
    String provider = 'LRCLIB',
    Duration maxAge = defaultTtl,
  }) async {
    try {
      final box = await _getBox();
      final key = cacheKey(
        title,
        artist,
        duration: duration,
        version: version,
        provider: provider,
      );
      final entry = box.get(key);
      if (entry == null) return null;

      // Honor cache freshness: discard expired entries.
      final cachedAtStr = entry['cachedAt'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          await box.delete(key);
          return null;
        }
      }

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
        source: entry['source'] as String? ?? provider,
      );
    } catch (_) {
      // Cache is best-effort — never block a lookup on it.
      return null;
    }
  }

  Future<void> put(
    String title,
    String artist, {
    Duration? duration,
    String? version,
    String provider = 'LRCLIB',
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
      final key = cacheKey(
        title,
        artist,
        duration: duration,
        version: version,
        provider: provider,
      );
      await box.put(key, <String, dynamic>{
        'plainLyrics': plainLyrics,
        'syncedLrc': syncedLrc,
        'source': provider,
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort.
    }
  }
}

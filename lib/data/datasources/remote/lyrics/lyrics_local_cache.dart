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
      final wordsData = entry['syncedWords'];

      List<LyricLine>? syncedLines;
      if (wordsData is List && wordsData.isNotEmpty) {
        syncedLines = wordsData.map<LyricLine>((lineMap) {
          final lMap = Map<String, dynamic>.from(lineMap as Map);
          final wordsList = lMap['words'] as List?;
          return LyricLine(
            startTimeMs: (lMap['startTimeMs'] as num?)?.toInt() ?? 0,
            endTimeMs: (lMap['endTimeMs'] as num?)?.toInt(),
            text: (lMap['text'] ?? '').toString(),
            words: wordsList?.map<LyricWord>((wMap) {
              final w = Map<String, dynamic>.from(wMap as Map);
              return LyricWord(
                startTimeMs: (w['startTimeMs'] as num?)?.toInt() ?? 0,
                endTimeMs: (w['endTimeMs'] as num?)?.toInt() ?? 0,
                text: (w['text'] ?? '').toString(),
                isBackground: (w['isBackground'] as bool?) ?? false,
              );
            }).toList(),
          );
        }).toList();
      } else if (syncedLrc != null && syncedLrc.isNotEmpty) {
        syncedLines = parseLrc(syncedLrc);
      }

      if ((syncedLines == null || syncedLines.isEmpty) &&
          (plain == null || plain.isEmpty)) {
        return null;
      }

      final syncTypeStr = entry['syncType'] as String?;
      final syncType = syncTypeStr == 'wordSynced'
          ? LyricsSyncType.wordSynced
          : (syncedLines != null && syncedLines.isNotEmpty
              ? LyricsSyncType.lineSynced
              : LyricsSyncType.plain);

      return Lyrics(
        songId: songId,
        plainLyrics: plain,
        syncedLyrics: syncedLines,
        source: entry['source'] as String? ?? provider,
        syncType: syncType,
        providerId: entry['providerId'] as String? ?? provider,
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
    List<LyricLine>? syncedLyrics,
    LyricsSyncType? syncType,
    String? providerId,
  }) async {
    if ((plainLyrics == null || plainLyrics.isEmpty) &&
        (syncedLrc == null || syncedLrc.isEmpty) &&
        (syncedLyrics == null || syncedLyrics.isEmpty)) {
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
        provider: providerId ?? provider,
      );

      List<Map<String, dynamic>>? serializedWords;
      if (syncedLyrics != null && syncedLyrics.any((l) => l.isWordSynced)) {
        serializedWords = syncedLyrics.map((l) => <String, dynamic>{
          'startTimeMs': l.startTimeMs,
          'endTimeMs': l.endTimeMs,
          'text': l.text,
          'words': l.words?.map((w) => <String, dynamic>{
            'startTimeMs': w.startTimeMs,
            'endTimeMs': w.endTimeMs,
            'text': w.text,
            'isBackground': w.isBackground,
          }).toList(),
        }).toList();
      }

      await box.put(key, <String, dynamic>{
        'plainLyrics': plainLyrics,
        'syncedLrc': syncedLrc,
        if (serializedWords != null) ...{'syncedWords': serializedWords},
        'source': provider,
        'providerId': providerId ?? provider,
        'syncType': syncType?.name,
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort.
    }
  }

  /// Record a verified negative result (404 / no lyrics found) to prevent
  /// repeatedly hitting the remote API on subsequent plays.
  Future<void> markNotFound(
    String title,
    String artist, {
    Duration? duration,
    String? version,
    String provider = 'LRCLIB',
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
      await box.put(key, <String, dynamic>{
        'notFound': true,
        'source': provider,
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort.
    }
  }

  /// Check if this track was recently verified as having no lyrics on the remote provider.
  Future<bool> isMarkedNotFound(
    String title,
    String artist, {
    Duration? duration,
    String? version,
    String provider = 'LRCLIB',
    Duration maxAge = const Duration(days: 3),
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
      if (entry != null && entry['notFound'] == true) {
        final cachedAtStr = entry['cachedAt'] as String?;
        if (cachedAtStr != null) {
          final cachedAt = DateTime.tryParse(cachedAtStr);
          if (cachedAt != null && DateTime.now().difference(cachedAt) < maxAge) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

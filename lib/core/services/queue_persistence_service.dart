import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/entities.dart';
import 'settings_service.dart';

/// Represents a persisted listening session restored safely on launch.
class SavedQueueSession {
  final Song currentSong;
  final List<Song> queue;
  final int queueIndex;
  final Duration position;
  final DateTime updatedAt;

  const SavedQueueSession({
    required this.currentSong,
    required this.queue,
    required this.queueIndex,
    required this.position,
    required this.updatedAt,
  });
}

/// Service that persists and restores the playback queue and position with explicit
/// privacy controls and strict no-surprise-auto-play safety.
class QueuePersistenceService {
  static const String _boxName = 'prism_queue_session';
  static const String _sessionKey = 'active_session';
  static QueuePersistenceService? _instance;

  Box? _box;

  QueuePersistenceService._();

  static QueuePersistenceService get instance =>
      _instance ??= QueuePersistenceService._();

  Future<Box> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox(_boxName);
    return _box!;
  }

  /// Persists current playback session if privacy settings permit.
  Future<void> saveSession({
    required Song? currentSong,
    required List<Song> queue,
    required int queueIndex,
    required Duration position,
    bool isIncognito = false,
  }) async {
    final settings = SettingsService.instance;

    // 1. Explicit user privacy check
    if (!settings.restoreQueueOnLaunch) {
      await clearSession();
      return;
    }

    // 2. Incognito / private listening check
    if (isIncognito && settings.excludeIncognitoQueue) {
      return;
    }

    if (currentSong == null || queue.isEmpty) {
      await clearSession();
      return;
    }

    try {
      final box = await _getBox();
      final data = {
        'currentSong': _songToMap(currentSong),
        'queue': queue.map(_songToMap).toList(),
        'queueIndex': queueIndex,
        'positionMs': position.inMilliseconds,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await box.put(_sessionKey, data);
    } catch (e) {
      debugPrint('QueuePersistenceService: Failed to save session: $e');
    }
  }

  /// Retrieves the saved queue session if permitted by privacy settings.
  Future<SavedQueueSession?> getSavedSession() async {
    final settings = SettingsService.instance;
    if (!settings.restoreQueueOnLaunch) {
      return null;
    }

    try {
      final box = await _getBox();
      final raw = box.get(_sessionKey);
      if (raw == null || raw is! Map) return null;

      final currentSongMap = raw['currentSong'];
      final queueRaw = raw['queue'];
      if (currentSongMap == null || queueRaw == null || queueRaw is! List) {
        return null;
      }

      final currentSong = _mapToSong(currentSongMap as Map);
      final queue = queueRaw.map((e) => _mapToSong(e as Map)).toList();
      final queueIndex =
          (raw['queueIndex'] as int?)?.clamp(0, queue.length - 1) ?? 0;
      final positionMs = raw['positionMs'] as int? ?? 0;
      final updatedAtStr = raw['updatedAt'] as String?;
      final updatedAt = updatedAtStr != null
          ? DateTime.tryParse(updatedAtStr) ?? DateTime.now()
          : DateTime.now();

      return SavedQueueSession(
        currentSong: currentSong,
        queue: queue,
        queueIndex: queueIndex,
        position: Duration(milliseconds: positionMs),
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('QueuePersistenceService: Failed to load session: $e');
      return null;
    }
  }

  /// Explicit privacy action: completely clears any persisted queue session.
  Future<void> clearSession() async {
    try {
      final box = await _getBox();
      await box.delete(_sessionKey);
    } catch (e) {
      debugPrint('QueuePersistenceService: Failed to clear session: $e');
    }
  }

  static Map<String, dynamic> _songToMap(Song song) => {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'artists': song.artists,
        'album': song.album,
        'albumId': song.albumId,
        'durationMs': song.duration.inMilliseconds,
        'thumbnailLow': song.thumbnails.low,
        'thumbnailMed': song.thumbnails.medium,
        'thumbnailHigh': song.thumbnails.high,
        'thumbnailMax': song.thumbnails.max,
        'source': song.source.index,
        'sourceName': song.source.name,
        'jioSaavnId': song.jioSaavnId,
        'youtubeId': song.youtubeId,
        'spotifyId': song.spotifyId,
        'isExplicit': song.isExplicit,
        'year': song.year,
        'genre': song.genre,
        'playCount': song.playCount,
        'matchConfidence': song.matchConfidence,
      };

  static Song _mapToSong(Map data) {
    MusicSource source = MusicSource.unknown;
    if (data['sourceName'] != null) {
      source = MusicSource.values.firstWhere(
        (s) => s.name == data['sourceName'],
        orElse: () => MusicSource.unknown,
      );
    } else if (data['source'] is int) {
      source = MusicSource.values.elementAtOrNull(data['source'] as int) ??
          MusicSource.unknown;
    }

    return Song(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      artist: data['artist'] as String? ?? '',
      artists: (data['artists'] as List?)?.cast<String>() ?? const [],
      album: data['album'] as String?,
      albumId: data['albumId'] as String?,
      duration: Duration(milliseconds: data['durationMs'] as int? ?? 0),
      thumbnails: Thumbnails(
        low: data['thumbnailLow'] as String?,
        medium: data['thumbnailMed'] as String?,
        high: data['thumbnailHigh'] as String?,
        max: data['thumbnailMax'] as String?,
      ),
      source: source,
      jioSaavnId: data['jioSaavnId'] as String?,
      youtubeId: data['youtubeId'] as String?,
      spotifyId: data['spotifyId'] as String?,
      isExplicit: data['isExplicit'] as bool? ?? false,
      year: data['year'] as int?,
      genre: data['genre'] as String?,
      playCount: data['playCount'] as int?,
      matchConfidence: (data['matchConfidence'] as num?)?.toDouble(),
    );
  }
}

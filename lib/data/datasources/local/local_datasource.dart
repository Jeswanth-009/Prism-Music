import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import '../../../../domain/entities/entities.dart';

/// Data source for local storage operations
abstract class LocalDataSource {
  // ============ LIKED SONGS ============
  
  /// Get all liked songs
  Future<List<Song>> getLikedSongs();
  
  /// Add a song to liked songs
  Future<void> likeSong(Song song);
  
  /// Remove a song from liked songs
  Future<void> unlikeSong(String songId);
  
  /// Check if a song is liked
  Future<bool> isSongLiked(String songId);

  // ============ PLAYLISTS ============
  
  /// Get all user playlists
  Future<List<Playlist>> getPlaylists();
  
  /// Create a new playlist
  Future<Playlist> createPlaylist(String name, {String? description});
  
  /// Delete a playlist
  Future<void> deletePlaylist(String playlistId);
  
  /// Update playlist details
  Future<Playlist> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
  });
  
  /// Add song to playlist
  Future<void> addSongToPlaylist(String playlistId, Song song);
  
  /// Remove song from playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
  
  /// Get playlist with songs
  Future<Playlist?> getPlaylist(String playlistId);

  // ============ LISTENING HISTORY ============
  
  /// Get listening history
  Future<List<Song>> getListeningHistory({int limit = 50, DateTime? since});
  
  /// Add song to listening history
  Future<void> addToHistory(Song song);
  
  /// Clear listening history
  Future<void> clearHistory();

  // ============ DOWNLOADS ============
  
  /// Get downloaded songs
  Future<List<Song>> getDownloadedSongs();
  
  /// Save download info
  Future<void> saveDownload(Song song, String filePath);
  
  /// Delete download
  Future<void> deleteDownload(String songId);
  
  /// Check if song is downloaded
  Future<bool> isSongDownloaded(String songId);
  
  /// Get download file path
  Future<String?> getDownloadPath(String songId);

  // ============ CACHED METADATA ============
  
  /// Cache song metadata
  Future<void> cacheSong(Song song);
  
  /// Get cached song
  Future<Song?> getCachedSong(String songId);
  
  /// Clear all cached data
  Future<void> clearCache();

  // ============ SETTINGS ============

  /// Get a setting value
  Future<T?> getSetting<T>(String key);

  /// Save a setting value
  Future<void> saveSetting<T>(String key, T value);

  // ============ SEARCH HISTORY ============

  /// Get search history (most recent first)
  Future<List<Map<String, String>>> getSearchHistory({int limit = 20});

  /// Get searches similar to query
  Future<List<Map<String, String>>> getSimilarSearches(String query, {int limit = 5});

  /// Add a search query to history
  Future<void> addSearchHistory(String query);

  /// Remove a specific search from history
  Future<void> removeSearchHistory(String id);

  /// Clear all search history
  Future<void> clearSearchHistory();
}

/// Implementation using Hive for local persistence
class LocalDataSourceImpl implements LocalDataSource {
  static const String _historyBoxName = 'listening_history';
  static const String _likedBoxName = 'liked_songs';
  static const String _searchHistoryBoxName = 'search_history';
  static const String _downloadsBoxName = 'downloads';
  Box? _historyBox;
  Box? _likedBox;
  Box? _searchHistoryBox;
  Box? _downloadsBox;

  LocalDataSourceImpl();

  Future<Box> _getHistoryBox() async {
    if (_historyBox != null && _historyBox!.isOpen) return _historyBox!;
    _historyBox = await Hive.openBox(_historyBoxName);
    return _historyBox!;
  }

  Future<Box> _getLikedBox() async {
    if (_likedBox != null && _likedBox!.isOpen) return _likedBox!;
    _likedBox = await Hive.openBox(_likedBoxName);
    return _likedBox!;
  }

  Future<Box> _getSearchHistoryBox() async {
    if (_searchHistoryBox != null && _searchHistoryBox!.isOpen) return _searchHistoryBox!;
    _searchHistoryBox = await Hive.openBox(_searchHistoryBoxName);
    return _searchHistoryBox!;
  }

  Future<Box> _getDownloadsBox() async {
    if (_downloadsBox != null && _downloadsBox!.isOpen) return _downloadsBox!;
    _downloadsBox = await Hive.openBox(_downloadsBoxName);
    return _downloadsBox!;
  }

  Map<String, dynamic> _songToMap(Song song) => {
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
        'youtubeId': song.youtubeId,
        'spotifyId': song.spotifyId,
        'isExplicit': song.isExplicit,
        'year': song.year,
        'genre': song.genre,
        'playCount': song.playCount,
      };

  Song _mapToSong(Map data) => Song(
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
        source: MusicSource.values.elementAtOrNull(data['source'] as int? ?? 4) ?? MusicSource.unknown,
        youtubeId: data['youtubeId'] as String?,
        spotifyId: data['spotifyId'] as String?,
        isExplicit: data['isExplicit'] as bool? ?? false,
        year: data['year'] as int?,
        genre: data['genre'] as String?,
        playCount: data['playCount'] as int?,
      );

  // ============ LIKED SONGS ============

  @override
  Future<List<Song>> getLikedSongs() async {
    final box = await _getLikedBox();
    final songs = <Song>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map) songs.add(_mapToSong(data));
    }
    return songs;
  }

  @override
  Future<void> likeSong(Song song) async {
    final box = await _getLikedBox();
    await box.put(song.playableId, _songToMap(song));
  }

  @override
  Future<void> unlikeSong(String songId) async {
    final box = await _getLikedBox();
    await box.delete(songId);
  }

  @override
  Future<bool> isSongLiked(String songId) async {
    final box = await _getLikedBox();
    return box.containsKey(songId);
  }

  // ============ PLAYLISTS ============

  @override
  Future<List<Playlist>> getPlaylists() async {
    // TODO: Implement with Isar
    return [];
  }

  @override
  Future<Playlist> createPlaylist(String name, {String? description}) async {
    // TODO: Implement with Isar
    return Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      isUserCreated: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    // TODO: Implement with Isar
  }

  @override
  Future<Playlist> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
  }) async {
    // TODO: Implement with Isar
    return Playlist(id: playlistId, name: name ?? '');
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    // TODO: Implement with Isar
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    // TODO: Implement with Isar
  }

  @override
  Future<Playlist?> getPlaylist(String playlistId) async {
    // TODO: Implement with Isar
    return null;
  }

  // ============ LISTENING HISTORY ============

  @override
  Future<List<Song>> getListeningHistory({int limit = 50, DateTime? since}) async {
    final box = await _getHistoryBox();
    // Keys are stored as 'timestamp_songId' so reverse‐sorted keys = newest first
    final keys = box.keys.toList()..sort((a, b) => b.toString().compareTo(a.toString()));
    final songs = <Song>[];
    final seenIds = <String>{};
    for (final key in keys) {
      if (songs.length >= limit) break;
      final data = box.get(key);
      if (data is Map) {
        final song = _mapToSong(data);
        // Deduplicate — only keep the most recent play of each song
        if (seenIds.add(song.playableId)) {
          if (since != null) {
            final ts = int.tryParse(key.toString().split('_').first);
            if (ts != null && DateTime.fromMillisecondsSinceEpoch(ts).isBefore(since)) continue;
          }
          songs.add(song);
        }
      }
    }
    return songs;
  }

  @override
  Future<void> addToHistory(Song song) async {
    final box = await _getHistoryBox();
    final key = '${DateTime.now().millisecondsSinceEpoch}_${song.playableId}';
    await box.put(key, _songToMap(song));
    // Cap history at 500 entries
    if (box.length > 500) {
      final allKeys = box.keys.toList()..sort((a, b) => a.toString().compareTo(b.toString()));
      final toRemove = allKeys.sublist(0, box.length - 500);
      for (final k in toRemove) {
        await box.delete(k);
      }
    }
  }

  @override
  Future<void> clearHistory() async {
    final box = await _getHistoryBox();
    await box.clear();
  }

  // ============ DOWNLOADS ============

  @override
  Future<List<Song>> getDownloadedSongs() async {
    final box = await _getDownloadsBox();
    final songs = <Song>[];

    for (final key in box.keys) {
      final data = box.get(key);
      if (data is! Map) continue;

      final localPath = data['localPath']?.toString();
      if (localPath == null || localPath.isEmpty || !File(localPath).existsSync()) {
        continue;
      }

      final file = File(localPath);
      if (file.lengthSync() < 16 * 1024) {
        continue;
      }

      final title = data['title']?.toString() ?? 'Unknown Title';
      final artist = data['artist']?.toString() ?? 'Unknown Artist';
      final album = data['album']?.toString();
      final songId = (data['songId'] ?? key).toString();
      int durationSeconds = int.tryParse(data['duration']?.toString() ?? '') ??
          int.tryParse(data['durationSec']?.toString() ?? '') ??
          0;
      if (durationSeconds == 0) {
        final durationMs = int.tryParse(data['durationMs']?.toString() ?? '');
        if (durationMs != null && durationMs > 0) {
          durationSeconds = durationMs ~/ 1000;
        }
      }
      final thumb = data['thumbnailUrl']?.toString() ?? '';

      songs.add(
        Song(
          id: songId,
          title: title,
          artist: artist,
          artists: [artist],
          album: album,
          duration: Duration(seconds: durationSeconds),
          thumbnails: Thumbnails.fromUrl(thumb),
          source: MusicSource.local,
          streamUrl: localPath,
        ),
      );
    }

    return songs;
  }

  @override
  Future<void> saveDownload(Song song, String filePath) async {
    final box = await _getDownloadsBox();
    await box.put(song.playableId, {
      'songId': song.playableId,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'duration': song.duration.inSeconds,
      'thumbnailUrl': song.thumbnailUrl,
      'localPath': filePath,
      'downloadedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteDownload(String songId) async {
    final box = await _getDownloadsBox();
    final data = box.get(songId);
    if (data is Map) {
      final path = data['localPath']?.toString();
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    await box.delete(songId);
  }

  @override
  Future<bool> isSongDownloaded(String songId) async {
    final box = await _getDownloadsBox();
    final data = box.get(songId);
    if (data is! Map) return false;
    final path = data['localPath']?.toString();
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  @override
  Future<String?> getDownloadPath(String songId) async {
    final box = await _getDownloadsBox();
    final data = box.get(songId);
    if (data is! Map) return null;
    final path = data['localPath']?.toString();
    if (path == null || path.isEmpty) return null;
    return File(path).existsSync() ? path : null;
  }

  // ============ CACHED METADATA ============

  @override
  Future<void> cacheSong(Song song) async {
    // TODO: Implement with Isar
  }

  @override
  Future<Song?> getCachedSong(String songId) async {
    // TODO: Implement with Isar
    return null;
  }

  @override
  Future<void> clearCache() async {
    // TODO: Implement with Isar
  }

  // ============ SETTINGS ============

  @override
  Future<T?> getSetting<T>(String key) async {
    // TODO: Implement with Hive
    return null;
  }

  @override
  Future<void> saveSetting<T>(String key, T value) async {
    // TODO: Implement with Hive
  }

  // ============ SEARCH HISTORY ============

  @override
  Future<List<Map<String, String>>> getSearchHistory({int limit = 20}) async {
    final box = await _getSearchHistoryBox();
    final entries = <Map<String, String>>[];

    // Get all keys sorted by timestamp (newest first)
    final keys = box.keys.toList()..sort((a, b) => b.toString().compareTo(a.toString()));

    for (final key in keys.take(limit)) {
      final data = box.get(key);
      if (data is Map) {
        entries.add({
          'id': key.toString(),
          'query': data['query']?.toString() ?? '',
          'timestamp': data['timestamp']?.toString() ?? '',
        });
      }
    }

    return entries;
  }

  @override
  Future<List<Map<String, String>>> getSimilarSearches(String query, {int limit = 5}) async {
    final box = await _getSearchHistoryBox();
    final queryLower = query.toLowerCase().trim();
    final matches = <Map<String, String>>[];

    // Get all keys sorted by timestamp (newest first)
    final keys = box.keys.toList()..sort((a, b) => b.toString().compareTo(a.toString()));

    for (final key in keys) {
      if (matches.length >= limit) break;
      final data = box.get(key);
      if (data is Map) {
        final storedQuery = data['query']?.toString().toLowerCase() ?? '';
        // Check if stored query starts with or contains the search query
        if (storedQuery.startsWith(queryLower) || storedQuery.contains(queryLower)) {
          // Avoid duplicates
          if (!matches.any((m) => m['query']?.toLowerCase() == storedQuery)) {
            matches.add({
              'id': key.toString(),
              'query': data['query']?.toString() ?? '',
              'timestamp': data['timestamp']?.toString() ?? '',
            });
          }
        }
      }
    }

    return matches;
  }

  @override
  Future<void> addSearchHistory(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    final box = await _getSearchHistoryBox();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final key = '${timestamp}_${trimmedQuery.hashCode}';

    // Check if this exact query already exists (case-insensitive), remove old entry
    final existingKey = box.keys.firstWhere(
      (k) {
        final data = box.get(k);
        return data is Map && data['query']?.toString().toLowerCase() == trimmedQuery.toLowerCase();
      },
      orElse: () => null,
    );
    if (existingKey != null) {
      await box.delete(existingKey);
    }

    await box.put(key, {
      'query': trimmedQuery,
      'timestamp': timestamp,
    });

    // Cap history at 100 entries
    if (box.length > 100) {
      final allKeys = box.keys.toList()..sort((a, b) => a.toString().compareTo(b.toString()));
      final toRemove = allKeys.sublist(0, box.length - 100);
      for (final k in toRemove) {
        await box.delete(k);
      }
    }
  }

  @override
  Future<void> removeSearchHistory(String id) async {
    final box = await _getSearchHistoryBox();
    await box.delete(id);
  }

  @override
  Future<void> clearSearchHistory() async {
    final box = await _getSearchHistoryBox();
    await box.clear();
  }
}

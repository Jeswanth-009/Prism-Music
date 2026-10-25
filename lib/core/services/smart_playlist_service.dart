import 'package:flutter/material.dart';

import '../../data/datasources/local/local_datasource.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/library_repository.dart';

/// A dynamic smart playlist model computed from user listening behavior.
class SmartPlaylist {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String ruleSummary;
  final List<Song> songs;
  final IconData icon;
  final List<Color> gradientColors;

  const SmartPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.ruleSummary,
    required this.songs,
    required this.icon,
    required this.gradientColors,
  });

  int get trackCount => songs.length;
}

/// Service that builds smart playlists based on actual listening sessions,
/// liked tracks, and newly added discovery entries.
class SmartPlaylistService {
  final LocalDataSource _localDataSource;

  SmartPlaylistService({
    required LocalDataSource localDataSource,
    LibraryRepository? libraryRepository,
  }) : _localDataSource = localDataSource;

  /// Generates the dynamic smart playlists based on stored history and favorites.
  Future<List<SmartPlaylist>> generateSmartPlaylists() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    final fortyFiveDaysAgo = now.subtract(const Duration(days: 45));

    final historyEntries = await _localDataSource.getFullHistory();
    final likedSongs = await _localDataSource.getLikedSongs();

    // 1. Heavy Rotation (most played tracks in the last 30 days)
    final recentEntries = historyEntries
        .where((e) => e.playedAt.isAfter(thirtyDaysAgo))
        .toList();
    final playCounts = <String, int>{};
    final songLookup = <String, Song>{};

    for (final entry in recentEntries) {
      final id = entry.song.playableId;
      playCounts[id] = (playCounts[id] ?? 0) + 1;
      songLookup[id] = entry.song;
    }

    final heavyRotationIds = playCounts.keys.toList()
      ..sort((a, b) => playCounts[b]!.compareTo(playCounts[a]!));
    final heavyRotationSongs = heavyRotationIds
        .take(30)
        .map((id) => songLookup[id]!)
        .toList();

    // 2. Recent Favorites (liked songs)
    final recentFavorites = likedSongs.take(30).toList();

    // 3. Fresh Additions (tracks first heard in the last 14 days)
    final firstPlayed = <String, DateTime>{};
    for (final entry in historyEntries) {
      final id = entry.song.playableId;
      if (!firstPlayed.containsKey(id) ||
          entry.playedAt.isBefore(firstPlayed[id]!)) {
        firstPlayed[id] = entry.playedAt;
      }
    }
    final seenFreshIds = <String>{};
    final freshSongs = <Song>[];
    for (final entry in historyEntries) {
      final id = entry.song.playableId;
      final first = firstPlayed[id];
      if (first != null && first.isAfter(fourteenDaysAgo)) {
        if (seenFreshIds.add(id)) {
          freshSongs.add(entry.song);
          if (freshSongs.length >= 30) break;
        }
      }
    }

    // 4. Forgotten Gems (liked songs not played in over 45 days)
    final lastPlayed = <String, DateTime>{};
    for (final entry in historyEntries) {
      final id = entry.song.playableId;
      if (!lastPlayed.containsKey(id) ||
          entry.playedAt.isAfter(lastPlayed[id]!)) {
        lastPlayed[id] = entry.playedAt;
      }
    }

    final forgottenGems = likedSongs.where((song) {
      final last = lastPlayed[song.playableId];
      return last == null || last.isBefore(fortyFiveDaysAgo);
    }).take(30).toList();

    return [
      SmartPlaylist(
        id: 'smart_heavy_rotation',
        title: 'Heavy Rotation',
        subtitle: 'Most played this month',
        description:
            'Your soundtrack on repeat based on your recent listening sessions.',
        ruleSummary: 'Top tracks played in the last 30 days',
        songs: heavyRotationSongs,
        icon: Icons.local_fire_department_rounded,
        gradientColors: const [Color(0xFFFF5722), Color(0xFFFF9800)],
      ),
      SmartPlaylist(
        id: 'smart_recent_favorites',
        title: 'Recent Favorites',
        subtitle: 'Loved tracks in rotation',
        description: 'The songs you have liked and kept close lately.',
        ruleSummary: 'Recently liked songs in your library',
        songs: recentFavorites,
        icon: Icons.favorite_rounded,
        gradientColors: const [Color(0xFFE91E63), Color(0xFFFF4081)],
      ),
      SmartPlaylist(
        id: 'smart_fresh_additions',
        title: 'Fresh Additions',
        subtitle: 'New discoveries',
        description:
            'Songs you listened to for the first time over the past two weeks.',
        ruleSummary: 'First heard in the last 14 days',
        songs: freshSongs,
        icon: Icons.auto_awesome_rounded,
        gradientColors: const [Color(0xFF00BCD4), Color(0xFF3F51B5)],
      ),
      SmartPlaylist(
        id: 'smart_forgotten_gems',
        title: 'Forgotten Gems',
        subtitle: 'Time to rediscover',
        description:
            'Liked tracks in your library that you have not played in over 45 days.',
        ruleSummary: 'Liked songs unplayed in 45+ days',
        songs: forgottenGems,
        icon: Icons.replay_circle_filled_rounded,
        gradientColors: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
      ),
    ];
  }

  /// Saves a snapshot of this smart playlist into the user's permanent playlists.
  Future<Playlist> saveAsStaticPlaylist(SmartPlaylist smartPlaylist) async {
    final playlist = await _localDataSource.createPlaylist(
      smartPlaylist.title,
      description: 'Saved from Smart Playlist: ${smartPlaylist.ruleSummary}',
    );

    for (final song in smartPlaylist.songs) {
      await _localDataSource.addSongToPlaylist(playlist.id, song);
    }

    return (await _localDataSource.getPlaylist(playlist.id)) ?? playlist;
  }
}

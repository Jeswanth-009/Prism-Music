import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/smart_playlist_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

import '../helpers/fakes.dart';

void main() {
  group('SmartPlaylistService Tests', () {
    late FakeLocalDataSource localDataSource;
    late SmartPlaylistService service;

    setUp(() {
      localDataSource = FakeLocalDataSource();
      service = SmartPlaylistService(localDataSource: localDataSource);
    });

    test('generates heavy rotation, recent favorites, fresh additions, and forgotten gems',
        () async {
      final now = DateTime.now();

      const songA = Song(
        id: 's_a',
        title: 'Song Alpha',
        artist: 'Artist One',
        duration: Duration(seconds: 180),
        thumbnails: Thumbnails(),
      );

      const songB = Song(
        id: 's_b',
        title: 'Song Beta',
        artist: 'Artist Two',
        duration: Duration(seconds: 210),
        thumbnails: Thumbnails(),
      );

      const songC = Song(
        id: 's_c',
        title: 'Song Gamma',
        artist: 'Artist Three',
        duration: Duration(seconds: 195),
        thumbnails: Thumbnails(),
      );

      // Populate history: Song A played 3 times recently, Song B played once 60 days ago
      localDataSource.historyEntries = [
        HistoryEntry(song: songA, playedAt: now.subtract(const Duration(days: 2))),
        HistoryEntry(song: songA, playedAt: now.subtract(const Duration(days: 5))),
        HistoryEntry(song: songA, playedAt: now.subtract(const Duration(days: 10))),
        HistoryEntry(song: songB, playedAt: now.subtract(const Duration(days: 60))),
        HistoryEntry(song: songC, playedAt: now.subtract(const Duration(days: 3))),
      ];

      // Song B and C are liked
      localDataSource.likedSongs = [songB, songC];

      final smartPlaylists = await service.generateSmartPlaylists();
      expect(smartPlaylists.length, equals(4));

      // 1. Heavy Rotation
      final heavyRotation = smartPlaylists.firstWhere((p) => p.id == 'smart_heavy_rotation');
      expect(heavyRotation.songs.first.id, equals('s_a'));

      // 2. Recent Favorites
      final recentFavorites = smartPlaylists.firstWhere((p) => p.id == 'smart_recent_favorites');
      expect(recentFavorites.songs.length, equals(2));

      // 3. Fresh Additions
      final fresh = smartPlaylists.firstWhere((p) => p.id == 'smart_fresh_additions');
      expect(fresh.songs.any((s) => s.id == 's_c'), isTrue);

      // 4. Forgotten Gems: Song B was played 60 days ago (>= 45 days)
      final forgotten = smartPlaylists.firstWhere((p) => p.id == 'smart_forgotten_gems');
      expect(forgotten.songs.any((s) => s.id == 's_b'), isTrue);
    });

    test('saveAsStaticPlaylist persists smart playlist snapshot to user playlists', () async {
      const songX = Song(
        id: 's_x',
        title: 'Song X',
        artist: 'Artist X',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
      );

      final smartPlaylist = SmartPlaylist(
        id: 'smart_heavy_rotation',
        title: 'Heavy Rotation',
        subtitle: 'Most played',
        description: 'Soundtrack on repeat',
        ruleSummary: 'Top tracks played in the last 30 days',
        songs: [songX],
        icon: Icons.local_fire_department_rounded,
        gradientColors: const [Color(0xFFFF5722), Color(0xFFFF9800)],
      );

      final saved = await service.saveAsStaticPlaylist(smartPlaylist);
      expect(saved.name, equals('Heavy Rotation'));
      expect(saved.songs?.length, equals(1));
      expect(saved.songs?.first.id, equals('s_x'));
    });
  });
}

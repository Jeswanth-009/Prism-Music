import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/album.dart';
import 'package:prism_music/domain/entities/playlist.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  final song1 = Song(
    id: 's1',
    title: 'Song One',
    artist: 'Artist One',
    duration: const Duration(seconds: 180),
    thumbnails: Thumbnails.empty(),
    source: MusicSource.youtube,
  );

  final song2 = Song(
    id: 's2',
    title: 'Song Two',
    artist: 'Artist Two',
    duration: const Duration(seconds: 210),
    thumbnails: Thumbnails.empty(),
    source: MusicSource.youtube,
  );

  group('Album equality and copyWith', () {
    test('equality includes songs and description', () {
      final a1 = Album(
        id: 'alb1',
        title: 'Title',
        artist: 'Artist',
        thumbnails: Thumbnails.empty(),
        songs: [song1],
        description: 'First description',
      );

      final a2 = Album(
        id: 'alb1',
        title: 'Title',
        artist: 'Artist',
        thumbnails: Thumbnails.empty(),
        songs: [song1],
        description: 'First description',
      );

      final a3 = Album(
        id: 'alb1',
        title: 'Title',
        artist: 'Artist',
        thumbnails: Thumbnails.empty(),
        songs: [song1, song2],
        description: 'First description',
      );

      final a4 = a1.copyWith(description: 'Updated description');

      expect(a1, equals(a2));
      expect(a1, isNot(equals(a3)));
      expect(a1, isNot(equals(a4)));
    });

    test('copyWith sentinel clearing semantics', () {
      final album = Album(
        id: 'alb1',
        title: 'Title',
        artist: 'Artist',
        thumbnails: Thumbnails.empty(),
        year: 2024,
        trackCount: 10,
        songs: [song1],
        youtubePlaylistId: 'yt123',
        spotifyId: 'sp123',
        description: 'Desc',
      );

      // Omitting fields keeps them
      final unchanged = album.copyWith(title: 'New Title');
      expect(unchanged.title, 'New Title');
      expect(unchanged.year, 2024);
      expect(unchanged.trackCount, 10);
      expect(unchanged.songs, [song1]);
      expect(unchanged.description, 'Desc');

      // Explicitly passing null clears them
      final cleared = album.copyWith(
        year: null,
        trackCount: null,
        songs: null,
        youtubePlaylistId: null,
        spotifyId: null,
        description: null,
      );
      expect(cleared.year, isNull);
      expect(cleared.trackCount, isNull);
      expect(cleared.songs, isNull);
      expect(cleared.youtubePlaylistId, isNull);
      expect(cleared.spotifyId, isNull);
      expect(cleared.description, isNull);
    });
  });

  group('Playlist equality and copyWith', () {
    test('equality includes songs, thumbnails, totalDuration, timestamps', () {
      final now = DateTime(2024, 1, 1);
      final p1 = Playlist(
        id: 'p1',
        name: 'My Playlist',
        songs: [song1],
        totalDuration: const Duration(seconds: 180),
        createdAt: now,
      );

      final p2 = Playlist(
        id: 'p1',
        name: 'My Playlist',
        songs: [song1],
        totalDuration: const Duration(seconds: 180),
        createdAt: now,
      );

      final p3 = Playlist(
        id: 'p1',
        name: 'My Playlist',
        songs: [song2],
        totalDuration: const Duration(seconds: 180),
        createdAt: now,
      );

      expect(p1, equals(p2));
      expect(p1, isNot(equals(p3)));
    });

    test('copyWith sentinel clearing semantics', () {
      final now = DateTime(2024, 1, 1);
      final playlist = Playlist(
        id: 'p1',
        name: 'My Playlist',
        description: 'A description',
        author: 'Author',
        totalDuration: const Duration(minutes: 10),
        songs: [song1],
        youtubePlaylistId: 'yt1',
        spotifyPlaylistId: 'sp1',
        createdAt: now,
        updatedAt: now,
      );

      // Omitting parameters keeps them
      final untouched = playlist.copyWith(name: 'Updated Name');
      expect(untouched.name, 'Updated Name');
      expect(untouched.description, 'A description');
      expect(untouched.author, 'Author');
      expect(untouched.totalDuration, const Duration(minutes: 10));
      expect(untouched.songs, [song1]);

      // Explicitly passing null clears them
      final cleared = playlist.copyWith(
        description: null,
        author: null,
        totalDuration: null,
        songs: null,
        youtubePlaylistId: null,
        spotifyPlaylistId: null,
        createdAt: null,
        updatedAt: null,
      );
      expect(cleared.description, isNull);
      expect(cleared.author, isNull);
      expect(cleared.totalDuration, isNull);
      expect(cleared.songs, isNull);
      expect(cleared.youtubePlaylistId, isNull);
      expect(cleared.spotifyPlaylistId, isNull);
      expect(cleared.createdAt, isNull);
      expect(cleared.updatedAt, isNull);
    });
  });
}

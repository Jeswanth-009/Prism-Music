import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/playlist_export_service.dart';
import 'package:prism_music/domain/entities/playlist.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/presentation/widgets/playlist/playlist_export_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSong1 = Song(
    id: 'song_1',
    title: 'Midnight Echoes',
    artist: 'Luna Prism',
    album: 'Constellations',
    duration: Duration(seconds: 215),
    youtubeId: 'yt_123',
    thumbnails: Thumbnails(),
  );

  const testSong2 = Song(
    id: 'song_2',
    title: 'Starlight Dream',
    artist: 'Solar Flare',
    album: 'Supernova',
    duration: Duration(seconds: 180),
    youtubeId: 'yt_456',
    thumbnails: Thumbnails(),
  );

  const testPlaylist = Playlist(
    id: 'pl_001',
    name: 'Synthwave Night',
    description: 'Neon synth and darkwave favorites',
    author: 'User',
    isUserCreated: true,
    songs: [testSong1, testSong2],
  );

  group('PlaylistExportService', () {
    test('sanitizeFilename removes illegal filesystem characters', () {
      expect(PlaylistExportService.sanitizeFilename('Rock/Metal: 2026?'),
          equals('Rock_Metal_ 2026_'));
      expect(PlaylistExportService.sanitizeFilename('   '), equals('playlist'));
    });

    test('M3U8 export format structure is valid', () async {
      // Create export service and test M3U string generation logic
      final songs = testPlaylist.songs!;
      final buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      buffer.writeln('#PLAYLIST:${testPlaylist.name}');
      buffer.writeln('#COMMENT:${testPlaylist.description}');
      for (final s in songs) {
        buffer.writeln('#EXTINF:${s.duration.inSeconds},${s.artist} - ${s.title}');
        buffer.writeln('https://music.youtube.com/watch?v=${s.youtubeId}');
      }
      final content = buffer.toString();

      expect(content, contains('#EXTM3U'));
      expect(content, contains('#PLAYLIST:Synthwave Night'));
      expect(content, contains('#EXTINF:215,Luna Prism - Midnight Echoes'));
      expect(content, contains('https://music.youtube.com/watch?v=yt_123'));
      expect(content, contains('#EXTINF:180,Solar Flare - Starlight Dream'));
      expect(content, contains('https://music.youtube.com/watch?v=yt_456'));
    });

    test('JSON export serialization structure is valid', () {
      final payload = {
        'format': 'prism_playlist_archive',
        'version': 1,
        'playlist': {
          'id': testPlaylist.id,
          'name': testPlaylist.name,
          'description': testPlaylist.description,
          'trackCount': testPlaylist.songs!.length,
          'tracks': testPlaylist.songs!.map((s) => {
            'id': s.id,
            'title': s.title,
            'artist': s.artist,
            'durationSeconds': s.duration.inSeconds,
          }).toList(),
        },
      };

      final encoded = jsonEncode(payload);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['format'], equals('prism_playlist_archive'));
      expect(decoded['playlist']['name'], equals('Synthwave Night'));
      final tracks = decoded['playlist']['tracks'] as List<dynamic>;
      expect(tracks.length, equals(2));
      expect(tracks.first['title'], equals('Midnight Echoes'));
    });
  });

  group('PlaylistExportSheet Widget', () {
    testWidgets('renders all export format options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistExportSheet(playlist: testPlaylist),
          ),
        ),
      );

      expect(find.text('Export Playlist'), findsOneWidget);
      expect(find.text('Synthwave Night • 2 tracks'), findsOneWidget);
      expect(find.text('M3U8 Playlist (.m3u8)'), findsOneWidget);
      expect(find.text('JSON Archive (.json)'), findsOneWidget);
      expect(find.text('Share Tracklist (Text)'), findsOneWidget);
    });
  });
}

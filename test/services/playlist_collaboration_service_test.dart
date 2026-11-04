import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/playlist_collaboration_service.dart';
import 'package:prism_music/domain/entities/playlist.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  group('PlaylistCollaborationService', () {
    const service = PlaylistCollaborationService.instance;

    final testSongs = [
      const Song(
        id: 's1',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: Duration(seconds: 230),
        thumbnails: Thumbnails(),
        youtubeId: 'dqt8Z1k0oWQ',
        isrc: 'USUM71607567',
      ),
      const Song(
        id: 's2',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
        youtubeId: '4NRXx6U8ABQ',
        isrc: 'USUG11904206',
      ),
    ];

    final testPlaylist = Playlist(
      id: 'pl_123',
      name: 'Synthwave Night',
      description: 'Late night driving mix',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      trackCount: testSongs.length,
      songs: testSongs,
    );

    test('encodes and decodes a playlist preserving track attributes and ISRC', () {
      final appLink = service.buildAppShareLink(testPlaylist);
      expect(appLink.startsWith('prism://playlist?data='), isTrue);

      final decoded = service.decodePlaylistPayload(appLink);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('Synthwave Night'));
      expect(decoded.songs?.length, equals(2));

      final firstTrack = decoded.songs![0];
      expect(firstTrack.title, equals('Starboy'));
      expect(firstTrack.artist, equals('The Weeknd'));
      expect(firstTrack.duration.inSeconds, equals(230));
      expect(firstTrack.youtubeId, equals('dqt8Z1k0oWQ'));
      expect(firstTrack.isrc, equals('USUM71607567'));

      final secondTrack = decoded.songs![1];
      expect(secondTrack.title, equals('Blinding Lights'));
      expect(secondTrack.artist, equals('The Weeknd'));
      expect(secondTrack.youtubeId, equals('4NRXx6U8ABQ'));
      expect(secondTrack.isrc, equals('USUG11904206'));
    });

    test('decodes web fallback URL with hash fragment', () {
      final webLink = service.buildWebShareLink(testPlaylist);
      expect(webLink.contains('#data='), isTrue);

      final decoded = service.decodePlaylistPayload(webLink);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('Synthwave Night'));
      expect(decoded.songs?.length, equals(2));
    });

    test('returns null gracefully on invalid or corrupt payload', () {
      expect(service.decodePlaylistPayload(''), isNull);
      expect(service.decodePlaylistPayload('prism://playlist?data=invalid_base64_payload!'), isNull);
      expect(service.decodePlaylistPayload('not_a_valid_token'), isNull);
    });
  });
}

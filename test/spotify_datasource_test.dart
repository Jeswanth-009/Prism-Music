import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/data/datasources/remote/spotify/spotify_datasource.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  group('SpotifyDataSourceImpl.parseEmbedHtml', () {
    // parseEmbedHtml never touches the network, a bare Dio is fine here.
    final dataSource = SpotifyDataSourceImpl(dio: Dio());

    test('parses playlist name, owner, cover and tracks from __NEXT_DATA__',
        () {
      final html = File(
        'test/fixtures/spotify_embed_playlist.html',
      ).readAsStringSync();

      final details = dataSource.parseEmbedHtml(html);

      expect(details, isNotNull);
      expect(details!.name, 'Comeback Comrade');
      expect(details.owner, 'Ganni');
      expect(details.id, '5uMBnqs9tGZPbgIED2VNvu');
      expect(details.coverUrl, isNotEmpty);
      expect(details.tracks, isNotEmpty);
    });

    test('maps track fields: title, artists, spotify id, duration', () {
      final html = File(
        'test/fixtures/spotify_embed_playlist.html',
      ).readAsStringSync();

      final first = dataSource.parseEmbedHtml(html)!.tracks.first;

      expect(first.title, 'Maya');
      expect(first.artist, 'Arijit Singh');
      expect(first.artists, ['Arijit Singh', 'Ramya Behara']);
      expect(first.spotifyId, '48JiUwsMs5CAKOK1BYXG4q');
      expect(first.id, 'spotify:track:48JiUwsMs5CAKOK1BYXG4q');
      expect(first.duration.inMilliseconds, 234615);
      expect(first.source, MusicSource.spotify);
    });

    test('returns null for pages without embed data', () {
      expect(dataSource.parseEmbedHtml('<html><body>error</body></html>'),
          isNull);
    });

    test('returns null for embed data without tracks', () {
      const html = '<html><head>'
          '<script id="__NEXT_DATA__" type="application/json">'
          '{"props":{"pageProps":{"state":{"data":{"entity":'
          '{"name":"Empty","trackList":[]}'
          '}}}}}'
          '</script></head></html>';

      expect(dataSource.parseEmbedHtml(html), isNull);
    });
  });
}

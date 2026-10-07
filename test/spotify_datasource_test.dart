import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/data/datasources/remote/spotify/spotify_datasource.dart';
import 'package:prism_music/domain/entities/entities.dart';

/// Fake adapter that records every request. Requests to a spotify.link host
/// answer with a redirect to [redirectTarget]; everything else returns the
/// [embedHtml] fixture, so redirect-following can be observed end-to-end.
class _RedirectingAdapter implements HttpClientAdapter {
  _RedirectingAdapter({required this.embedHtml, this.redirectTarget});

  final String embedHtml;
  final Uri? redirectTarget;
  final List<Uri> requested = [];

  bool get isSpotifyLink => redirectTarget != null;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);

    final isShortLink =
        options.uri.host == 'spotify.link' || options.uri.host.endsWith('.spotify.link');
    if (isShortLink && redirectTarget != null) {
      return ResponseBody.fromString('', 302, headers: {
        Headers.contentTypeHeader: ['text/html'],
        'location': [redirectTarget.toString()],
      });
    }

    return ResponseBody.fromString(embedHtml, 200, headers: {
      Headers.contentTypeHeader: ['text/html'],
    });
  }

  @override
  void close({bool force = false}) {}
}

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

  group('SpotifyDataSourceImpl.getPlaylistDetails link validation', () {
    final fixture =
        File('test/fixtures/spotify_embed_playlist.html').readAsStringSync();

    SpotifyDataSourceImpl build(_RedirectingAdapter adapter) {
      final dio = Dio();
      dio.httpClientAdapter = adapter;
      return SpotifyDataSourceImpl(dio: dio);
    }

    test('resolves a plain open.spotify.com URL and fetches the embed',
        () async {
      final adapter = _RedirectingAdapter(embedHtml: fixture);
      final dataSource = build(adapter);

      final details = await dataSource
          .getPlaylistDetails('https://open.spotify.com/playlist/5uMBnqs9tGZPbgIED2VNvu');

      expect(details, isNotNull);
      expect(details!.id, '5uMBnqs9tGZPbgIED2VNvu');
      expect(
        adapter.requested.single.toString(),
        'https://open.spotify.com/embed/playlist/5uMBnqs9tGZPbgIED2VNvu',
      );
    });

    test('resolves the spotify: scheme form', () async {
      final adapter = _RedirectingAdapter(embedHtml: fixture);
      final dataSource = build(adapter);

      final details = await dataSource
          .getPlaylistDetails('spotify:playlist:5uMBnqs9tGZPbgIED2VNvu');

      expect(details, isNotNull);
      expect(adapter.requested.single.host, 'open.spotify.com');
    });

    test('resolves a genuine spotify.link that redirects to open.spotify.com',
        () async {
      final adapter = _RedirectingAdapter(
        embedHtml: fixture,
        redirectTarget:
            Uri.parse('https://open.spotify.com/playlist/5uMBnqs9tGZPbgIED2VNvu'),
      );
      final dataSource = build(adapter);

      final details =
          await dataSource.getPlaylistDetails('https://spotify.link/abc123');

      expect(details, isNotNull);
      expect(details!.id, '5uMBnqs9tGZPbgIED2VNvu');
      // Short link (redirect target extracted from Location) → embed fetch.
      expect(adapter.requested.length, 2);
      expect(adapter.requested.first.host, 'spotify.link');
      expect(adapter.requested.last.host, 'open.spotify.com');
    });

    test('rejects a lookalike short-link host without any network request',
        () async {
      final adapter = _RedirectingAdapter(embedHtml: fixture);
      final dataSource = build(adapter);

      final details = await dataSource
          .getPlaylistDetails('https://spotify.link.evil.com/abc123');

      expect(details, isNull);
      expect(adapter.requested, isEmpty);
    });

    test('rejects a non-Spotify host embedding a playlist path', () async {
      final adapter = _RedirectingAdapter(embedHtml: fixture);
      final dataSource = build(adapter);

      final details = await dataSource
          .getPlaylistDetails('https://evil.example.com/playlist/5uMBnqs9tGZPbgIED2VNvu');

      expect(details, isNull);
      expect(adapter.requested, isEmpty);
    });

    test('rejects a genuine short link whose redirect lands off Spotify',
        () async {
      final adapter = _RedirectingAdapter(
        embedHtml: fixture,
        redirectTarget: Uri.parse('https://evil.com/playlist/5uMBnqs9tGZPbgIED2VNvu'),
      );
      final dataSource = build(adapter);

      final details =
          await dataSource.getPlaylistDetails('https://spotify.link/abc123');

      expect(details, isNull);
      // The untrusted target is rejected from Location; evil.com is NEVER requested.
      expect(adapter.requested.length, 1);
      expect(adapter.requested.single.host, 'spotify.link');
    });
  });
}

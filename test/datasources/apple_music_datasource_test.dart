import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/link_validation.dart';
import 'package:prism_music/data/datasources/remote/apple_music/apple_music_datasource.dart';

void main() {
  group('AppleMusicDataSource', () {
    late AppleMusicDataSourceImpl dataSource;

    setUp(() {
      dataSource = AppleMusicDataSourceImpl();
    });

    test('validates Apple Music playlist hosts correctly', () {
      expect(isAppleMusicPlaylistHost('music.apple.com'), isTrue);
      expect(isAppleMusicPlaylistHost('itunes.apple.com'), isTrue);
      expect(isAppleMusicPlaylistHost('beta.music.apple.com'), isTrue);
      expect(isAppleMusicPlaylistHost('spotify.com'), isFalse);
      expect(isAppleMusicPlaylistHost('evil-music.apple.com.attacker.com'), isFalse);
    });

    test('parses Apple Music playlist from serialized-server-data with ISRC codes', () {
      const sampleHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Today's Hits on Apple Music">
  <meta property="og:image" content="https://is1-ssl.mzstatic.com/image/thumb/Features/cover.jpg">
  <meta property="og:description" content="The biggest hits right now.">
  <script type="application/json" id="serialized-server-data">
  [
    {
      "data": [
        {
          "id": "pl.f4d1060b525243e6a05420188a71bf1b",
          "type": "playlists",
          "attributes": {
            "name": "Today's Hits",
            "curatorName": "Apple Music",
            "description": { "standard": "The biggest hits right now." },
            "artwork": { "url": "https://is1-ssl.mzstatic.com/image/thumb/Features/{w}x{h}bb.jpg" }
          },
          "relationships": {
            "tracks": {
              "data": [
                {
                  "id": "1738123456",
                  "type": "songs",
                  "attributes": {
                    "name": "Espresso",
                    "artistName": "Sabrina Carpenter",
                    "albumName": "Short n' Sweet",
                    "durationInMillis": 175000,
                    "isrc": "USUM72403305",
                    "artwork": { "url": "https://is1-ssl.mzstatic.com/image/thumb/Music/{w}x{h}bb.jpg" }
                  }
                },
                {
                  "id": "1738987654",
                  "type": "songs",
                  "attributes": {
                    "name": "Birds of a Feather",
                    "artistName": "Billie Eilish",
                    "albumName": "HIT ME HARD AND SOFT",
                    "durationInMillis": 190000,
                    "isrc": "USUM72401824",
                    "artwork": { "url": "https://is1-ssl.mzstatic.com/image/thumb/Music2/{w}x{h}bb.jpg" }
                  }
                }
              ]
            }
          }
        }
      ]
    }
  ]
  </script>
</head>
<body></body>
</html>
''';

      final details = dataSource.parsePlaylistHtml(
        sampleHtml,
        url: 'https://music.apple.com/us/playlist/todays-hits/pl.f4d1060b525243e6a05420188a71bf1b',
      );

      expect(details, isNotNull);
      expect(details!.id, 'pl.f4d1060b525243e6a05420188a71bf1b');
      expect(details.name, "Today's Hits");
      expect(details.curator, 'Apple Music');
      expect(details.tracks.length, 2);

      final track1 = details.tracks[0];
      expect(track1.title, 'Espresso');
      expect(track1.artist, 'Sabrina Carpenter');
      expect(track1.album, "Short n' Sweet");
      expect(track1.duration, const Duration(milliseconds: 175000));
      expect(track1.isrc, 'USUM72403305');
      expect(track1.thumbnailUrl, 'https://is1-ssl.mzstatic.com/image/thumb/Music/300x300bb.jpg');

      final track2 = details.tracks[1];
      expect(track2.title, 'Birds of a Feather');
      expect(track2.artist, 'Billie Eilish');
      expect(track2.isrc, 'USUM72401824');
    });

    test('parses Apple Music playlist from JSON-LD schema fallback', () {
      const jsonLdHtml = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "http://schema.org",
    "@type": "MusicPlaylist",
    "name": "Chill Vibes",
    "author": { "@type": "Organization", "name": "Apple Music Chill" },
    "track": [
      {
        "@type": "MusicRecording",
        "name": "Sunset Lover",
        "duration": "PT3M57S",
        "byArtist": { "@type": "MusicGroup", "name": "Petit Biscuit" },
        "inAlbum": { "@type": "MusicAlbum", "name": "Presence" },
        "isrcCode": "FR9W11500001"
      }
    ]
  }
  </script>
</head>
<body></body>
</html>
''';

      final details = dataSource.parsePlaylistHtml(
        jsonLdHtml,
        url: 'https://music.apple.com/us/playlist/pl.u-a1b2c3d4e5',
      );

      expect(details, isNotNull);
      expect(details!.id, 'pl.u-a1b2c3d4e5');
      expect(details.name, 'Chill Vibes');
      expect(details.curator, 'Apple Music Chill');
      expect(details.tracks.length, 1);

      final track = details.tracks.first;
      expect(track.title, 'Sunset Lover');
      expect(track.artist, 'Petit Biscuit');
      expect(track.album, 'Presence');
      expect(track.isrc, 'FR9W11500001');
      expect(track.duration, const Duration(minutes: 3, seconds: 57));
    });

    test('returns null on empty or unparseable HTML', () {
      expect(dataSource.parsePlaylistHtml(''), isNull);
      expect(dataSource.parsePlaylistHtml('<html><body>Not a playlist</body></html>'), isNull);
    });
  });
}

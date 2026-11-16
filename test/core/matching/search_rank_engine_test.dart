import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/matching/search_rank_engine.dart';
import 'package:prism_music/domain/entities/album.dart';
import 'package:prism_music/domain/entities/artist.dart';
import 'package:prism_music/domain/entities/song.dart';

import '../../helpers/fakes.dart';

void main() {
  group('SearchRankEngine normalization & knockoff detection', () {
    test('normalize strips brackets, punctuation, and extra whitespace', () {
      expect(
        SearchRankEngine.normalize('Master of Puppets (Remastered 2016)'),
        'master of puppets remastered 2016',
      );
      expect(
        SearchRankEngine.coreTitle('Master of Puppets (Remastered 2016)'),
        'master of puppets',
      );
      expect(
        SearchRankEngine.coreTitle('Fade to Black [Official Music Video]'),
        'fade to black',
      );
      expect(
        SearchRankEngine.coreTitle('Hotel California - Live at The Forum'),
        'hotel california',
      );
      expect(
        SearchRankEngine.normalize('  In   The   End  '),
        'in the end',
      );
    });

    test('hasKnockoffMarkers detects cover, karaoke, tribute, 8d audio, and slowed versions', () {
      expect(
        SearchRankEngine.hasKnockoffMarkers(
          'Master of Puppets (Tribute Band Cover)',
          'master of puppets',
        ),
        isTrue,
      );
      expect(
        SearchRankEngine.hasKnockoffMarkers(
          'Fade to Black (Karaoke Instrumental)',
          'fade to black',
        ),
        isTrue,
      );
      expect(
        SearchRankEngine.hasKnockoffMarkers(
          'Numb (Slowed and Reverb)',
          'numb',
        ),
        isTrue,
      );
      expect(
        SearchRankEngine.hasKnockoffMarkers(
          'Something in the Way (8D Audio)',
          'something in the way',
        ),
        isTrue,
      );
      expect(
        SearchRankEngine.hasKnockoffMarkers(
          'Master of Puppets (Live in Seattle 1989)',
          'master of puppets',
        ),
        isFalse,
      );
    });
  });

  group('SearchRankEngine.rankSongs', () {
    final original = song('s1', 'Master of Puppets', artist: 'Metallica');
    final cover = song('s2', 'Master of Puppets (Cover)', artist: 'Rock Tribute Band');
    final karaoke = song('s3', 'Master of Puppets [Karaoke Version]', artist: 'Karaoke Kings');
    final live = song('s4', 'Master of Puppets (Live)', artist: 'Metallica');

    test('places original studio master ahead of covers and karaoke', () {
      final input = <Song>[karaoke, cover, live, original];
      final ranked = SearchRankEngine.rankSongs(input, 'Master of Puppets');

      expect(ranked.first.id, 's1');
      expect(ranked.first.artist, 'Metallica');
      expect(ranked.last.id, anyOf('s2', 's3'));
    });

    test('prefers exact title match over partial match', () {
      final partial = song('s5', 'Master of Puppets 2: The Return', artist: 'Metallica');
      final input = <Song>[partial, original];
      final ranked = SearchRankEngine.rankSongs(input, 'Master of Puppets');

      expect(ranked.first.id, 's1');
    });
  });

  group('SearchRankEngine.evaluateTopResult', () {
    const artistMetallica = Artist(
      id: 'a1',
      name: 'Metallica',
      thumbnails: Thumbnails(high: 'https://example.com/metallica.jpg'),
    );

    const albumMaster = Album(
      id: 'alb1',
      title: 'Master of Puppets',
      artist: 'Metallica',
      thumbnails: Thumbnails(),
    );

    final songMaster = song('s1', 'Master of Puppets', artist: 'Metallica');

    test('exact artist query identifies artist as top match', () {
      final top = SearchRankEngine.evaluateTopResult(
        songs: [songMaster],
        artists: const [artistMetallica],
        albums: const [albumMaster],
        query: 'Metallica',
      );

      expect(top, isNotNull);
      expect(top!.isArtist, isTrue);
      expect(top.artist?.name, 'Metallica');
    });

    test('exact song query identifies song as top match', () {
      final top = SearchRankEngine.evaluateTopResult(
        songs: [songMaster],
        artists: const [artistMetallica],
        albums: const [],
        query: 'Master of Puppets',
      );

      expect(top, isNotNull);
      expect(top!.isSong, isTrue);
      expect(top.song?.title, 'Master of Puppets');
    });

    test('exact album query identifies album when artist name is not the query', () {
      final top = SearchRankEngine.evaluateTopResult(
        songs: [],
        artists: [],
        albums: const [albumMaster],
        query: 'Master of Puppets',
      );

      expect(top, isNotNull);
      expect(top!.isAlbum, isTrue);
      expect(top.album?.title, 'Master of Puppets');
    });

    test('returns null when candidates are empty', () {
      final top = SearchRankEngine.evaluateTopResult(
        songs: [],
        artists: [],
        albums: [],
        query: 'something completely absent',
      );

      expect(top, isNull);
    });
  });
}

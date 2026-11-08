import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/genre_service.dart';

void main() {
  group('GenreService', () {
    late GenreService service;

    setUp(() {
      service = GenreService();
    });

    test('getAllGenres returns non-empty catalog of genres and moods', () {
      final genres = service.getAllGenres();
      expect(genres, isNotEmpty);
      expect(genres.any((g) => g.id == 'pop'), isTrue);
      expect(genres.any((g) => g.id == 'bollywood'), isTrue);
      expect(genres.any((g) => g.id == 'rock'), isTrue);
      expect(genres.any((g) => g.id == 'lofi_chill'), isTrue);
    });

    test('getGenresOnly and getMoodsOnly partition genres appropriately', () {
      final musicGenres = service.getGenresOnly();
      final moods = service.getMoodsOnly();

      expect(musicGenres.every((g) => !g.isMood), isTrue);
      expect(moods.every((g) => g.isMood), isTrue);
      expect(musicGenres.length + moods.length, equals(service.getAllGenres().length));
    });

    test('getGenreById finds correct genre', () {
      final pop = service.getGenreById('pop');
      expect(pop, isNotNull);
      expect(pop!.name, equals('Pop'));
      expect(pop.playlists, isNotEmpty);

      final nonExistent = service.getGenreById('unknown_xyz');
      expect(nonExistent, isNull);
    });

    test('searchGenres filters correctly', () {
      final rockResults = service.searchGenres('rock');
      expect(rockResults.any((g) => g.name.contains('Rock')), isTrue);

      final emptyResults = service.searchGenres('');
      expect(emptyResults.length, equals(service.getAllGenres().length));

      final bogusResults = service.searchGenres('xyz999nonexistent');
      expect(bogusResults, isEmpty);
    });
  });
}

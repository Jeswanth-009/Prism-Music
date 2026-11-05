import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/core/services/recommendation_service.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/domain/repositories/library_repository.dart';

class MockMusicRepository extends Mock implements MusicRepository {}
class MockLibraryRepository extends Mock implements LibraryRepository {}

void main() {
  late MockMusicRepository mockMusicRepository;
  late MockLibraryRepository mockLibraryRepository;
  late RecommendationService service;

  Song makeSong(String id, String title, String artist) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Album',
      duration: const Duration(seconds: 180),
      thumbnails: const Thumbnails(),
      source: MusicSource.youtube,
      youtubeId: id,
    );
  }

  setUp(() {
    mockMusicRepository = MockMusicRepository();
    mockLibraryRepository = MockLibraryRepository();
    service = RecommendationService(mockMusicRepository, mockLibraryRepository);

    when(() => mockLibraryRepository.getListeningHistory(limit: any(named: 'limit')))
        .thenAnswer((_) async => const Right([]));
    when(() => mockLibraryRepository.getLikedSongs())
        .thenAnswer((_) async => const Right([]));
    when(() => mockMusicRepository.searchSongs(
          any(),
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => const Right([]));
    when(() => mockMusicRepository.getJioSaavnSuggestions(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => const Right([]));
    when(() => mockMusicRepository.getTrending(region: any(named: 'region'), limit: any(named: 'limit')))
        .thenAnswer((_) async => const Right([]));
  });

  group('Song Radio', () {
    test('generateSongRadio ensures seed song is first and appends deduplicated recommendations', () async {
      final seed = makeSong('seed1', 'Blinding Lights', 'The Weeknd');
      final similar1 = makeSong('sim1', 'Starboy', 'The Weeknd');
      final duplicateSeed = makeSong('seed1', 'Blinding Lights', 'The Weeknd');
      final similar2 = makeSong('sim2', 'Save Your Tears', 'The Weeknd');

      when(() => mockMusicRepository.getRelatedSongs(seed.id, limit: any(named: 'limit')))
          .thenAnswer((_) async => Right([similar1, duplicateSeed, similar2]));

      final radio = await service.generateSongRadio(seed, count: 10);

      expect(radio.first, seed);
      expect(radio.length, 3); // seed, similar1, similar2 (duplicate filtered out)
      expect(radio[1].title, 'Starboy');
      expect(radio[2].title, 'Save Your Tears');
    });

    test('generateSongRadio gracefully returns seed song when recommendations fail', () async {
      final seed = makeSong('seed2', 'Levitating', 'Dua Lipa');

      when(() => mockMusicRepository.getRelatedSongs(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => const Left(ServerFailure(message: 'Network offline')));

      final radio = await service.generateSongRadio(seed);

      expect(radio.length, 1);
      expect(radio.first, seed);
    });
  });
}

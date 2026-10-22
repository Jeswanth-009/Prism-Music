import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/recommendation_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/domain/repositories/library_repository.dart';
import 'package:prism_music/core/error/failures.dart';

class MockMusicRepository implements MusicRepository {
  List<Song> mockSongs = [];

  @override
  Future<Either<Failure, List<Song>>> searchSongs(String query, {int limit = 20, String? filter, int offset = 0}) async {
    return Right(mockSongs);
  }

  @override
  Future<Either<Failure, List<Song>>> getRelatedSongs(String songId, {int limit = 20}) async {
    return Right(mockSongs);
  }

  @override
  Future<Either<Failure, List<Song>>> getJioSaavnSuggestions(String songId, {int limit = 10}) async {
    return Right(mockSongs);
  }

  @override
  Future<Either<Failure, List<Song>>> getTrending({String region = 'US', int limit = 50}) async {
    return Right(mockSongs);
  }

  @override
  Future<Either<Failure, List<Song>>> getRecommendations({int limit = 20}) async {
    return Right(mockSongs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLibraryRepository implements LibraryRepository {
  List<Song> history = [];
  List<Song> likedSongs = [];

  @override
  Future<Either<Failure, List<Song>>> getListeningHistory({int limit = 50, DateTime? since}) async {
    return Right(history);
  }

  @override
  Future<Either<Failure, List<Song>>> getLikedSongs() async {
    return Right(likedSongs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMusicRepository musicRepository;
  late MockLibraryRepository libraryRepository;
  late RecommendationService recommendationService;

  setUp(() async {
    Hive.init('./test_hive');
    if (Hive.isBoxOpen('recommendation_settings')) {
      await Hive.box('recommendation_settings').deleteFromDisk();
    }
    if (Hive.isBoxOpen('user_taste_profile')) {
      await Hive.box('user_taste_profile').deleteFromDisk();
    }
    musicRepository = MockMusicRepository();
    libraryRepository = MockLibraryRepository();
    await SettingsService.instance.initialize();
    await SettingsService.instance.clearNotInterested();
    recommendationService = RecommendationService(musicRepository, libraryRepository);
    await recommendationService.initialize();
    await recommendationService.setMode(RecommendationMode.similar);
  });

  tearDown(() async {
    await SettingsService.instance.clearNotInterested();
    await recommendationService.dispose();
  });

  test('RecommendationMode defaults to similar and switches to discover', () async {
    expect(recommendationService.mode, RecommendationMode.similar);
    await recommendationService.setMode(RecommendationMode.discover);
    expect(recommendationService.mode, RecommendationMode.discover);
    await recommendationService.setMode(RecommendationMode.similar);
    expect(recommendationService.mode, RecommendationMode.similar);
  });

  test('Similar mode returns relevant filtered songs without anti-artist penalty', () async {
    final seedSong = const Song(
      id: 'seed1',
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      duration: Duration(seconds: 233),
      thumbnails: Thumbnails(),
      youtubeId: 'seed1',
    );

    musicRepository.mockSongs = [
      const Song(
        id: 'rec1',
        title: 'Bad Habits (Official Video)',
        artist: 'Ed Sheeran',
        duration: Duration(seconds: 231),
        thumbnails: Thumbnails(),
        youtubeId: 'rec1',
      ),
      const Song(
        id: 'rec2',
        title: 'Stay With Me',
        artist: 'Sam Smith',
        duration: Duration(seconds: 172),
        thumbnails: Thumbnails(),
        youtubeId: 'rec2',
      ),
      const Song(
        id: 'junk1',
        title: 'Shape of You (Reaction / Interview / Podcast)',
        artist: 'Random Reacts',
        duration: Duration(seconds: 600),
        thumbnails: Thumbnails(),
        youtubeId: 'junk1',
      ),
    ];

    final recommendations = await recommendationService.getRecommendations(
      currentSong: seedSong,
      limit: 10,
    );

    expect(recommendations.isNotEmpty, isTrue);
    // Non-music podcast/reaction should be filtered out
    expect(recommendations.any((s) => s.id == 'junk1'), isFalse);
    // Real music should be present
    expect(recommendations.any((s) => s.id == 'rec1'), isTrue);
    expect(recommendations.any((s) => s.id == 'rec2'), isTrue);
  });

  test('Discover mode provides diverse songs without exceeding artist cap', () async {
    await recommendationService.setMode(RecommendationMode.discover);

    musicRepository.mockSongs = List.generate(
      5,
      (i) => Song(
        id: 'song_$i',
        title: 'Track $i',
        artist: 'Same Artist',
        duration: const Duration(seconds: 200),
        thumbnails: const Thumbnails(),
        youtubeId: 'song_$i',
      ),
    );

    final recommendations = await recommendationService.getRecommendations(
      limit: 10,
    );

    // Max 2 tracks per artist in discover mode
    final sameArtistCount = recommendations.where((s) => s.artist == 'Same Artist').length;
    expect(sameArtistCount, lessThanOrEqualTo(2));
    expect(recommendations.first.recommendationReason, isNotNull);
    expect(recommendations.first.recommendationReason, contains('✦'));
  });

  test('Explainable reasons are attached to Similar mode recommendations', () async {
    const seedSong = Song(
      id: 'seed1',
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      duration: Duration(seconds: 233),
      thumbnails: Thumbnails(),
      youtubeId: 'seed1',
    );

    musicRepository.mockSongs = [
      const Song(
        id: 'rec1',
        title: 'Castle on the Hill',
        artist: 'Ed Sheeran',
        duration: Duration(seconds: 261),
        thumbnails: Thumbnails(),
        youtubeId: 'rec1',
      ),
      const Song(
        id: 'rec2',
        title: 'Perfect',
        artist: 'Ed Sheeran',
        duration: Duration(seconds: 263),
        thumbnails: Thumbnails(),
        youtubeId: 'rec2',
      ),
    ];

    final recommendations = await recommendationService.getRecommendations(
      currentSong: seedSong,
      limit: 5,
    );

    expect(recommendations.isNotEmpty, isTrue);
    expect(recommendations.first.recommendationReason, contains('More from Ed Sheeran'));
  });

  test('Not Interested songs and artists are strictly suppressed', () async {
    const seedSong = Song(
      id: 'seed_base',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
      youtubeId: 'seed_base',
    );

    final unwantedSong = const Song(
      id: 'unwanted_1',
      title: 'Unwanted Song',
      artist: 'Blocked Artist',
      duration: Duration(seconds: 210),
      thumbnails: Thumbnails(),
      youtubeId: 'unwanted_1',
    );

    final wantedSong = const Song(
      id: 'wanted_1',
      title: 'Save Your Tears',
      artist: 'The Weeknd',
      duration: Duration(seconds: 215),
      thumbnails: Thumbnails(),
      youtubeId: 'wanted_1',
    );

    musicRepository.mockSongs = [unwantedSong, wantedSong];

    // Suppress unwanted song
    await recommendationService.markSongNotInterested(unwantedSong);

    final recommendations = await recommendationService.getRecommendations(
      currentSong: seedSong,
      limit: 5,
    );

    expect(recommendations.any((s) => s.id == 'unwanted_1'), isFalse);
    expect(recommendations.any((s) => s.id == 'wanted_1'), isTrue);

    // Suppress by artist
    await recommendationService.markArtistNotInterested('The Weeknd');
    final recommendationsAfterArtistBlock = await recommendationService.getRecommendations(
      currentSong: seedSong,
      limit: 5,
    );
    expect(recommendationsAfterArtistBlock.any((s) => s.artist == 'The Weeknd'), isFalse);
  });
}

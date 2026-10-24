import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/core/services/curated_playlists.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';
import 'package:prism_music/presentation/pages/curated_playlist_page.dart';

import '../helpers/fakes.dart';

class _TestMusicRepository extends FakeMusicRepository {
  @override
  Future<Either<Failure, Playlist>> getPlaylistDetails(
    String playlistId, {
    int page = 1,
  }) async {
    return Right(playlist(
      'PL_test_123',
      'Autumn Lo-Fi Beats',
      songs: [
        song('s1', 'Crisp Air'),
        song('s2', 'Falling Leaves'),
      ],
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestMusicRepository musicRepo;

  setUp(() async {
    await getIt.reset();
    musicRepo = _TestMusicRepository();
    getIt.registerSingleton<MusicRepository>(musicRepo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('CuratedPlaylists Provenance & Maintenance', () {
    test('all curated playlists have non-empty provenance and maintenance metadata', () {
      final playlists = CuratedPlaylists.all;
      expect(playlists, isNotEmpty);

      for (final p in playlists) {
        expect(p.provenance, isNotEmpty, reason: 'Playlist ${p.name} missing provenance');
        expect(p.maintenance, isNotEmpty, reason: 'Playlist ${p.name} missing maintenance');
      }
    });

    test('seasonal category contains playlists with seasonalTag and audit dates', () {
      final seasonal = CuratedPlaylists.forCategory('Seasonal');
      expect(seasonal, isNotEmpty);

      for (final s in seasonal) {
        expect(s.seasonalTag, isNotNull);
        expect(s.seasonalTag, isNotEmpty);
        expect(s.lastVerified, isNotNull);
      }

      final autumn = seasonal.firstWhere((p) => p.id == 'autumn_lofi_chill');
      expect(autumn.seasonalTag, equals('Autumn 2026'));
      expect(autumn.provenance, contains('Prism Editorial'));
      expect(autumn.maintenance, contains('Seasonal rotation'));
    });
  });

  testWidgets('CuratedPlaylistPage renders clear provenance and maintenance banner',
      (tester) async {
    const testPlaylist = CuratedPlaylist(
      id: 'test_editorial_01',
      name: 'Autumn Lo-Fi Beats',
      playlistId: 'PL_test_123',
      category: 'Seasonal',
      gradient: [Colors.orange, Colors.deepOrange],
      icon: Icons.eco_rounded,
      seasonalTag: 'Autumn 2026',
      provenance: 'Prism Editorial Lo-Fi Soundscapes',
      maintenance: 'Seasonal rotation · Verified October 2026',
    );

    await pumpTestWidget(
      tester,
      const CuratedPlaylistPage(playlist: testPlaylist),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Autumn Lo-Fi Beats'), findsWidgets);
    expect(find.text('Prism Editorial Lo-Fi Soundscapes'), findsOneWidget);
    expect(find.text('Seasonal rotation · Verified October 2026'), findsOneWidget);
    expect(find.text('Autumn 2026'), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
  });
}

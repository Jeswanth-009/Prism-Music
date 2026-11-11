import 'package:fpdart/fpdart.dart' show Right;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/repositories.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/blocs/library/library_state.dart';
import 'package:prism_music/presentation/widgets/library/import/playlist_sync_sheet.dart';

class MockMusicRepository extends Mock implements MusicRepository {}

class MockLibraryBloc extends Mock implements LibraryBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMusicRepository mockMusicRepo;
  late MockLibraryBloc mockLibraryBloc;

  final localSong1 = Song(
    id: 'local_1',
    title: 'Local Track 1',
    artist: 'Artist A',
    duration: const Duration(seconds: 180),
    thumbnails: Thumbnails.empty(),
    source: MusicSource.spotify,
  );

  final localSong2 = Song(
    id: 'local_2',
    title: 'Local Track 2 (to be removed upstream)',
    artist: 'Artist B',
    duration: const Duration(seconds: 210),
    thumbnails: Thumbnails.empty(),
    source: MusicSource.spotify,
  );

  final newUpstreamSong = Song(
    id: 'upstream_3',
    title: 'Upstream Brand New Song',
    artist: 'Artist C',
    duration: const Duration(seconds: 240),
    thumbnails: Thumbnails.empty(),
    source: MusicSource.spotify,
  );

  final testPlaylist = Playlist(
    id: 'pl_100',
    name: 'Top Hits 2026',
    songs: [localSong1, localSong2],
    spotifyPlaylistId: 'spotify_123',
    isUserCreated: false,
    trackCount: 2,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockMusicRepo = MockMusicRepository();
    mockLibraryBloc = MockLibraryBloc();

    when(() => mockLibraryBloc.state).thenReturn(
      LibraryState(playlists: [testPlaylist], status: LibraryStatus.success),
    );
    when(() => mockLibraryBloc.stream).thenAnswer((_) => const Stream.empty());

    final importResult = ImportPlaylistResult(
      playlist: testPlaylist,
      matchedTracks: [localSong1, newUpstreamSong],
      unmatchedTracks: const [],
      totalSourceTracks: 2,
    );

    when(() => mockMusicRepo.importSpotifyPlaylist(any()))
        .thenAnswer((_) async => Right(importResult));
  });

  setUpAll(() {
    registerFallbackValue(
      const SyncPlaylistSongsEvent(playlistId: '', songs: []),
    );
  });

  testWidgets('PlaylistSyncSheet fetches diff, displays +1 New and -1 Removed badges, and applies sync',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<LibraryBloc>.value(
            value: mockLibraryBloc,
            child: PlaylistSyncSheet(
              playlist: testPlaylist,
              musicRepository: mockMusicRepo,
            ),
          ),
        ),
      ),
    );

    // Initial loading frame
    expect(find.text('Sync Top Hits 2026'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump to complete async upstream resolution
    await tester.pumpAndSettle();

    // Verify diff badges
    expect(find.text('+1 New'), findsOneWidget);
    expect(find.text('-1 Removed'), findsOneWidget);
    expect(find.text('2 Total'), findsOneWidget);

    // Verify tracks are rendered
    expect(find.text('Local Track 1'), findsOneWidget);
    expect(find.text('Upstream Brand New Song'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);

    // Tap "Apply Sync" button
    final applyButton = find.text('Apply Sync');
    expect(applyButton, findsOneWidget);
    await tester.tap(applyButton);
    await tester.pump();

    // Verify event dispatched to LibraryBloc
    verify(
      () => mockLibraryBloc.add(
        any(
          that: isA<SyncPlaylistSongsEvent>().having(
            (e) => e.playlistId,
            'playlistId',
            'pl_100',
          ).having(
            (e) => e.songs.length,
            'songs length',
            2,
          ),
        ),
      ),
    ).called(1);
  });
}

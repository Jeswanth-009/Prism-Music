import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/library/library_event.dart';
import 'package:prism_music/presentation/pages/playlist_detail_page.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLibraryRepository libraryRepo;

  setUp(() {
    libraryRepo = FakeLibraryRepository();
  });

  LibraryBloc buildBloc() {
    final bloc = LibraryBloc(
      libraryRepository: libraryRepo,
      musicRepository: FakeMusicRepository(),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  testWidgets('renders user-created playlist badge', (tester) async {
    final p = playlist('p1', 'My Roadtrip Mix', isUserCreated: true);
    libraryRepo.playlists = [p];
    final bloc = buildBloc()..add(const LoadLibraryEvent());

    await pumpTestWidget(
      tester,
      PlaylistDetailPage(playlist: p),
      libraryBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('My Roadtrip Mix'), findsOneWidget);
    expect(find.text('PLAYLIST'), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
  });

  testWidgets('renders Spotify Import badge and refresh button', (tester) async {
    final p = playlist(
      'sp1',
      'Liked from Spotify',
      spotifyPlaylistId: 'spot123',
    );
    libraryRepo.playlists = [p];
    final bloc = buildBloc()..add(const LoadLibraryEvent());

    await pumpTestWidget(
      tester,
      PlaylistDetailPage(playlist: p),
      libraryBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Liked from Spotify'), findsOneWidget);
    expect(find.text('SPOTIFY IMPORT'), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
  });

  testWidgets('renders YouTube Import badge and refresh button', (tester) async {
    final p = playlist(
      'yt1',
      'Favorites from YT',
      youtubePlaylistId: 'PL_yt_fav',
    );
    libraryRepo.playlists = [p];
    final bloc = buildBloc()..add(const LoadLibraryEvent());

    await pumpTestWidget(
      tester,
      PlaylistDetailPage(playlist: p),
      libraryBloc: bloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Favorites from YT'), findsOneWidget);
    expect(find.text('YOUTUBE IMPORT'), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
  });
}

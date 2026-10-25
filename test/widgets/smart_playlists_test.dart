import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/services/smart_playlist_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/pages/smart_playlist_page.dart';
import 'package:prism_music/presentation/widgets/library/smart_playlist_card.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocalDataSource localDataSource;
  late SmartPlaylistService service;

  setUp(() async {
    await getIt.reset();
    localDataSource = FakeLocalDataSource();
    service = SmartPlaylistService(localDataSource: localDataSource);
    getIt.registerSingleton<SmartPlaylistService>(service);
    initTestHive('smart_playlist_widget_test');
  });

  tearDown(() async {
    await getIt.reset();
  });

  final testSmartPlaylist = SmartPlaylist(
    id: 'smart_heavy_rotation',
    title: 'Heavy Rotation',
    subtitle: 'Most played this month',
    description: 'Your soundtrack on repeat based on your recent listening sessions.',
    ruleSummary: 'Top tracks played in the last 30 days',
    songs: const [
      Song(
        id: 's_rot_1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(seconds: 200),
        thumbnails: Thumbnails(),
      ),
    ],
    icon: Icons.local_fire_department_rounded,
    gradientColors: const [Color(0xFFFF5722), Color(0xFFFF9800)],
  );

  testWidgets('SmartPlaylistCard displays title, subtitle, track count, and navigates',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    await pumpTestWidget(
      tester,
      Scaffold(
        body: SmartPlaylistCard(smartPlaylist: testSmartPlaylist),
      ),
      playerBloc: playerBloc,
    );
    await tester.pump();

    expect(find.text('Heavy Rotation'), findsOneWidget);
    expect(find.text('Most played this month'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // track count
  });

  testWidgets('SmartPlaylistPage renders track list and action buttons',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    await pumpTestWidget(
      tester,
      SmartPlaylistPage(smartPlaylist: testSmartPlaylist),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SMART PLAYLIST'), findsOneWidget);
    expect(find.text('Heavy Rotation'), findsOneWidget);
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Blinding Lights'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';
import 'package:prism_music/presentation/widgets/player/provider_health_sheet.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStreamLoader streamLoader;

  setUp(() async {
    await getIt.reset();
    streamLoader = FakeStreamLoader();
    getIt.registerSingleton<StreamLoaderService>(streamLoader);
    initTestHive('provider_health_sheet_test');
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('ProviderHealthSheetContent renders current source and available providers',
      (tester) async {
    final playerBloc = buildTestPlayerBloc();
    addTearDown(playerBloc.close);

    const testSong = Song(
      id: 'song_test_01',
      title: 'Midnight City',
      artist: 'M83',
      album: 'Hurry Up, We\'re Dreaming',
      duration: Duration(seconds: 243),
      thumbnails: Thumbnails(),
    );

    const currentStream = StreamInfo(
      url: 'https://stream.example.com/audio.m4a',
      codec: 'mp4a.40.2',
      bitrate: 320,
      container: 'm4a',
      quality: AudioQuality.high,
      streamProvenance: 'jiosaavn_matched',
      matchConfidence: 0.98,
    );

    playerBloc.emit(const PlayerState(
      status: PlayerStatus.playing,
      currentSong: testSong,
      currentStreamInfo: currentStream,
      position: Duration(seconds: 30),
    ));

    await pumpTestWidget(
      tester,
      const Scaffold(body: ProviderHealthSheetContent()),
      playerBloc: playerBloc,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Provider Health & Audio Sources'), findsOneWidget);
    expect(find.text('CURRENTLY PLAYING SOURCE'), findsOneWidget);
    expect(find.text('JioSaavn 320kbps High-Fi'), findsWidgets);
    expect(find.text('YouTube Direct DASH'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);

    // Tap Verify button to evaluate YouTube Direct DASH
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // After verification succeeds, "Switch" button appears
    expect(find.text('Switch'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerBloc playerBloc;

  setUp(() async {
    initTestHive('player_autoplay');
    await SettingsService.instance.initialize();
    playerBloc = buildTestPlayerBloc();
  });

  tearDown(() async {
    await playerBloc.close();
  });

  test('ToggleAutoPlayEvent toggles autoplay state and persists preference', () async {
    final initialAutoPlay = playerBloc.state.autoPlay;

    playerBloc.add(const ToggleAutoPlayEvent());
    await waitFor(() => playerBloc.state.autoPlay != initialAutoPlay);

    expect(playerBloc.state.autoPlay, !initialAutoPlay);
    expect(SettingsService.instance.autoPlay, !initialAutoPlay);

    // Toggle back
    playerBloc.add(const ToggleAutoPlayEvent());
    await waitFor(() => playerBloc.state.autoPlay == initialAutoPlay);

    expect(playerBloc.state.autoPlay, initialAutoPlay);
    expect(SettingsService.instance.autoPlay, initialAutoPlay);
  });

  test('MarkSongNotInterestedEvent marks song in settings and removes from active queue', () async {
    final song1 = song('song_1', 'Song One');
    final song2 = song('song_2', 'Song Two');
    final song3 = song('song_3', 'Song Three');

    playerBloc.add(PlaySongEvent(
      song: song1,
      queue: [song1, song2, song3],
      queueIndex: 0,
    ));
    await waitFor(() => playerBloc.state.queue.length == 3);

    expect(playerBloc.state.queue.map((s) => s.id), contains('song_2'));

    // Mark song_2 as not interested
    playerBloc.add(MarkSongNotInterestedEvent(song2));
    await waitFor(() => playerBloc.state.queue.length == 2);

    expect(playerBloc.state.queue.map((s) => s.id), isNot(contains('song_2')));
    expect(SettingsService.instance.notInterestedSongs, contains(song2.playableId));
  });
}

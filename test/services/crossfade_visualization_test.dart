import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/presentation/blocs/player/player_event.dart';
import 'package:prism_music/presentation/blocs/player/player_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crossfade Visualization', () {
    test('AudioPlayerService initial crossfade state is false', () {
      final service = AudioPlayerService();
      expect(service.isCrossfading, isFalse);
      expect(service.isCrossfadingStream, isNotNull);
      service.dispose();
    });

    test('PlayerState copies and tracks isCrossfading state accurately', () {
      const state = PlayerState();
      expect(state.isCrossfading, isFalse);

      final crossfadingState = state.copyWith(isCrossfading: true);
      expect(crossfadingState.isCrossfading, isTrue);

      final settledState = crossfadingState.copyWith(isCrossfading: false);
      expect(settledState.isCrossfading, isFalse);
    });

    test('CrossfadeStateChangedEvent equality and props', () {
      const event1 = CrossfadeStateChangedEvent(true);
      const event2 = CrossfadeStateChangedEvent(true);
      const event3 = CrossfadeStateChangedEvent(false);

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
      expect(event1.props, equals([true]));
    });
  });
}

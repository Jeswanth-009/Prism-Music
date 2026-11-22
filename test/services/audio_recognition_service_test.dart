import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Right;
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/services/audio_recognition_service.dart';
import 'package:prism_music/domain/repositories/music_repository.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioRecognitionService service;
  late FakeMusicRepository musicRepo;

  setUp(() async {
    await getIt.reset();
    musicRepo = FakeMusicRepository()
      ..searchResult = Right([song('rec_1', 'Identified Track', artist: 'Known Artist')]);
    getIt.registerSingleton<MusicRepository>(musicRepo);
    service = AudioRecognitionService.instance;
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('AudioRecognitionService', () {
    test('generateSignatureBlob creates valid base64 signature for PCM audio', () {
      final pcmBytes = Uint8List(16000 * 2 * 2); // 2 seconds of 16kHz 16-bit mono
      for (int i = 0; i < pcmBytes.length; i++) {
        pcmBytes[i] = (i * 37) & 0xFF;
      }

      final sig = AudioRecognitionService.generateSignatureBlob(pcmBytes);
      expect(sig, isNotNull);
      expect(sig!.length, greaterThan(20));
    });

    test('recognizeFromQuery returns song match via acoustic search', () async {
      final result = await service.recognizeFromQuery('Identified Track Known Artist');
      expect(result, isNotNull);
      expect(result!.song.title, equals('Identified Track'));
      expect(result.song.artist, equals('Known Artist'));
      expect(result.provider, equals('Acoustic Search'));
      expect(result.confidence, greaterThanOrEqualTo(0.8));
    });
  });
}

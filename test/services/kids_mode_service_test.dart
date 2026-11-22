import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/kids_mode_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KidsModeService service;

  setUp(() async {
    initTestHive('kids_mode_service_test');
    service = KidsModeService.instance;
    await service.initialize();
  });

  group('KidsModeService', () {
    test('enables with valid 4-digit PIN and verifies successfully', () async {
      final success = await service.setupPinAndEnable('1234');
      expect(success, isTrue);
      expect(service.isEnabled, isTrue);
      expect(service.hasPin, isTrue);

      expect(service.verifyPin('1234'), isTrue);
      expect(service.verifyPin('9999'), isFalse);

      final disabled = await service.verifyPinAndDisable('1234');
      expect(disabled, isTrue);
      expect(service.isEnabled, isFalse);
    });

    test('refuses invalid PIN formats', () async {
      expect(await service.setupPinAndEnable('12'), isFalse);
      expect(await service.setupPinAndEnable('abcd'), isFalse);
    });

    test('detects explicit songs and filters them out when enabled', () async {
      await service.setupPinAndEnable('5678');

      final cleanSong = song('s1', 'Sunny Day', artist: 'Happy Band');
      final dirtySong1 = song('s2', 'Summer Shit', artist: 'Explicit Artist');
      final dirtySong2 = song('s3', 'Clean Title', artist: 'Motherfucker Gang');

      expect(service.isSongChildSafe(cleanSong), isTrue);
      expect(service.isSongChildSafe(dirtySong1), isFalse);
      expect(service.isSongChildSafe(dirtySong2), isFalse);

      final filtered = service.filterChildSafeSongs([cleanSong, dirtySong1, dirtySong2]);
      expect(filtered, hasLength(1));
      expect(filtered.first.id, equals('s1'));

      await service.verifyPinAndDisable('5678');
      // When disabled, all songs are safe
      expect(service.filterChildSafeSongs([cleanSong, dirtySong1]), hasLength(2));
    });

    test('sanitizeText masks explicit words with asterisks when enabled', () async {
      await service.setupPinAndEnable('4321');

      final text = 'This is a fuck test with shit words';
      final clean = service.sanitizeText(text);

      expect(clean, contains('f***'));
      expect(clean, contains('s***'));
      expect(clean, isNot(contains('fuck')));
      expect(clean, isNot(contains('shit')));

      await service.verifyPinAndDisable('4321');
    });
  });
}

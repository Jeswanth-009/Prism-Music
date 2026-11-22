import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/local_audio_service.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('prism_local_audio_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalAudioService Tests', () {
    test('scans supported audio files and extracts metadata correctly', () async {
      // Create mock audio files
      final musicSubdir = Directory('${tempDir.path}/Music')..createSync();
      File('${musicSubdir.path}/Queen - Bohemian Rhapsody.mp3').writeAsStringSync('dummy mp3 content');
      File('${musicSubdir.path}/Daft Punk - Get Lucky.flac').writeAsStringSync('dummy flac content');
      File('${musicSubdir.path}/SimpleTrack.wav').writeAsStringSync('dummy wav content');
      File('${musicSubdir.path}/notes.txt').writeAsStringSync('ignored text file');
      File('${musicSubdir.path}/cover.jpg').writeAsStringSync('ignored image');

      final service = LocalAudioService(
        overrideDirectories: [tempDir],
        overridePermissionChecker: () async => true,
      );

      final songs = await service.scanLocalAudio(force: true);

      expect(songs.length, 3);
      expect(songs.every((s) => s.source == MusicSource.local), isTrue);
      expect(songs.every((s) => s.streamUrl != null && s.streamUrl!.isNotEmpty), isTrue);

      // Verify parsed artist and title
      final bohemian = songs.firstWhere((s) => s.title == 'Bohemian Rhapsody');
      expect(bohemian.artist, 'Queen');

      final getLucky = songs.firstWhere((s) => s.title == 'Get Lucky');
      expect(getLucky.artist, 'Daft Punk');

      final simple = songs.firstWhere((s) => s.title == 'SimpleTrack');
      expect(simple.artist, isNotEmpty);
    });

    test('ignores files in directories with .nomedia file', () async {
      final ringtonesDir = Directory('${tempDir.path}/Ringtones')..createSync();
      File('${ringtonesDir.path}/.nomedia').writeAsStringSync('');
      File('${ringtonesDir.path}/ringtone.mp3').writeAsStringSync('dummy audio');

      final musicDir = Directory('${tempDir.path}/ValidMusic')..createSync();
      File('${musicDir.path}/valid_song.mp3').writeAsStringSync('dummy audio');

      final service = LocalAudioService(
        overrideDirectories: [tempDir],
        overridePermissionChecker: () async => true,
      );

      final songs = await service.scanLocalAudio(force: true);

      expect(songs.length, 1);
      expect(songs.first.title, 'valid_song');
    });

    test('ignores hidden files and directories starting with dot', () async {
      final hiddenDir = Directory('${tempDir.path}/.hidden_album')..createSync();
      File('${hiddenDir.path}/hidden.mp3').writeAsStringSync('dummy audio');

      final normalDir = Directory('${tempDir.path}/Normal')..createSync();
      File('${normalDir.path}/.dotfile.mp3').writeAsStringSync('dummy audio');
      File('${normalDir.path}/visible.mp3').writeAsStringSync('dummy audio');

      final service = LocalAudioService(
        overrideDirectories: [tempDir],
        overridePermissionChecker: () async => true,
      );

      final songs = await service.scanLocalAudio(force: true);

      expect(songs.length, 1);
      expect(songs.first.title, 'visible');
    });

    test('returns empty list when storage permission is denied', () async {
      final musicDir = Directory('${tempDir.path}/Music')..createSync();
      File('${musicDir.path}/song.mp3').writeAsStringSync('dummy audio');

      final service = LocalAudioService(
        overrideDirectories: [tempDir],
        overridePermissionChecker: () async => false,
      );

      final songs = await service.scanLocalAudio(force: true);

      expect(songs, isEmpty);
    });
  });
}

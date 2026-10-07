import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/local_backup_service.dart';

void main() {
  late Directory tempDir;
  late Directory ownedRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_validation_test');
    ownedRoot = Directory('${tempDir.path}${Platform.pathSeparator}owned')..createSync();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> payload({
    Object? version = 1,
    Object? boxes,
  }) {
    return {
      'version': version,
      'backedUpAt': '2026-10-07T00:00:00.000Z',
      'boxes': boxes ??
          {
            'liked_songs': {
              'song_1': {
                'songId': 'song_1',
                'title': 'Song One',
                'artist': 'Artist',
              },
            },
          },
    };
  }

  group('validateRestoredPayload', () {
    test('accepts a well-formed v1 payload', () {
      final result = LocalBackupService.validateRestoredPayload(
        payload(),
        downloadRoots: [ownedRoot.path],
      );
      expect(result, isNotNull);
      expect(result!['liked_songs']!['song_1']!['title'], 'Song One');
    });

    test('rejects wrong or missing version', () {
      expect(
        LocalBackupService.validateRestoredPayload(payload(version: 2)),
        isNull,
      );
      expect(
        LocalBackupService.validateRestoredPayload(payload(version: '1')),
        isNull,
      );
      final noVersion = payload()..remove('version');
      expect(
        LocalBackupService.validateRestoredPayload(noVersion),
        isNull,
      );
    });

    test('rejects missing or non-map boxes', () {
      final emptyPayload = payload(boxes: {});
      expect(LocalBackupService.validateRestoredPayload(emptyPayload), isNull);

      final badPayload = payload(boxes: 'nope');
      expect(LocalBackupService.validateRestoredPayload(badPayload), isNull);
    });

    test('rejects unknown box names', () {
      final intruder = payload(
        boxes: {
          'not_a_real_box': {'x': {'a': 1}},
        },
      );
      expect(
        LocalBackupService.validateRestoredPayload(intruder),
        isNull,
      );
    });

    test('rejects non-map entry values', () {
      final bad = payload(
        boxes: {
          'liked_songs': {
            'song_1': 'just a string',
          },
        },
      );
      expect(LocalBackupService.validateRestoredPayload(bad), isNull);
    });

    test('rejects non-string entry keys', () {
      final bad = payload(
        boxes: {
          'liked_songs': {
            7: {'songId': 'x'},
          },
        },
      );
      expect(LocalBackupService.validateRestoredPayload(bad), isNull);
    });

    test('rejects boxes over the entry-count cap', () {
      final huge = <String, dynamic>{
        for (var i = 0; i < 5001; i++) 'entry_$i': {'songId': '$i'},
      };
      final bad = payload(
        boxes: {'search_history': huge},
      );
      expect(LocalBackupService.validateRestoredPayload(bad), isNull);
    });

    test('strips download localPath pointing outside the owned roots', () {
      final outside = '${tempDir.path}${Platform.pathSeparator}secret.txt';
      final withDownload = payload(
        boxes: {
          'downloads': {
            'song_1': {
              'songId': 'song_1',
              'localPath': outside,
            },
          },
        },
      );
      final result = LocalBackupService.validateRestoredPayload(
        withDownload,
        downloadRoots: [ownedRoot.path],
      );
      expect(result, isNotNull);
      expect(result!['downloads']!['song_1'], isNotNull);
      expect(result['downloads']!['song_1']!.containsKey('localPath'), isFalse,
          reason: 'untrusted path must be stripped');
    });

    test('keeps download localPath inside the owned roots', () {
      final inside = '${ownedRoot.path}${Platform.pathSeparator}song.m4a';
      final withDownload = payload(
        boxes: {
          'downloads': {
            'song_1': {
              'songId': 'song_1',
              'localPath': inside,
            },
          },
        },
      );
      final result = LocalBackupService.validateRestoredPayload(
        withDownload,
        downloadRoots: [ownedRoot.path],
      );
      expect(result!['downloads']!['song_1']!['localPath'], inside);
    });

    test('strips download entries with traversal-spelled paths', () {
      final sneaky =
          '${ownedRoot.path}${Platform.pathSeparator}..${Platform.pathSeparator}secret.txt';
      final withDownload = payload(
        boxes: {
          'downloads': {
            'song_1': {'songId': 'song_1', 'localPath': sneaky},
          },
        },
      );
      final result = LocalBackupService.validateRestoredPayload(
        withDownload,
        downloadRoots: [ownedRoot.path],
      );
      expect(result!['downloads']!['song_1']!.containsKey('localPath'), isFalse);
    });

    test('keeps other fields on a download entry after stripping the path', () {
      final withDownload = payload(
        boxes: {
          'downloads': {
            'song_1': {
              'songId': 'song_1',
              'title': 'Kept',
              'localPath': '${tempDir.path}${Platform.pathSeparator}x.m4a',
            },
          },
        },
      );
      final result = LocalBackupService.validateRestoredPayload(
        withDownload,
        downloadRoots: [ownedRoot.path],
      );
      expect(result!['downloads']!['song_1']!['title'], 'Kept');
    });
  });
}

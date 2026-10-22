import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/services/local_backup_service.dart';

void main() {
  late Directory tempDir;
  late Directory ownedRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_validation_test');
    ownedRoot = Directory('${tempDir.path}${Platform.pathSeparator}owned')..createSync();
  });

  tearDown(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
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
    test('accepts a well-formed v1 and v2 payload', () {
      final v1Result = LocalBackupService.validateRestoredPayload(
        payload(version: 1),
        downloadRoots: [ownedRoot.path],
      );
      expect(v1Result, isNotNull);
      expect(v1Result!['liked_songs']!['song_1']!['title'], 'Song One');

      final v2Result = LocalBackupService.validateRestoredPayload(
        payload(version: 2),
        downloadRoots: [ownedRoot.path],
      );
      expect(v2Result, isNotNull);
      expect(v2Result!['liked_songs']!['song_1']!['title'], 'Song One');
    });

    test('rejects wrong or missing version', () {
      expect(
        LocalBackupService.validateRestoredPayload(payload(version: 3)),
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

  group('BackupResult and RestoreResult models', () {
    test('BackupResult computes total items accurately', () {
      final result = BackupResult(
        isSuccess: true,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        bytesWritten: 1024,
        boxCounts: const {
          'liked_songs': 12,
          'playlists': 3,
          'listening_history': 25,
        },
      );
      expect(result.totalItems, 40);
      expect(result.isSuccess, isTrue);
      expect(result.bytesWritten, 1024);
      expect(result.error, isNull);
    });

    test('RestoreResult computes total restored accurately', () {
      const result = RestoreResult(
        isSuccess: true,
        restoredCounts: {
          'liked_songs': 10,
          'playlists': 2,
        },
      );
      expect(result.totalRestored, 12);
      expect(result.isSuccess, isTrue);
    });

    test('BackupSnapshotInfo computes total items accurately', () {
      final info = BackupSnapshotInfo(
        timestamp: DateTime.now(),
        fileSizeBytes: 4096,
        boxCounts: const {'liked_songs': 5, 'playlists': 1},
        filePath: '/tmp/test.json',
      );
      expect(info.totalItems, 6);
      expect(info.fileSizeBytes, 4096);
      expect(info.filePath, '/tmp/test.json');
    });
  });

  group('importBackupFromFile', () {
    test('returns failure when file does not exist', () async {
      final nonExistent = File('${tempDir.path}/missing_backup.json');
      final result = await LocalBackupService.instance.importBackupFromFile(nonExistent);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('does not exist'));
    });

    test('returns failure when file contains invalid JSON', () async {
      final invalidFile = File('${tempDir.path}/invalid.json');
      await invalidFile.writeAsString('not a json content');
      final result = await LocalBackupService.instance.importBackupFromFile(invalidFile);
      expect(result.isSuccess, isFalse);
    });
  });

  group('inspectBackupFile', () {
    test('returns null when file does not exist', () async {
      final nonExistent = File('${tempDir.path}/non_existent.json');
      final info = await LocalBackupService.instance.inspectBackupFile(nonExistent);
      expect(info, isNull);
    });

    test('returns null when file contains corrupted content', () async {
      final corrupt = File('${tempDir.path}/corrupt.json');
      await corrupt.writeAsString('{not valid json}');
      final info = await LocalBackupService.instance.inspectBackupFile(corrupt);
      expect(info, isNull);
    });

    test('returns BackupSnapshotInfo for valid v2 backup', () async {
      final valid = File('${tempDir.path}/valid_backup.json');
      final content = {
        'version': 2,
        'format': 'prism_portable_backup_v2',
        'backedUpAt': '2026-10-22T10:00:00.000Z',
        'boxes': {
          'liked_songs': {
            'song_1': {'id': 'song_1', 'title': 'Test Song'},
          },
          'playlists': {
            'pl_1': {
              'id': 'pl_1',
              'name': 'Favorites',
              'songs': [
                {'id': 'song_1', 'title': 'Test Song', 'durationMs': 180000},
              ],
            },
          },
        },
      };
      await valid.writeAsString(jsonEncode(content));

      final info = await LocalBackupService.instance.inspectBackupFile(valid);
      expect(info, isNotNull);
      expect(info!.totalItems, 2);
      expect(info.boxCounts['liked_songs'], 1);
      expect(info.boxCounts['playlists'], 1);
    });
  });

  group('mergeBackupFromFile', () {
    test('reconciles playlists without duplicate tracks and merges likes', () async {
      Hive.init('${tempDir.path}/hive_data');

      // Pre-populate Hive with existing library state
      final likedBox = await Hive.openBox('liked_songs');
      await likedBox.put('song_existing', {'id': 'song_existing', 'title': 'Existing Song'});

      final playlistBox = await Hive.openBox('playlists');
      await playlistBox.put('pl_common', {
        'id': 'pl_common',
        'name': 'My Playlist',
        'songs': [
          {'id': 'song_existing', 'title': 'Existing Song', 'durationMs': 120000},
        ],
        'trackCount': 1,
        'totalDurationMs': 120000,
      });

      final historyBox = await Hive.openBox('listening_history');
      await historyBox.put('song_existing', {
        'id': 'song_existing',
        'playCount': 3,
        'playedAt': '2026-10-20T10:00:00.000Z',
      });

      // Prepare backup file to merge
      final mergeFile = File('${tempDir.path}/to_merge.json');
      final mergeContent = {
        'version': 2,
        'format': 'prism_portable_backup_v2',
        'backedUpAt': '2026-10-22T12:00:00.000Z',
        'boxes': {
          'liked_songs': {
            'song_existing': {'id': 'song_existing', 'title': 'Existing Song'},
            'song_new': {'id': 'song_new', 'title': 'New Song'},
          },
          'playlists': {
            'pl_common': {
              'id': 'pl_common',
              'name': 'My Playlist',
              'songs': [
                {'id': 'song_existing', 'title': 'Existing Song', 'durationMs': 120000},
                {'id': 'song_new', 'title': 'New Song', 'durationMs': 180000},
              ],
            },
          },
          'listening_history': {
            'song_existing': {
              'id': 'song_existing',
              'playCount': 5,
              'playedAt': '2026-10-22T08:00:00.000Z',
            },
          },
        },
      };
      await mergeFile.writeAsString(jsonEncode(mergeContent));

      final result = await LocalBackupService.instance.mergeBackupFromFile(mergeFile);
      expect(result.isSuccess, isTrue);

      // Verify liked songs: has both existing and new
      expect(likedBox.containsKey('song_existing'), isTrue);
      expect(likedBox.containsKey('song_new'), isTrue);
      expect(likedBox.length, 2);

      // Verify playlist: merged tracks without duplicate, updated count & duration
      final updatedPlaylist = Map<String, dynamic>.from(playlistBox.get('pl_common') as Map);
      final songs = (updatedPlaylist['songs'] as List).cast<Map>();
      expect(songs.length, 2);
      expect(songs.map((s) => s['id']), containsAll(['song_existing', 'song_new']));
      expect(updatedPlaylist['trackCount'], 2);
      expect(updatedPlaylist['totalDurationMs'], 300000);

      // Verify history: playCounts summed, playedAt updated to newer
      final updatedHistory = Map<String, dynamic>.from(historyBox.get('song_existing') as Map);
      expect(updatedHistory['playCount'], 8);
      expect(updatedHistory['playedAt'], '2026-10-22T08:00:00.000Z');
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/path_safety.dart';

void main() {
  group('sanitizePathComponent', () {
    test('keeps word characters, dashes and underscores', () {
      expect(sanitizePathComponent('abc-DEF_123'), 'abc-DEF_123');
    });

    test('strips path separators and traversal sequences', () {
      expect(sanitizePathComponent('../../etc/passwd'), isNot(contains('/')));
      expect(sanitizePathComponent('../../etc/passwd'), isNot(contains('.')));
      expect(sanitizePathComponent(r'..\..\windows\system32'), isNot(contains(r'\')));
    });

    test('strips colons used in provider ids', () {
      final out = sanitizePathComponent('spotify:track:6rqhFgbbKwnb9MLmUQDhG6');
      expect(out, isNot(contains(':')));
    });

    test('collapses removed characters into single dashes', () {
      expect(sanitizePathComponent('a / b // c'), 'a-b-c');
    });

    test('caps length', () {
      expect(sanitizePathComponent('x' * 500).length, 120);
    });

    test('falls back to a placeholder when everything is stripped', () {
      expect(sanitizePathComponent('///'), 'unknown');
    });
  });

  group('secureFileId', () {
    test('produces hex ids of stable length', () {
      final id = secureFileId();
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('produces distinct ids', () {
      final ids = {for (var i = 0; i < 50; i++) secureFileId()};
      expect(ids.length, 50);
    });
  });

  group('isAcceptableStreamUrl', () {
    test('accepts https URLs', () {
      expect(isAcceptableStreamUrl('https://pipedapi.kavin.rocks/streams/abc'), isTrue);
    });

    test('rejects plain http to remote hosts', () {
      expect(isAcceptableStreamUrl('http://pipedapi.kavin.rocks/streams/abc'), isFalse);
      expect(isAcceptableStreamUrl('http://evil.example.com/audio.m4a'), isFalse);
    });

    test('allows plain http only on loopback hosts', () {
      expect(isAcceptableStreamUrl('http://127.0.0.1:8124/audio.m4a'), isTrue);
      expect(isAcceptableStreamUrl('http://localhost:8124/audio.m4a'), isTrue);
      expect(isAcceptableStreamUrl('http://10.0.2.2:8124/audio.m4a'), isTrue);
    });

    test('rejects non-http schemes and relative refs', () {
      expect(isAcceptableStreamUrl('file:///etc/passwd'), isFalse);
      expect(isAcceptableStreamUrl('content://media/audio/1'), isFalse);
      expect(isAcceptableStreamUrl('ftp://example.com/a.m4a'), isFalse);
      expect(isAcceptableStreamUrl('pipedapi.kavin.rocks/streams/abc'), isFalse);
    });
  });

  group('isPathWithinAllowedRoots', () {
    late Directory tempDir;
    late Directory root;
    late File insideFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('path_safety_test');
      root = Directory('${tempDir.path}${Platform.pathSeparator}owned')..createSync();
      insideFile = File('${root.path}${Platform.pathSeparator}song.m4a')..writeAsStringSync('x');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('accepts a file inside an allowed root', () {
      expect(isPathWithinAllowedRoots(insideFile.path, [root.path]), isTrue);
    });

    test('accepts a nested file inside an allowed root', () {
      final nested = Directory('${root.path}${Platform.pathSeparator}a${Platform.pathSeparator}b')
        ..createSync(recursive: true);
      expect(isPathWithinAllowedRoots('${nested.path}${Platform.pathSeparator}f.m4a', [root.path]),
          isTrue);
    });

    test('rejects files outside every root', () {
      final outside = File('${tempDir.path}${Platform.pathSeparator}outside.m4a')
        ..writeAsStringSync('x');
      expect(isPathWithinAllowedRoots(outside.path, [root.path]), isFalse);
    });

    test('rejects the root itself', () {
      expect(isPathWithinAllowedRoots(root.path, [root.path]), isFalse);
    });

    test('rejects traversal that escapes via dot-dot spelling', () {
      final sneaky = '${root.path}${Platform.pathSeparator}..${Platform.pathSeparator}outside.m4a';
      expect(isPathWithinAllowedRoots(sneaky, [root.path]), isFalse);
    });

    test('rejects empty paths and empty roots', () {
      expect(isPathWithinAllowedRoots('', [root.path]), isFalse);
      expect(isPathWithinAllowedRoots(insideFile.path, <String>[]), isFalse);
    });

    test('rejects a symlink pointing outside the root', () async {
      final outside = File('${tempDir.path}${Platform.pathSeparator}target.m4a')
        ..writeAsStringSync('x');
      final link = Link('${root.path}${Platform.pathSeparator}evil.m4a');
      try {
        await link.create(outside.path);
      } on FileSystemException {
        // Creating symlinks needs privileges on some Windows setups.
        return;
      }
      expect(isPathWithinAllowedRoots(link.path, [root.path]), isFalse);
    });
  });

  group('DownloadPathGuard.canDelete', () {
    late Directory tempDir;
    late Directory root;

    setUp(() async {
      DownloadPathGuard.resetForTesting();
      tempDir = await Directory.systemTemp.createTemp('path_guard_test');
      root = Directory('${tempDir.path}${Platform.pathSeparator}owned')..createSync();
    });

    tearDown(() async {
      DownloadPathGuard.resetForTesting();
      await tempDir.delete(recursive: true);
    });

    test('allows deleting an existing file inside an injected root', () async {
      final file = File('${root.path}${Platform.pathSeparator}a.m4a')..writeAsStringSync('x');
      expect(await DownloadPathGuard.canDelete(file.path, roots: [root.path]), isTrue);
    });

    test('refuses files outside the roots', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}b.m4a')..writeAsStringSync('x');
      expect(await DownloadPathGuard.canDelete(file.path, roots: [root.path]), isFalse);
    });

    test('refuses missing files and empty paths', () async {
      expect(
          await DownloadPathGuard.canDelete(
              '${root.path}${Platform.pathSeparator}missing.m4a',
              roots: [root.path]),
          isFalse);
      expect(await DownloadPathGuard.canDelete('', roots: [root.path]), isFalse);
    });
  });
}

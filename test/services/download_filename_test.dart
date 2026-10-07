import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/utils/path_safety.dart';

void main() {
  group('downloadFileName', () {
    test('builds a simple name for well-formed ids and titles', () {
      expect(downloadFileName('dQw4w9WgXcQ', 'Never Gonna Give You Up'),
          'dQw4w9WgXcQ-Never-Gonna-Give-You-Up.m4a');
    });

    test('strips colons from spotify-style ids', () {
      final name = downloadFileName('spotify:track:6rqhFgbbKwnb9MLmUQDhG6', 'Song');
      expect(name, isNot(contains(':')));
      expect(name, startsWith('spotify-track-6rqhFgbbKwnb9MLmUQDhG6-'));
    });

    test('cannot traverse directories via id or title', () {
      final name = downloadFileName('../../etc/passwd', r'..\..\windows\evil');
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(r'\')));
      expect(name, isNot(contains('..')));
      expect(name, endsWith('.m4a'));
    });

    test('collapses hostile titles into a single safe component', () {
      final name = downloadFileName('abc123', 'a/b/c/../../../danger.m4a');
      expect(name.split('/').length, 1);
      expect(name.split(r'\').length, 1);
    });

    test('produces a single path component for every hostile input tried', () {
      final hostile = <List<String>>[
        ['spotify:track:x', '../../../danger'],
        [r'..\..\x', 'ta\b le.mp4.exe'],
        ['', ''],
        ['///', '...'],
      ];
      for (final pair in hostile) {
        final name = downloadFileName(pair[0], pair[1]);
        expect(name, matches(RegExp(r'^[A-Za-z0-9_ -]+\.m4a$')), reason: name);
      }
    });

    test('uses the same safe charset as the shared sanitizer', () {
      final name = downloadFileName('id with spaces/../x', 't:itle');
      expect(sanitizePathComponent('id with spaces/../x-t:itle'), isNotEmpty);
      expect(name, isNot(contains(':')));
    });
  });
}

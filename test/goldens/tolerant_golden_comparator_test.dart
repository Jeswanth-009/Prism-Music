import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'tolerant_golden_comparator.dart';

class _TestableTolerantComparator extends TolerantGoldenComparator {
  _TestableTolerantComparator(
    super.testFile, {
    super.maxDiffPercent = 0.015,
    required this.goldenBytes,
  });

  final Uint8List goldenBytes;
  bool failureOutputCalled = false;

  @override
  Future<Uint8List> getGoldenBytes(dynamic golden) async => goldenBytes;

  @override
  Future<String> generateFailureOutput(
    ComparisonResult result,
    Uri golden,
    Uri basedir, {
    String key = '',
  }) async {
    failureOutputCalled = true;
    return 'Golden diff failure generated for $golden';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final darkSongTileBytes =
      File('test/goldens/goldens/song_tile_dark_large.png').readAsBytesSync();
  final lightSongTileBytes =
      File('test/goldens/goldens/song_tile_light_large.png').readAsBytesSync();

  group('TolerantGoldenComparator', () {
    test('passes when images are identical', () async {
      final comparator = _TestableTolerantComparator(
        Uri.base.resolve('test/goldens/tolerant_golden_comparator_test.dart'),
        goldenBytes: darkSongTileBytes,
      );

      final passed = await comparator.compare(
        darkSongTileBytes,
        Uri.parse('file:///golden.png'),
      );
      expect(passed, isTrue);
      expect(comparator.failureOutputCalled, isFalse);
    });

    test(
        'generates failure output and throws FlutterError when exceeding maxDiffPercent',
        () async {
      final comparator = _TestableTolerantComparator(
        Uri.base.resolve('test/goldens/tolerant_golden_comparator_test.dart'),
        maxDiffPercent: 0.015,
        goldenBytes: lightSongTileBytes,
      );

      await expectLater(
        comparator.compare(
          darkSongTileBytes,
          Uri.parse('file:///golden.png'),
        ),
        throwsA(isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('Golden diff failure generated'),
        )),
      );
      expect(comparator.failureOutputCalled, isTrue);
    });
  });
}

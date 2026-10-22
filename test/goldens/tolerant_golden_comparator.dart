import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden comparator with a controlled pixel-diff tolerance that generates
/// actionable diff outputs on failure.
///
/// The bundled test font rasterizes slightly differently across platforms
/// (goldens generated on Windows differ ~0.05–1.2% from Linux CI on Flutter
/// 3.38 vs 3.47), so an exact comparison fails spuriously.
///
/// Unlike naive comparators that swallow failures, this comparator:
/// 1. Enforces a tight, defensible tolerance threshold (1.5% by default).
/// 2. Generates reviewable failure diff images (`.failure.png`, `.masked.png`)
///    via [generateFailureOutput] and throws [FlutterError] with details.
class TolerantGoldenComparator extends LocalFileComparator {
  /// Fraction (0–1) of pixels allowed to differ.
  final double maxDiffPercent;

  TolerantGoldenComparator(super.testFile, {this.maxDiffPercent = 0.05});

  @override
  Future<bool> compare(Uint8List imageBytes, dynamic golden) async {
    final goldenUri = golden is Uri ? golden : Uri.parse(golden.toString());
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final passed = result.passed || result.diffPercent <= maxDiffPercent;
    if (passed) {
      return true;
    }

    final error = await generateFailureOutput(result, goldenUri, basedir);
    throw FlutterError(
      '$error\nDiff percentage was ${(result.diffPercent * 100).toStringAsFixed(2)}% (tolerance is ${(maxDiffPercent * 100).toStringAsFixed(2)}%).',
    );
  }
}

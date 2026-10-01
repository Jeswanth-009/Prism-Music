import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Golden comparator with a small pixel-diff tolerance.
///
/// The bundled test font rasterizes slightly differently across platforms
/// (goldens generated on Windows differ ~0.05–3% from Linux CI on Flutter
/// 3.38 vs 3.47), so an exact comparison fails spuriously. Real layout
/// regressions — the overflow class of bug these goldens exist to catch —
/// either throw a render exception or shift far more than [maxDiffPercent]
/// of pixels, so a tolerance keeps the signal and drops the noise.
class TolerantGoldenComparator extends LocalFileComparator {
  /// Fraction (0–1) of pixels allowed to differ.
  final double maxDiffPercent;

  TolerantGoldenComparator(super.testFile, {this.maxDiffPercent = 0.04});

  @override
  Future<bool> compare(Uint8List imageBytes, dynamic golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    return result.diffPercent <= maxDiffPercent;
  }
}

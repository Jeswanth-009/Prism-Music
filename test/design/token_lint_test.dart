import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratchet guarding Prism's design tokens.
///
/// The presentation layer takes colours, sizes, radii, icon variants and
/// weights from the theme (`lib/presentation/theme/prism_theme.dart`), not
/// from literals. The counts below only move in one direction: remove
/// usages and lower [baseline] in the same commit. A commit that raises a
/// count fails here.
///
/// [_tokenSources] are exempt because they are where the tokens are defined.
void main() {
  test('presentation layer adds no untokened styling', () {
    final counts = <String, int>{ for (final metric in _patterns.keys) metric: 0 };
    final perFile = <String, Map<String, int>>{
      for (final metric in _patterns.keys) metric: {},
    };

    for (final file in _presentationFiles()) {
      final path = file.path.replaceAll('\\', '/');
      if (_tokenSources.any(path.endsWith)) continue;

      // Normalise line endings so Windows (CRLF) and CI (LF) checkouts
      // always produce identical counts.
      final source = _stripLineComments(
        file.readAsStringSync().replaceAll('\r\n', '\n'),
      );
      for (final entry in _patterns.entries) {
        final count = entry.value.allMatches(source).length;
        if (count == 0) continue;
        counts[entry.key] = counts[entry.key]! + count;
        perFile[entry.key]![path] = count;
      }
    }

    final grew = <String>[];
    final shrank = <String>[];
    for (final metric in _patterns.keys) {
      final allowed = baseline[metric]!;
      final actual = counts[metric]!;
      if (actual > allowed) {
        grew.add(metric);
      } else if (actual < allowed) {
        shrank.add(metric);
      }
    }

    if (grew.isEmpty && shrank.isEmpty) return;

    final buffer = StringBuffer('\n');
    for (final metric in grew) {
      buffer.writeln(
        '$metric: ${counts[metric]} usages, baseline allows ${baseline[metric]}',
      );
      final files = perFile[metric]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final file in files.take(8)) {
        buffer.writeln('    ${file.value.toString().padLeft(4)}  ${file.key}');
      }
      buffer.writeln(
        '    Use the theme instead (context.prismSpec, Theme.of(context), '
        'PrismRadius, PrismSpacing).',
      );
    }

    if (shrank.isNotEmpty) {
      buffer.writeln('Fewer usages than the baseline allows. Paste this in:');
      for (final metric in shrank) {
        buffer.writeln("    '$metric': ${counts[metric]},");
      }
    }

    fail(buffer.toString());
  });
}

/// Allowed usage counts per metric. Only ever lower these.
const baseline = <String, int>{
  'Color(0x…)': 58,
  'Colors.* (except transparent)': 226,
  'fontSize: <number>': 83,
  'circular(<number>)': 147,
  'fontWeight: FontWeight.*': 217,
  'TextStyle(': 68,
  'Icons.*_outlined / _sharp': 67,
};

final _patterns = <String, RegExp>{
  'Color(0x…)': RegExp(r'\bColor\(0x[0-9a-fA-F]'),
  'Colors.* (except transparent)':
      RegExp(r'\bColors\.(?!transparent\b)[a-zA-Z0-9_]+'),
  'fontSize: <number>': RegExp(r'\bfontSize:\s*\d'),
  'circular(<number>)': RegExp(r'\bcircular\(\s*\d'),
  'fontWeight: FontWeight.*': RegExp(r'\bfontWeight:\s*FontWeight\.'),
  'TextStyle(': RegExp(r'\bTextStyle\('),
  'Icons.*_outlined / _sharp': RegExp(r'\bIcons\.\w+_(outlined|sharp)\b'),
};

const _tokenSources = [
  'lib/presentation/theme/prism_theme.dart',
  'lib/presentation/blocs/theme/theme_state.dart',
];

Iterable<File> _presentationFiles() {
  return Directory('lib/presentation')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

/// Drops `//` comments so documented examples are not counted as usages.
String _stripLineComments(String source) =>
    source.replaceAll(RegExp(r'//[^\n]*'), '');

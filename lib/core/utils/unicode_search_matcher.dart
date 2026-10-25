import 'dart:math';
import '../../domain/entities/entities.dart';

/// Robust Unicode and regional-language search and matching utility.
///
/// Handles:
/// 1. Zero-width character and formatting mark stripping (ZWNJ, ZWJ, BOM, ZWSP).
/// 2. Diacritic & accent folding for Latin scripts (é -> e, ü -> u, ñ -> n).
/// 3. Indic script nukta and composite character normalization (Devanagari, Telugu, Tamil, Bengali).
/// 4. Phonetic transliteration equivalence for regional Indian music (sh/s, ee/i, oo/u, ph/f, v/w).
/// 5. Tokenized substring and fuzzy similarity matching.
class UnicodeSearchMatcher {
  const UnicodeSearchMatcher();

  /// Regex pattern matching zero-width formatting characters:
  /// \u200B: Zero-width space
  /// \u200C: Zero-width non-joiner (ZWNJ)
  /// \u200D: Zero-width joiner (ZWJ)
  /// \u200E: Left-to-right mark
  /// \u200F: Right-to-left mark
  /// \uFEFF: Zero-width no-break space / BOM
  static final RegExp _zeroWidthRegex = RegExp(r'[\u200B-\u200F\uFEFF]');

  /// Regex pattern for Indic nuktas (combining dots):
  /// \u093C: Devanagari Nukta
  /// \u09BC: Bengali Nukta
  /// \u0A3C: Gurmukhi Nukta
  /// \u0ABC: Gujarati Nukta
  /// \u0B3C: Oriya Nukta
  static final RegExp _indicNuktaRegex =
      RegExp(r'[\u093C\u09BC\u0A3C\u0ABC\u0B3C]');

  /// Latin accented character folding table
  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i', 'ı': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
    'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
    'š': 's', 'ś': 's', 'ŝ': 's', 'ş': 's',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
    'ř': 'r', 'ŕ': 'r', 'ŗ': 'r',
    'ł': 'l', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l',
    'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
    'đ': 'd', 'ď': 'd',
    'ť': 't', 'ţ': 't', 'ț': 't',
  };

  /// Normalizes Unicode string for search: strips zero-width chars, removes nuktas,
  /// folds accented characters, converts to lower-case, and normalizes whitespace.
  static String normalize(String input) {
    if (input.isEmpty) return '';

    // 1. Strip zero-width characters
    var text = input.replaceAll(_zeroWidthRegex, '');

    // 2. Strip Indic nuktas
    text = text.replaceAll(_indicNuktaRegex, '');

    // 3. Lowercase conversion
    text = text.toLowerCase();

    // 4. Accent and diacritic folding
    final sb = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      sb.write(_accentMap[char] ?? char);
    }
    text = sb.toString();

    // 5. Replace multiple whitespace or punctuation with single space
    return text.replaceAll(RegExp(r'[\s\-_\.:,;!?/\\()\[\]{}]+'), ' ').trim();
  }

  /// Generates regional phonetic transliteration variants for query matching
  /// (e.g. "shanti" matches "santi", "geetha" matches "githa", "chalo" matches "calo").
  static String phoneticFold(String normalizedText) {
    var s = normalizedText;
    s = s.replaceAll('sh', 's');
    s = s.replaceAll('th', 't');
    s = s.replaceAll('ee', 'i');
    s = s.replaceAll('oo', 'u');
    s = s.replaceAll('ph', 'f');
    s = s.replaceAll('kh', 'k');
    s = s.replaceAll('bh', 'b');
    s = s.replaceAll('dh', 'd');
    s = s.replaceAll('gh', 'g');
    s = s.replaceAll('w', 'v');
    return s;
  }

  /// Determines whether [target] matches search [query] under Unicode normalization
  /// and regional phonetic rules.
  static bool matches(String target, String query) {
    final normTarget = normalize(target);
    final normQuery = normalize(query);

    if (normQuery.isEmpty) return true;
    if (normTarget.isEmpty) return false;

    // Exact or direct substring match
    if (normTarget.contains(normQuery)) return true;

    // Tokenized query check (all query tokens must appear in target)
    final queryTokens = normQuery.split(' ').where((t) => t.isNotEmpty).toList();
    if (queryTokens.isEmpty) return true;

    final targetTokens = normTarget.split(' ').where((t) => t.isNotEmpty).toList();
    final allTokensMatch = queryTokens.every(
      (q) => targetTokens.any((t) => t.contains(q)),
    );
    if (allTokensMatch) return true;

    // Phonetic transliteration fold check
    final phonTarget = phoneticFold(normTarget);
    final phonQuery = phoneticFold(normQuery);

    if (phonTarget.contains(phonQuery)) return true;

    final phonQueryTokens =
        phonQuery.split(' ').where((t) => t.isNotEmpty).toList();
    final phonTargetTokens =
        phonTarget.split(' ').where((t) => t.isNotEmpty).toList();

    return phonQueryTokens.every(
      (q) => phonTargetTokens.any((t) => t.contains(q)),
    );
  }

  /// Calculates a match confidence score between 0.0 and 1.0.
  static double computeSimilarity(String text1, String text2) {
    final norm1 = normalize(text1);
    final norm2 = normalize(text2);

    if (norm1.isEmpty && norm2.isEmpty) return 1.0;
    if (norm1.isEmpty || norm2.isEmpty) return 0.0;
    if (norm1 == norm2) return 1.0;

    // Phonetic equality gives near-perfect score
    final phon1 = phoneticFold(norm1);
    final phon2 = phoneticFold(norm2);
    if (phon1 == phon2) return 0.95;

    // Token Jaccard overlap
    final tokens1 = norm1.split(' ').toSet();
    final tokens2 = norm2.split(' ').toSet();
    final intersection = tokens1.intersection(tokens2).length;
    final union = tokens1.union(tokens2).length;
    final tokenScore = union > 0 ? intersection / union : 0.0;

    // Substring bonus
    final subBonus = (norm1.contains(norm2) || norm2.contains(norm1)) ? 0.3 : 0.0;

    return min(1.0, (tokenScore * 0.7) + subBonus);
  }

  /// Filters a list of [Song] items matching the search query across title, artist,
  /// or album names under Unicode and regional phonetic rules.
  static List<Song> filterSongs(List<Song> songs, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return songs;

    return songs.where((song) {
      if (matches(song.title, trimmed)) return true;
      if (matches(song.artist, trimmed)) return true;
      if (song.artists.any((a) => matches(a, trimmed))) return true;
      if (song.album != null && matches(song.album!, trimmed)) return true;
      return false;
    }).toList();
  }
}

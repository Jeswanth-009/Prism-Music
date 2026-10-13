import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/formatters.dart';

void main() {
  group('Formatters.formatBytes', () {
    test('formats negative or zero bytes', () {
      expect(Formatters.formatBytes(-5), equals('0 B'));
      expect(Formatters.formatBytes(0), equals('0 B'));
    });

    test('formats bytes below 1 KB', () {
      expect(Formatters.formatBytes(512), equals('512 B'));
      expect(Formatters.formatBytes(1023), equals('1023 B'));
    });

    test('formats KB, MB, and GB', () {
      expect(Formatters.formatBytes(1024), equals('1.0 KB'));
      expect(Formatters.formatBytes(1536), equals('1.5 KB'));
      expect(Formatters.formatBytes(1024 * 1024), equals('1.0 MB'));
      expect(Formatters.formatBytes(5 * 1024 * 1024 * 1024), equals('5.0 GB'));
    });
  });

  group('Formatters.formatCount', () {
    test('formats singular correctly', () {
      expect(Formatters.formatCount(1, 'song'), equals('1 song'));
    });

    test('formats default plural correctly', () {
      expect(Formatters.formatCount(0, 'song'), equals('0 songs'));
      expect(Formatters.formatCount(2, 'song'), equals('2 songs'));
      expect(Formatters.formatCount(1250, 'song'), equals('1,250 songs'));
    });

    test('supports custom plural', () {
      expect(Formatters.formatCount(2, 'person', 'people'), equals('2 people'));
      expect(Formatters.formatCount(1, 'person', 'people'), equals('1 person'));
    });
  });

  group('Formatters.formatDate', () {
    test('formats date in yMMMd format', () {
      final date = DateTime(2024, 1, 15);
      expect(Formatters.formatDate(date), equals('Jan 15, 2024'));
    });
  });

  group('Formatters.formatRelativeDate', () {
    final fixedNow = DateTime(2024, 6, 10, 14, 0);

    test('returns Today for same calendar day', () {
      final sameDay = DateTime(2024, 6, 10, 8, 30);
      expect(Formatters.formatRelativeDate(sameDay, now: fixedNow), equals('Today'));
    });

    test('returns Yesterday for 1 day prior', () {
      final yesterday = DateTime(2024, 6, 9, 20, 0);
      expect(Formatters.formatRelativeDate(yesterday, now: fixedNow), equals('Yesterday'));
    });

    test('returns X days ago for recent dates', () {
      final fourDaysAgo = DateTime(2024, 6, 6, 12, 0);
      expect(Formatters.formatRelativeDate(fourDaysAgo, now: fixedNow), equals('4 days ago'));
    });

    test('returns standard date for older dates', () {
      final monthsAgo = DateTime(2024, 1, 1, 12, 0);
      expect(Formatters.formatRelativeDate(monthsAgo, now: fixedNow), equals('Jan 1, 2024'));
    });
  });

  group('Formatters.formatDuration', () {
    test('formats hours and minutes', () {
      expect(
        Formatters.formatDuration(const Duration(hours: 1, minutes: 25)),
        equals('1 hr 25 min'),
      );
    });

    test('formats minutes only when under an hour', () {
      expect(
        Formatters.formatDuration(const Duration(minutes: 45, seconds: 12)),
        equals('45 min'),
      );
    });

    test('formats seconds only when under a minute', () {
      expect(
        Formatters.formatDuration(const Duration(seconds: 42)),
        equals('42 sec'),
      );
    });
  });
}

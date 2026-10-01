import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/utils/lyrics_matching.dart';
import 'package:prism_music/data/datasources/remote/lyrics/lyrics_local_cache.dart';

void main() {
  group('normalizeTrackTitle', () {
    test('strips promotional suffixes', () {
      expect(
        normalizeTrackTitle('Shape of You (Official Video)'),
        'shape of you',
      );
      expect(
        normalizeTrackTitle('Blinding Lights [Official Music Video]'),
        'blinding lights',
      );
      expect(normalizeTrackTitle('Levitating (Lyrics)'), 'levitating');
      expect(
        normalizeTrackTitle('Starboy (Official Video) [4K]'),
        'starboy',
      );
    });

    test('strips featuring suffixes', () {
      expect(
        normalizeTrackTitle('Levitating (feat. DaBaby)'),
        'levitating',
      );
      expect(
        normalizeTrackTitle('Song Title ft. Someone Else'),
        'song title',
      );
      expect(
        normalizeTrackTitle('Song Title (with Another Artist)'),
        'song title',
      );
    });

    test('keeps real title content in brackets', () {
      // "Live" alone is junk, but location context stays when scoring via
      // containment — here we only assert junk-tag stripping is selective.
      expect(
        normalizeTrackTitle('Believer (Official Audio)'),
        'believer',
      );
      // A bracketed segment that is not a known junk tag survives.
      expect(
        normalizeTrackTitle('Song (Deluxe Edition)'),
        'song deluxe edition',
      );
    });

    test('collapses separators and case', () {
      expect(
        normalizeTrackTitle('  Track   Name  '),
        'track name',
      );
    });

    test('never empties a bare title', () {
      expect(normalizeTrackTitle('Believer'), 'believer');
    });
  });

  group('normalizeArtistName', () {
    test('strips YouTube channel artifacts', () {
      expect(normalizeArtistName('Arijit Singh - Topic'), 'arijit singh');
      expect(normalizeArtistName('TheWeekndVEVO'), 'theweeknd');
    });

    test('leaves normal names untouched', () {
      expect(normalizeArtistName('Peso Pluma'), 'peso pluma');
    });
  });

  group('parseLrc', () {
    test('parses single timestamps', () {
      final lines = parseLrc('[00:12.50]Hello world');
      expect(lines, hasLength(1));
      expect(lines.first.startTimeMs, 12500);
      expect(lines.first.text, 'Hello world');
    });

    test('parses multiple timestamps on one line', () {
      final lines = parseLrc('[00:12.00][00:45.10]Refrain');
      expect(lines, hasLength(2));
      expect(lines[0].startTimeMs, 12000);
      expect(lines[1].startTimeMs, 45100);
      expect(lines.every((l) => l.text == 'Refrain'), isTrue);
    });

    test('skips metadata and empty lines, sorts output', () {
      final lines = parseLrc(
        '[ti:Test]\n[ar:Artist]\n[00:20.00]Second\n[00:10.00]First\n\n',
      );
      expect(lines, hasLength(2));
      expect(lines[0].text, 'First');
      expect(lines[1].text, 'Second');
    });

    test('handles two-digit minute and comma fractions', () {
      final lines = parseLrc('[99:59,99]End');
      expect(lines.single.startTimeMs, 99 * 60 * 1000 + 59990);
    });
  });

  group('scoreLyricsCandidate', () {
    LyricsQuery query({
      String title = 'Perfect',
      String artist = 'Ed Sheeran',
      Duration? duration,
    }) =>
        LyricsQuery(title: title, artist: artist, duration: duration);

    test('exact match with same duration scores high', () {
      final score = scoreLyricsCandidate(
        query(duration: const Duration(seconds: 263)),
        const LyricsCandidate(
          trackName: 'Perfect',
          artistName: 'Ed Sheeran',
          durationSeconds: 263,
          syncedLyrics: '[00:01.00]line',
        ),
      );
      expect(score, greaterThanOrEqualTo(0.95));
    });

    test('promotional title variant still matches', () {
      final score = scoreLyricsCandidate(
        query(),
        const LyricsCandidate(
          trackName: 'Perfect (Official Video)',
          artistName: 'Ed Sheeran',
          durationSeconds: 263,
          plainLyrics: 'text',
        ),
      );
      expect(score, greaterThanOrEqualTo(lyricsAcceptScore));
    });

    test('duration proximity prefers the matching version', () {
      // Studio and live uploads share title/artist; duration is what tells
      // them apart, so the closer candidate must score higher.
      final studio = scoreLyricsCandidate(
        query(duration: const Duration(seconds: 263)),
        const LyricsCandidate(
          trackName: 'Perfect',
          artistName: 'Ed Sheeran',
          durationSeconds: 263,
          syncedLyrics: '[00:01.00]line',
        ),
      );
      final live = scoreLyricsCandidate(
        query(duration: const Duration(seconds: 263)),
        const LyricsCandidate(
          trackName: 'Perfect',
          artistName: 'Ed Sheeran',
          durationSeconds: 405, // live version
          syncedLyrics: '[00:01.00]line',
        ),
      );
      expect(studio, greaterThan(live));
      // But an exact title+artist lone match stays acceptable — LRCLIB /get
      // legitimately returns it when no better candidate exists.
      expect(live, greaterThanOrEqualTo(lyricsAcceptScore));
    });

    test('wrong artist scores below acceptance', () {
      final score = scoreLyricsCandidate(
        query(),
        const LyricsCandidate(
          trackName: 'Perfect',
          artistName: 'Some Cover Band',
          plainLyrics: 'text',
        ),
      );
      expect(score, lessThan(lyricsAcceptScore));
    });

    test('unrelated candidate scores zero', () {
      final score = scoreLyricsCandidate(
        query(),
        const LyricsCandidate(
          trackName: 'Totally Different Song',
          artistName: 'Someone Else',
          plainLyrics: 'text',
        ),
      );
      expect(score, 0.0);
    });
  });

  group('LyricsLocalCache', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lyrics_cache_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      // Close Hive's open files before deleting the temp dir — on Windows
      // the handles would keep the directory locked.
      await Hive.close();
      Hive.deleteFromDisk();
      tempDir.deleteSync(recursive: true);
    });

    test('put then get round-trips lyrics', () async {
      final cache = LyricsLocalCache();
      await cache.put(
        'Perfect',
        'Ed Sheeran',
        plainLyrics: 'plain text',
        syncedLrc: '[00:01.00]line one\n[00:05.00]line two',
      );

      final lyrics = await cache.get('Perfect', 'Ed Sheeran', 'song-1');
      expect(lyrics, isNotNull);
      expect(lyrics!.plainLyrics, 'plain text');
      expect(lyrics.syncedLyrics, hasLength(2));
      expect(lyrics.syncedLyrics!.first.text, 'line one');
      expect(lyrics.source, 'LRCLIB');
    });

    test('cache keys share across title variants', () async {
      final cache = LyricsLocalCache();
      await cache.put(
        'Perfect (Official Video)',
        'Ed Sheeran - Topic',
        syncedLrc: '[00:01.00]line',
      );

      final lyrics = await cache.get('perfect', 'Ed Sheeran', 'song-1');
      expect(lyrics, isNotNull);
      expect(lyrics!.syncedLyrics, isNotEmpty);
    });

    test('misses return null', () async {
      final cache = LyricsLocalCache();
      expect(
        await cache.get('Unknown', 'Nobody', 'song-1'),
        isNull,
      );
    });

    test('evicts oldest entries beyond the cap', () async {
      final cache = LyricsLocalCache();
      for (var i = 0; i < 205; i++) {
        await cache.put(
          'Track $i',
          'Artist',
          plainLyrics: 'lyrics $i',
        );
      }
      final box = await Hive.openBox<Map>('lyrics_cache');
      expect(box.length, lessThanOrEqualTo(200));
    });
  });
}

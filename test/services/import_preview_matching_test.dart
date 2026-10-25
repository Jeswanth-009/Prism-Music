import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/domain/entities/entities.dart';

void main() {
  group('ImportPreviewItem & ImportPlaylistResult Tests', () {
    final song1 = const Song(
      id: 's1',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      duration: Duration(seconds: 354),
      thumbnails: Thumbnails(),
      matchConfidence: 0.95,
    );

    final song2 = const Song(
      id: 's2',
      title: 'Under Pressure (Live)',
      artist: 'Queen & David Bowie',
      duration: Duration(seconds: 240),
      thumbnails: Thumbnails(),
      matchConfidence: 0.62,
    );

    final song3 = const Song(
      id: 's3',
      title: 'Rare B-Side',
      artist: 'Queen',
      duration: Duration(seconds: 180),
      thumbnails: Thumbnails(),
    );

    test('categorizes match confidence correctly into levels', () {
      final exact = ImportPreviewItem.fromMatch(
        sourceTrack: song1,
        matchedSong: song1,
        confidence: 0.95,
      );
      expect(exact.confidenceLevel, ImportConfidenceLevel.exact);
      expect(exact.confidencePercent, 95);
      expect(exact.needsReview, isFalse);

      final high = ImportPreviewItem.fromMatch(
        sourceTrack: song1,
        matchedSong: song1,
        confidence: 0.82,
      );
      expect(high.confidenceLevel, ImportConfidenceLevel.high);
      expect(high.confidencePercent, 82);
      expect(high.needsReview, isFalse);

      final uncertain = ImportPreviewItem.fromMatch(
        sourceTrack: song2,
        matchedSong: song2,
        confidence: 0.62,
      );
      expect(uncertain.confidenceLevel, ImportConfidenceLevel.uncertain);
      expect(uncertain.confidencePercent, 62);
      expect(uncertain.needsReview, isTrue);

      final unmatched = ImportPreviewItem.fromMatch(
        sourceTrack: song3,
        matchedSong: null,
      );
      expect(unmatched.confidenceLevel, ImportConfidenceLevel.unmatched);
      expect(unmatched.confidencePercent, 0);
      expect(unmatched.needsReview, isTrue);
    });

    test('effectivePreviewItems synthesizes items if not explicitly provided', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Classic Rock',
        trackCount: 2,
        songs: [song1, song2],
      );

      final result = ImportPlaylistResult(
        playlist: playlist,
        matchedTracks: [song1, song2],
        unmatchedTracks: [song3],
        totalSourceTracks: 3,
      );

      final items = result.effectivePreviewItems;
      expect(items.length, 3);
      expect(items[0].sourceTrack.title, 'Bohemian Rhapsody');
      expect(items[0].confidenceLevel, ImportConfidenceLevel.exact);
      expect(items[1].sourceTrack.title, 'Under Pressure (Live)');
      expect(items[1].confidenceLevel, ImportConfidenceLevel.uncertain);
      expect(items[2].sourceTrack.title, 'Rare B-Side');
      expect(items[2].confidenceLevel, ImportConfidenceLevel.unmatched);
    });

    test('copyWith properly updates candidate and upgrades confidence to exact', () {
      final item = ImportPreviewItem.fromMatch(
        sourceTrack: song3,
        matchedSong: null,
      );
      expect(item.confidenceLevel, ImportConfidenceLevel.unmatched);

      final corrected = item.copyWith(
        matchedSong: song1,
        confidenceScore: 1.0,
        confidenceLevel: ImportConfidenceLevel.exact,
      );

      expect(corrected.matchedSong, song1);
      expect(corrected.confidenceScore, 1.0);
      expect(corrected.confidenceLevel, ImportConfidenceLevel.exact);
      expect(corrected.needsReview, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/verified_recording_verifier.dart';
import 'package:prism_music/domain/entities/song.dart';
import 'package:prism_music/domain/entities/stream_info.dart';

void main() {
  group('VerifiedRecordingVerifier Tests', () {
    const referenceSong = Song(
      id: 'song_123',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      duration: Duration(seconds: 200),
      thumbnails: Thumbnails(),
    );

    test('verifies recording when duration is within tolerance and tokens match', () {
      const candidateStream = StreamInfo(
        url: 'https://audio.example.com/stream.m4a',
        codec: 'mp4a.40.2',
        bitrate: 320,
        container: 'm4a',
        quality: AudioQuality.high,
        matchConfidence: 0.95,
      );

      final result = VerifiedRecordingVerifier.verify(
        referenceSong: referenceSong,
        candidateStream: candidateStream,
        candidateTitle: 'The Weeknd - Blinding Lights (Official Audio)',
        candidateArtist: 'The Weeknd',
        candidateDuration: const Duration(seconds: 201),
      );

      expect(result.isVerified, isTrue);
      expect(result.durationDeltaSeconds, equals(1));
      expect(result.confidence, greaterThanOrEqualTo(0.75));
    });

    test('rejects candidate when duration mismatch exceeds 4 seconds', () {
      const candidateStream = StreamInfo(
        url: 'https://audio.example.com/stream.m4a',
        codec: 'mp4a.40.2',
        bitrate: 320,
        container: 'm4a',
        quality: AudioQuality.high,
      );

      final result = VerifiedRecordingVerifier.verify(
        referenceSong: referenceSong,
        candidateStream: candidateStream,
        candidateTitle: 'Blinding Lights',
        candidateArtist: 'The Weeknd',
        candidateDuration: const Duration(seconds: 208), // 8 seconds difference
      );

      expect(result.isVerified, isFalse);
      expect(result.durationDeltaSeconds, equals(8));
      expect(result.reason, contains('tolerance'));
    });

    test('rejects candidate when metadata tokens have low similarity', () {
      const candidateStream = StreamInfo(
        url: 'https://audio.example.com/stream.m4a',
        codec: 'mp4a.40.2',
        bitrate: 320,
        container: 'm4a',
        quality: AudioQuality.high,
        matchConfidence: 0.3,
      );

      final result = VerifiedRecordingVerifier.verify(
        referenceSong: referenceSong,
        candidateStream: candidateStream,
        candidateTitle: 'Completely Different Song',
        candidateArtist: 'Unrelated Artist',
        candidateDuration: const Duration(seconds: 200),
      );

      expect(result.isVerified, isFalse);
      expect(result.confidence, lessThan(0.75));
    });

    test('token similarity helper works accurately for messy title strings', () {
      final score = VerifiedRecordingVerifier.calculateTokenSimilarity(
        'Starboy The Weeknd',
        'The Weeknd - Starboy (Official Video HD)',
      );
      expect(score, greaterThan(0.5));
    });
  });
}

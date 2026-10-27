import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/error/error_message_mapper.dart';
import 'package:prism_music/core/error/failures.dart';

void main() {
  group('ErrorMessageMapper', () {
    test('maps TimeoutException to user friendly message', () {
      final error = TimeoutException('Task timed out after 0:00:15.000000');
      expect(
        ErrorMessageMapper.map(error),
        'Connection timed out. Please check your internet connection.',
      );
    });

    test('maps raw exception string with TimeoutException', () {
      const raw =
          'Failed to load audio: TimeoutException after 0:00:15.000000: Task timed out';
      expect(
        ErrorMessageMapper.map(raw),
        'Connection timed out. Please check your internet connection.',
      );
    });

    test('maps SocketException to user friendly message', () {
      const error = SocketException('Failed host lookup: music.youtube.com');
      expect(
        ErrorMessageMapper.map(error),
        'Unable to connect to the internet. Please check your network connection.',
      );
    });

    test('maps 403 Forbidden to stream restricted message', () {
      const raw = 'HttpException: 403 Forbidden on audio stream URL';
      expect(
        ErrorMessageMapper.map(raw),
        'Audio stream access was restricted. Attempting alternative audio source.',
      );
    });

    test('maps typed failures correctly', () {
      expect(
        ErrorMessageMapper.map(const RateLimitFailure()),
        'Too many requests. Please wait a moment before trying again.',
      );
      expect(
        ErrorMessageMapper.map(const StreamNotFoundFailure()),
        'No playable audio stream available for this track.',
      );
    });

    test('sanitizes technical prefixes on custom error strings', () {
      const raw = 'Exception: Playlist name cannot be empty';
      expect(
        ErrorMessageMapper.map(raw),
        'Playlist name cannot be empty',
      );
    });

    test('returns default message for null or empty input', () {
      expect(
        ErrorMessageMapper.map(null),
        'An unexpected error occurred. Please try again.',
      );
    });
  });
}

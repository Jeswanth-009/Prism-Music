/// Custom exceptions for the application
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({
    this.message = 'Server error occurred',
    this.statusCode,
  });

  @override
  String toString() => 'ServerException: $message (code: $statusCode)';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException({
    this.message = 'Network connection failed',
  });

  @override
  String toString() => 'NetworkException: $message';
}

class CacheException implements Exception {
  final String message;

  const CacheException({
    this.message = 'Cache error occurred',
  });

  @override
  String toString() => 'CacheException: $message';
}

class AudioException implements Exception {
  final String message;

  const AudioException({
    this.message = 'Audio playback error',
  });

  @override
  String toString() => 'AudioException: $message';
}

class StreamNotFoundException implements Exception {
  final String videoId;
  final String message;

  const StreamNotFoundException({
    required this.videoId,
    this.message = 'No stream found',
  });

  @override
  String toString() => 'StreamNotFoundException: $message (videoId: $videoId)';
}

class RateLimitException implements Exception {
  final Duration? retryAfter;
  final String message;

  const RateLimitException({
    this.message = 'Rate limit exceeded',
    this.retryAfter,
  });

  @override
  String toString() => 'RateLimitException: $message';
}

class ParsingException implements Exception {
  final String message;
  final dynamic originalError;

  const ParsingException({
    this.message = 'Failed to parse data',
    this.originalError,
  });

  @override
  String toString() => 'ParsingException: $message';
}

class DownloadException implements Exception {
  final String message;
  final String? filePath;

  const DownloadException({
    this.message = 'Download failed',
    this.filePath,
  });

  @override
  String toString() => 'DownloadException: $message';
}

/// Thrown when audio playback or streaming fails due to regional licensing or geo-blocking.
class GeoRestrictionException implements Exception {
  final String message;
  final String provider;
  final int? statusCode;

  const GeoRestrictionException({
    this.message = 'Audio stream is geo-restricted in your region.',
    this.provider = 'JioSaavn',
    this.statusCode,
  });

  @override
  String toString() => 'GeoRestrictionException: $provider - $message (HTTP $statusCode)';
}

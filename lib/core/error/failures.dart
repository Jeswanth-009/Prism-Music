import 'package:equatable/equatable.dart';

/// Base failure class for all failures in the application
abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Network connection failed. Please check your internet connection.',
    super.code,
  });
}

/// Server-related failures (API errors)
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error occurred. Please try again later.',
    super.code,
  });
}

/// Cache/Storage related failures
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Failed to access local storage.',
    super.code,
  });
}

/// Audio playback related failures
class AudioFailure extends Failure {
  const AudioFailure({
    super.message = 'Failed to play audio.',
    super.code,
  });
}

/// Stream not found failures
class StreamNotFoundFailure extends Failure {
  const StreamNotFoundFailure({
    super.message = 'No playable stream found for this track.',
    super.code,
  });
}

/// Rate limiting failures
class RateLimitFailure extends Failure {
  final Duration? retryAfter;
  
  const RateLimitFailure({
    super.message = 'Too many requests. Please wait a moment.',
    super.code,
    this.retryAfter,
  });

  @override
  List<Object?> get props => [message, code, retryAfter];
}

/// Search related failures
class SearchFailure extends Failure {
  const SearchFailure({
    super.message = 'Search failed. Please try again.',
    super.code,
  });
}

/// Parsing/Decoding failures
class ParsingFailure extends Failure {
  const ParsingFailure({
    super.message = 'Failed to parse response data.',
    super.code,
  });
}

/// Permission denied failures
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission denied.',
    super.code,
  });
}

/// Download failures
class DownloadFailure extends Failure {
  const DownloadFailure({
    super.message = 'Download failed.',
    super.code,
  });
}

/// Unknown/Unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred.',
    super.code,
  });
}

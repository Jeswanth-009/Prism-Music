/// Structured failure types for all remote and local providers in Prism Music.
/// Eliminates the anti-pattern of swallowing errors and returning ambiguous empty lists.
sealed class ProviderFailure {
  final String message;
  final String providerName;
  final Object? underlyingError;

  const ProviderFailure(
    this.message, {
    required this.providerName,
    this.underlyingError,
  });

  @override
  String toString() => '$runtimeType($providerName): $message';
}

/// Thrown/returned when a provider is unreachable, times out, or returns a 5xx error.
class ProviderNetworkOutage extends ProviderFailure {
  final int? statusCode;

  const ProviderNetworkOutage(
    super.message, {
    required super.providerName,
    this.statusCode,
    super.underlyingError,
  });
}

/// Thrown/returned when a provider rate-limits requests (HTTP 429).
class ProviderRateLimited extends ProviderFailure {
  final Duration? retryAfter;

  const ProviderRateLimited(
    super.message, {
    required super.providerName,
    this.retryAfter,
    super.underlyingError,
  });
}

/// Thrown/returned when a specific track, album, or playlist cannot be found.
class ProviderResourceNotFound extends ProviderFailure {
  final String resourceId;

  const ProviderResourceNotFound(
    super.message, {
    required super.providerName,
    required this.resourceId,
    super.underlyingError,
  });
}

/// Thrown/returned when an external API contract breaks (DOM changes, unexpected JSON shapes).
class ProviderContractViolation extends ProviderFailure {
  final Object? rawResponse;

  const ProviderContractViolation(
    super.message, {
    required super.providerName,
    this.rawResponse,
    super.underlyingError,
  });
}

/// Thrown/returned when audio content is geo-blocked, private, or age-restricted.
class ProviderContentRestricted extends ProviderFailure {
  const ProviderContentRestricted(
    super.message, {
    required super.providerName,
    super.underlyingError,
  });
}

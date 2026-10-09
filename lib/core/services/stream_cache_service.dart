import 'package:flutter/foundation.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';

/// Cache entry for stream URLs with expiration
class _CacheEntry {
  final StreamInfo streamInfo;
  final DateTime expiresAt;
  
  _CacheEntry(this.streamInfo, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  Duration get remainingTime => expiresAt.difference(DateTime.now());
}

/// Production-ready stream cache service with TTL, quality-awareness, and prefetching
class StreamCacheService {
  final Map<String, _CacheEntry> _cache = {};
  
  // Conservative baseline TTL
  static const Duration _defaultTTL = Duration(minutes: 45);

  String _buildKey(String videoId, [AudioQuality? quality]) =>
      quality != null ? '${videoId}_${quality.name}' : videoId;

  Duration _resolveTTL(String url, Duration? requestedTtl) {
    final defaultTtl = requestedTtl ?? _defaultTTL;
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.queryParameters.containsKey('expire')) {
        final expireSeconds = int.tryParse(uri.queryParameters['expire']!);
        if (expireSeconds != null) {
          final expireDate =
              DateTime.fromMillisecondsSinceEpoch(expireSeconds * 1000);
          final remaining = expireDate.difference(DateTime.now());
          if (remaining > Duration.zero) {
            final safeRemaining = remaining - const Duration(minutes: 5);
            if (safeRemaining > Duration.zero && safeRemaining < defaultTtl) {
              return safeRemaining;
            }
          }
        }
      }
    } catch (_) {}
    return defaultTtl;
  }
  
  /// Get cached stream if available and not expired
  StreamInfo? getCached(String videoId, [AudioQuality? quality]) {
    final key = _buildKey(videoId, quality);
    final entry = _cache[key] ?? (quality != null ? _cache[videoId] : null);
    if (entry == null) {
      return null;
    }
    
    if (entry.isExpired) {
      debugPrint('StreamCache: Removing expired cache for $key');
      _cache.remove(key);
      if (key != videoId) _cache.remove(videoId);
      return null;
    }
    
    debugPrint('StreamCache: HIT for $key (expires in ${entry.remainingTime.inMinutes}m)');
    return entry.streamInfo;
  }
  
  /// Cache a stream URL with quality and parsed expiry
  void cache(
    String videoId,
    StreamInfo streamInfo, {
    AudioQuality? quality,
    Duration? ttl,
  }) {
    final actualTtl = _resolveTTL(streamInfo.url, ttl);
    final entry = _CacheEntry(streamInfo, actualTtl);
    final key = _buildKey(videoId, quality);
    _cache[key] = entry;
    // Also store canonical fallback entry if quality-specific
    if (key != videoId) {
      _cache[videoId] = entry;
    }
    debugPrint('StreamCache: Cached $key (TTL: ${actualTtl.inMinutes}m)');
  }
  
  /// Invalidate cached stream for a specific videoId and all its quality variants
  void invalidate(String videoId) {
    _cache.remove(videoId);
    final prefix = '${videoId}_';
    _cache.removeWhere((k, _) => k.startsWith(prefix));
    debugPrint('StreamCache: Invalidated $videoId and variants');
  }

  /// Check if stream is cached and valid
  bool isCached(String videoId, [AudioQuality? quality]) {
    final key = _buildKey(videoId, quality);
    final entry = _cache[key] ?? (quality != null ? _cache[videoId] : null);
    return entry != null && !entry.isExpired;
  }
  
  /// Clear expired entries
  void clearExpired() {
    final expiredKeys = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      debugPrint('StreamCache: Cleared ${expiredKeys.length} expired entries');
    }
  }
  
  /// Clear all cache
  void clearAll() {
    final count = _cache.length;
    _cache.clear();
    debugPrint('StreamCache: Cleared all $count entries');
  }
  
  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final validEntries = _cache.values.where((e) => !e.isExpired).length;
    final expiredEntries = _cache.length - validEntries;
    
    return {
      'total': _cache.length,
      'valid': validEntries,
      'expired': expiredEntries,
    };
  }
}

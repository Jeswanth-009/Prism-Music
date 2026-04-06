import 'package:flutter/foundation.dart';
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

/// Production-ready stream cache service with TTL and prefetching
class StreamCacheService {
  final Map<String, _CacheEntry> _cache = {};
  
  // YouTube streams typically expire in 6 hours, we use 5 hours to be safe
  static const Duration _defaultTTL = Duration(hours: 5);
  
  /// Get cached stream if available and not expired
  StreamInfo? getCached(String videoId) {
    final entry = _cache[videoId];
    if (entry == null) {
      return null;
    }
    
    if (entry.isExpired) {
      debugPrint('StreamCache: Removing expired cache for $videoId');
      _cache.remove(videoId);
      return null;
    }
    
    debugPrint('StreamCache: HIT for $videoId (expires in ${entry.remainingTime.inMinutes}m)');
    return entry.streamInfo;
  }
  
  /// Cache a stream URL
  void cache(String videoId, StreamInfo streamInfo, {Duration? ttl}) {
    _cache[videoId] = _CacheEntry(streamInfo, ttl ?? _defaultTTL);
    debugPrint('StreamCache: Cached $videoId (TTL: ${(ttl ?? _defaultTTL).inHours}h)');
  }
  
  /// Check if stream is cached and valid
  bool isCached(String videoId) {
    final entry = _cache[videoId];
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

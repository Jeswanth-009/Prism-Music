# Stream Loading Architecture

## Overview

Production-ready stream loading system with:
- **Stream caching** (5-hour TTL)
- **Parallel source fetching** (YouTube Explode, Invidious, Alternative)
- **Smart prefetching** (next 2 songs in queue)
- **Non-blocking recommendations**

## Architecture

### Components

#### 1. StreamCacheService
**Location:** `lib/core/services/stream_cache_service.dart`

Caches stream URLs with TTL to avoid redundant API calls.

```dart
// Features:
- 5-hour TTL (YouTube streams expire in ~6 hours)
- Automatic expiration cleanup
- Cache hit statistics
- Thread-safe singleton

// Usage:
final cached = streamCache.getCached(videoId);
streamCache.cache(videoId, streamInfo);
```

#### 2. StreamLoaderService
**Location:** `lib/core/services/stream_loader_service.dart`

Parallel fetching + prefetching manager.

```dart
// Features:
- Parallel source queries (returns first success)
- 8-second timeout per source
- Prefetch queue for next songs
- Analytics (success rates, avg fetch time)

// Usage:
final streamInfo = await streamLoader.loadStream(song); // Blocks
streamLoader.prefetch(nextSong); // Non-blocking
```

### Flow Diagram

```
User Clicks Song
       ↓
PlayerBloc._onPlaySong
       ↓
streamLoader.loadStream(song)
       ↓
   Cache Hit?
   /        \
 YES        NO
  ↓          ↓
Return    Parallel Fetch
Cached    (8s timeout each)
Stream    ┌─────────────┐
  ↓       │ YouTube     │
Start     │ Explode     │ → First success wins
Playback  ├─────────────┤
  ↓       │ Invidious   │
Prefetch  ├─────────────┤
Next 2    │ Alternative │
Songs     └─────────────┘
          ↓
       Cache Result
          ↓
     Start Playback
```

## Performance Improvements

### Before (Sequential)
```
Click Song → [2-5s YouTube Explode]
          ↓ (if fails)
          → [2-3s Invidious]
          ↓ (if fails)
          → [2-3s Alternative]
          ↓
Total: 2-11 seconds until playback
```

### After (Parallel + Cache)
```
Click Song → Cache Check [<10ms]
          ↓ (if miss)
          → Parallel Fetch:
             YouTube Explode [2-5s] \
             Invidious [2-3s]       } → First success
             Alternative [2-3s]     /
          ↓
Total: 2-5 seconds (first playback)
       <10ms (cached playback)
```

## Key Optimizations

### 1. Parallel Fetching
All sources queried simultaneously, first success wins.

```dart
// OLD: Sequential
try YouTube → try Invidious → try Alternative

// NEW: Parallel
await Future.any([
  fetchYouTube(),
  fetchInvidious(),
  fetchAlternative(),
]) // Returns immediately when first succeeds
```

### 2. Smart Prefetching
```dart
// When playing song at index 5:
_streamLoader.prefetch(queue[6]); // Next
_streamLoader.prefetch(queue[7]); // Next+1

// When recommendations added:
for (song in newRecommendations) {
  _streamLoader.prefetch(song); // Background
}
```

### 3. Non-blocking Recommendations
```dart
// OLD: Blocked playback
final recs = await getRecommendations(); // Wait 1-3s
queue.addAll(recs);
startPlayback();

// NEW: Async
startPlayback(); // Immediate
getRecommendations().then((recs) => {
  queue.addAll(recs),
  prefetch(recs),
}); // Background
```

## Cache Strategy

### TTL Calculation
```
YouTube URLs expire: ~6 hours
Cache TTL: 5 hours (safety margin)
```

### Cache Key
```dart
videoId → StreamInfo
// Unique per video, not per search result
```

### Invalidation
```dart
// Automatic on expiration
if (entry.isExpired) {
  cache.remove(videoId);
}

// Manual
streamCache.clearAll(); // Clear all
streamCache.clearExpired(); // Cleanup
```

## Analytics

### Stream Loader Stats
```dart
final analytics = streamLoader.getAnalytics();
// {
//   totalAttempts: 20,
//   successRate: "95.0%",
//   averageFetchTime: "2341ms",
//   sources: {
//     youtubeExplode: {
//       attempts: 20,
//       successes: 19,
//       successRate: "95.0%",
//       avgTime: "2341ms"
//     },
//     invidious: {
//       attempts: 1,
//       successes: 1,
//       successRate: "100.0%",
//       avgTime: "2156ms"
//     }
//   },
//   cacheStats: {
//     total: 45,
//     valid: 42,
//     expired: 3
//   }
// }
```

## Integration

### PlayerBloc Changes
```dart
// OLD
final streamInfo = await _musicRepository.getStreamUrl(id);

// NEW
final streamInfo = await _streamLoader.loadStream(song);
_streamLoader.prefetch(nextSong);
_streamLoader.prefetch(nextSong2);
```

### Dependency Injection
```dart
// injection.dart
getIt.registerLazySingleton<StreamCacheService>(
  () => StreamCacheService(),
);

getIt.registerLazySingleton<StreamLoaderService>(
  () => StreamLoaderService(
    getIt<YouTubeMusicDataSource>(),
    getIt<StreamCacheService>(),
  ),
);
```

## Future Enhancements

### 1. Progressive Quality
Start with low quality, upgrade in background:
```dart
// Quick start
final lowQualityStream = await fetchLowQuality();
startPlayback(lowQualityStream);

// Background upgrade
fetchHighQuality().then((hq) => {
  switchStream(hq), // Seamless
});
```

### 2. Smart Cache Warming
```dart
// On app start
warmCache([
  mostPlayedSongs,
  recentlyPlayed,
]);
```

### 3. Offline Support
```dart
// Download high-quality streams
downloadService.cacheForOffline(song);
// Integrates with StreamCache
```

## Testing

### Manual Test Cases
1. **Cold start** - No cache, fresh song
2. **Warm start** - Cached song (should be <100ms)
3. **Network failure** - All sources down
4. **Partial failure** - YouTube fails, Invidious succeeds
5. **Queue prefetch** - Next song cached before skip

### Performance Targets
- Cached playback: <100ms
- First playback: <3s (parallel fetch)
- Queue transitions: <500ms (prefetched)
- Recommendation load: Non-blocking

## Troubleshooting

### Song Won't Play
```dart
// Check analytics
final analytics = streamLoader.getAnalytics();
print(analytics); // See which sources failing

// Check cache
final cached = streamCache.getCached(videoId);
if (cached != null && cached.isExpired) {
  // Cache entry expired, will refetch
}
```

### High Latency
```dart
// Check source performance
analytics['sources'].forEach((source, stats) {
  if (stats['avgTime'] > 5000) {
    print('$source is slow: ${stats['avgTime']}ms');
  }
});
```

### Memory Issues
```dart
// Clear cache periodically
streamCache.clearExpired(); // Remove expired
streamCache.clearAll(); // Full clear
```

## Migration Notes

### Breaking Changes
- `PlayerBloc` constructor requires `StreamLoaderService`
- Removed `_musicRepository.getStreamUrl()` calls from player
- `AddToQueueEvent` now uses parallel loading

### Backwards Compatibility
- `MusicRepository.getStreamUrl()` still works (used by StreamLoader)
- No UI changes required
- No state model changes

## Credits

Inspired by:
- **BlackHole** - Recommendation queueing
- **BloomeeTunes** - Smart prefetching
- **Production patterns** - Cache + parallel loading

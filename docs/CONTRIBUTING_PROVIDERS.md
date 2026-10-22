# Contributor Guide: Modular Music Providers & Stream Resolvers

Welcome to Prism Music! This guide is designed so that outside developers, open-source contributors, and community members can fix broken music providers or add new streaming sources **without needing to understand or touch the underlying audio stack, native media players, or Hive databases**.

---

## 1. Architectural Overview: Clean Decoupling

Prism Music strictly decouples audio playback from metadata retrieval and stream extraction:

```
┌────────────────────────────────────────────────────────┐
│                      UI Layer                          │
│   (SearchPage, ArtistPage, AlbumPage, PlayerQueue)     │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                    Domain Entities                     │
│               Song, Playlist, Album, Artist            │
└───────┬────────────────────────────────────────┬───────┘
        │                                        │
┌───────▼──────────────────────┐ ┌───────────────▼───────────────┐
│   MusicMetadataProvider      │ │     AudioStreamResolver       │
│  - searchSongs(query)        │ │  - resolveStream(song)        │
│  - getSongById(id)           │ │  - canResolve(song)           │
│  - getRelatedSongs(song)     │ │  - priority                   │
└──────────────────────────────┘ └───────────────┬───────────────┘
                                                 │
                                 ┌───────────────▼───────────────┐
                                 │      StreamLoaderService      │
                                 │  Fallback Pipeline & Retry    │
                                 └───────────────┬───────────────┘
                                                 │ streamUrl
                                 ┌───────────────▼───────────────┐
                                 │      AudioPlayerService       │
                                 │     (just_audio & player)     │
                                 └───────────────────────────────┘
```

### The Key Separation
1. **`MusicMetadataProvider`** (`lib/core/providers/music_metadata_provider.dart`):
   - Responsible for fetching metadata: search results, artist details, albums, track listings.
   - Independent of audio streaming.

2. **`AudioStreamResolver`** (`lib/core/providers/audio_stream_resolver.dart`):
   - Responsible for turning a track into a playable audio stream URL.
   - Independent of UI, database, or playback state.

3. **`StreamLoaderService`** (`lib/core/services/stream_loader_service.dart`):
   - Sequentially tries resolvers according to priority (e.g. JioSaavn $\to$ YouTubeExplode $\to$ Piped $\to$ Invidious).
   - If one provider breaks or rate-limits, the next one automatically resolves the track without playback interruption.

---

## 2. Implementing or Fixing an `AudioStreamResolver`

All stream resolvers implement the `AudioStreamResolver` contract:

```dart
abstract class AudioStreamResolver {
  /// User-facing or diagnostic name (e.g. 'JioSaavn', 'YouTubeExplode', 'Piped').
  String get name;

  /// Lower numbers are evaluated first in the fallback chain.
  int get priority;

  /// Fast synchronous check: can this resolver potentially resolve this song?
  bool canResolve(Song song);

  /// Resolves the audio stream URL. Returns null or throws on failure.
  Future<StreamResolutionResult?> resolve(
    Song song, {
    AudioQuality? quality,
    CancellationToken? cancellationToken,
  });
}
```

### Concrete Example
Here is how an isolated resolver looks:

```dart
class MyCustomStreamResolver implements AudioStreamResolver {
  @override
  String get name => 'MyCustomProvider';

  @override
  int get priority => 20;

  @override
  bool canResolve(Song song) {
    return song.source == MusicSource.custom || song.youtubeId != null;
  }

  @override
  Future<StreamResolutionResult?> resolve(
    Song song, {
    AudioQuality? quality,
    CancellationToken? cancellationToken,
  }) async {
    try {
      // 1. Check cancellation before making network request
      if (cancellationToken?.isCancelled ?? false) return null;

      // 2. Fetch stream from provider endpoint
      final streamUrl = await _fetchStreamUrl(song);
      if (streamUrl == null) return null;

      // 3. Return structured resolution result
      return StreamResolutionResult(
        streamUrl: streamUrl,
        resolverName: name,
        bitrateKbps: 160,
        format: 'm4a',
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
      );
    } catch (e) {
      // Never crash the app. Return null to let the next resolver in line take over.
      return null;
    }
  }
}
```

---

## 3. Provider Rules & Best Practices

1. **Never Touch Hive or Storage**:
   - Resolvers must be pure functions of input `(Song, Quality) -> StreamResolutionResult`.
   - Caching is handled centrally by `StreamLoaderService` and `LocalDataSource`.

2. **Never Touch Audio State**:
   - Do not call `just_audio`, `PlayerBloc`, or `AudioPlayerService`.
   - Your only job is resolving the URL and stream metadata.

3. **Handle Errors Gracefully**:
   - Return `null` when a track cannot be found or stream extraction fails.
   - Never let an unhandled exception escape into the player queue.

4. **Honor `CancellationToken`**:
   - Users frequently skip songs quickly. Check `cancellationToken?.isCancelled` before expensive requests or payload decryptions.

5. **Provide Expiration Metadata**:
   - If stream URLs expire (e.g., YouTube CDN tokens expiring in 6 hours), populate `expiresAt` so `StreamLoaderService` will not serve stale cached URLs.

---

## 4. Writing Fast, Mocked Provider Tests (No Emulators Needed!)

You don't need Android Studio, an emulator, or audio hardware to develop and test providers. You can verify everything in seconds using `flutter test`:

Run isolated provider tests:
```bash
flutter test test/providers/provider_isolation_test.dart
```

Example isolated test:
```dart
test('MyCustomStreamResolver resolves valid stream URL without audio stack', () async {
  final resolver = MyCustomStreamResolver();
  final testSong = Song(
    id: 'test_123',
    title: 'Song Title',
    artist: 'Artist',
    source: MusicSource.youtube,
  );

  expect(resolver.canResolve(testSong), isTrue);

  final result = await resolver.resolve(testSong);
  expect(result, isNotNull);
  expect(result!.streamUrl, startsWith('https://'));
  expect(result.resolverName, 'MyCustomProvider');
});
```

---

## 5. Submitting Your PR

Before submitting your pull request:
1. Run `flutter analyze` and ensure 0 errors/warnings.
2. Run `flutter test test/providers/` to verify your resolver.
3. Reference the relevant issue using our provider issue template.

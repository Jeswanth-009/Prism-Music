import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// Shared helper that resolves YouTube audio stream manifests using a multi-client fallback chain.
///
/// Tries clients in order of audio throughput and latency (Android SDK-less -> Android -> iOS -> Mobile Web)
/// with per-client timeouts to avoid hanging playback on slow or rate-limited endpoints.
class YouTubeManifestResolver {
  static final List<({String name, yt.YoutubeApiClient client, Duration timeout})>
      candidateClients = [
    (
      name: 'androidSdkless',
      client: yt.YoutubeApiClient.androidSdkless,
      timeout: const Duration(milliseconds: 3500),
    ),
    (
      name: 'android',
      client: yt.YoutubeApiClient.android,
      timeout: const Duration(seconds: 5),
    ),
    (
      name: 'ios',
      client: yt.YoutubeApiClient.ios,
      timeout: const Duration(seconds: 6),
    ),
    (
      name: 'mweb',
      client: yt.YoutubeApiClient.mweb,
      timeout: const Duration(seconds: 6),
    ),
  ];

  /// Fetches an audio-only stream manifest for [videoId] using [ytExplode].
  ///
  /// Returns the first [yt.StreamManifest] that has non-empty [audioOnly] streams.
  /// Throws the last encountered error if all clients fail or yield empty audio streams.
  static Future<yt.StreamManifest> fetchAudioManifest(
    yt.YoutubeExplode ytExplode,
    String videoId, {
    List<({String name, yt.YoutubeApiClient client, Duration timeout})>? clients,
    void Function(String clientName, Object error)? onClientFailure,
  }) async {
    final clientsToTry = clients ?? candidateClients;
    Object? lastError;

    for (final candidate in clientsToTry) {
      try {
        final manifest = await ytExplode.videos.streamsClient.getManifest(
          videoId,
          ytClients: [candidate.client],
          requireWatchPage: false,
        ).timeout(candidate.timeout);

        if (manifest.audioOnly.isNotEmpty) {
          return manifest;
        }
      } catch (e) {
        lastError = e;
        if (onClientFailure != null) {
          onClientFailure(candidate.name, e);
        } else {
          debugPrint('YouTubeManifestResolver: ${candidate.name} client failed ($e), falling back...');
        }
      }
    }

    throw lastError ?? Exception('All YouTube API clients failed for video: $videoId');
  }
}

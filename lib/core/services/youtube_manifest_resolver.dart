import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// Shared helper that resolves YouTube audio stream manifests using a multi-client fallback chain.
///
/// Races clients with a staggered delay (Android SDK-less -> Android -> iOS -> Mobile Web)
/// with per-client timeouts so slow or rate-limited clients never starve later fallbacks.
class YouTubeManifestResolver {
  static const Duration defaultStaggerDelay = Duration(milliseconds: 350);

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
      timeout: const Duration(seconds: 4),
    ),
    (
      name: 'ios',
      client: yt.YoutubeApiClient.ios,
      timeout: const Duration(milliseconds: 4500),
    ),
    (
      name: 'mweb',
      client: yt.YoutubeApiClient.mweb,
      timeout: const Duration(milliseconds: 4500),
    ),
  ];

  /// Fetches an audio-only stream manifest for [videoId] using [ytExplode].
  ///
  /// Launches the first client immediately and staggers fallback clients by
  /// [staggerDelay] (or fails over immediately if a client throws/yields no audio).
  /// Returns the first [yt.StreamManifest] with non-empty [audioOnly] streams, or
  /// throws the last encountered error if all clients fail.
  static Future<yt.StreamManifest> fetchAudioManifest(
    yt.YoutubeExplode ytExplode,
    String videoId, {
    List<({String name, yt.YoutubeApiClient client, Duration timeout})>? clients,
    void Function(String clientName, Object error)? onClientFailure,
    Duration staggerDelay = defaultStaggerDelay,
  }) async {
    final clientsToTry = clients ?? candidateClients;
    if (clientsToTry.isEmpty) {
      throw Exception('All YouTube API clients failed for video: $videoId');
    }
    if (clientsToTry.length == 1) {
      final candidate = clientsToTry.first;
      try {
        final manifest = await ytExplode.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [candidate.client],
              requireWatchPage: false,
            )
            .timeout(candidate.timeout);
        if (manifest.audioOnly.isNotEmpty) {
          return manifest;
        }
        throw Exception('${candidate.name} returned empty audioOnly manifest for $videoId');
      } catch (e) {
        _reportFailure(candidate.name, e, onClientFailure);
        rethrow;
      }
    }

    final completer = Completer<yt.StreamManifest>();
    Timer? staggerTimer;
    var launched = 0;
    var completedAttempts = 0;
    Object? lastError;

    void launchNext() {
      if (completer.isCompleted || launched >= clientsToTry.length) return;
      staggerTimer?.cancel();

      final candidate = clientsToTry[launched++];
      ytExplode.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [candidate.client],
            requireWatchPage: false,
          )
          .timeout(candidate.timeout)
          .then((manifest) {
        completedAttempts++;
        if (completer.isCompleted) return;
        if (manifest.audioOnly.isNotEmpty) {
          staggerTimer?.cancel();
          completer.complete(manifest);
          return;
        }
        lastError = Exception('${candidate.name} returned empty audioOnly streams');
        _reportFailure(candidate.name, lastError!, onClientFailure);
        if (launched < clientsToTry.length) {
          launchNext();
        } else if (completedAttempts >= clientsToTry.length) {
          staggerTimer?.cancel();
          completer.completeError(
            lastError ?? Exception('All YouTube API clients failed for video: $videoId'),
          );
        }
      }).catchError((Object e) {
        completedAttempts++;
        lastError = e;
        if (completer.isCompleted) return;
        _reportFailure(candidate.name, e, onClientFailure);
        if (launched < clientsToTry.length) {
          launchNext();
        } else if (completedAttempts >= clientsToTry.length) {
          staggerTimer?.cancel();
          completer.completeError(
            lastError ?? Exception('All YouTube API clients failed for video: $videoId'),
          );
        }
      });

      if (launched < clientsToTry.length) {
        staggerTimer = Timer(staggerDelay, launchNext);
      }
    }

    launchNext();
    return completer.future;
  }

  static void _reportFailure(
    String clientName,
    Object error,
    void Function(String clientName, Object error)? onClientFailure,
  ) {
    if (onClientFailure != null) {
      onClientFailure(clientName, error);
    } else {
      debugPrint('YouTubeManifestResolver: $clientName client failed ($error), falling back...');
    }
  }
}

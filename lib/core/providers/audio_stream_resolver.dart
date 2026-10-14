import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';

/// Contract for stream extraction providers (YouTube Explode, JioSaavn, Invidious, Piped).
/// Decouples audio resolution completely from metadata discovery.
abstract class AudioStreamResolver {
  /// Unique name identifying this resolver (e.g. 'youtube_explode', 'jiosaavn').
  String get resolverName;

  /// Whether this resolver is healthy and ready to process requests.
  bool get isAvailable;

  /// Resolve a playable [StreamInfo] for the requested [song].
  Future<StreamInfo?> resolveStream(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  });
}

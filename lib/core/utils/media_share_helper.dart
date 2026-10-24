import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import 'link_validation.dart';

/// Helper for validating media metadata, URLs, and generating rich, reliable
/// shareable cards for songs and playlists without producing broken links.
abstract final class MediaShareHelper {
  /// Validates whether a candidate string is a plausible YouTube video ID
  /// (e.g. 11-character base64url token or common test mock token),
  /// explicitly rejecting internal non-YouTube IDs (`saavn_`, `spotify_`,
  /// `local_`, `asset:`, URLs with protocols, etc.).
  static bool isValidYouTubeVideoId(String? id) {
    if (id == null || id.isEmpty) return false;
    final trimmed = id.trim();
    if (trimmed.startsWith('saavn_') ||
        trimmed.startsWith('spotify:') ||
        trimmed.startsWith('spotify_') ||
        trimmed.startsWith('local_') ||
        trimmed.startsWith('asset:') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.contains('/') ||
        trimmed.contains('?') ||
        trimmed.contains('&') ||
        trimmed.contains(' ')) {
      return false;
    }
    return RegExp(r'^[a-zA-Z0-9_-]{5,30}$').hasMatch(trimmed);
  }

  /// Validates whether a candidate string is a valid YouTube playlist ID.
  static bool isValidYouTubePlaylistId(String? id) {
    if (id == null || id.isEmpty) return false;
    final trimmed = id.trim();
    if (trimmed.startsWith('http') || trimmed.contains('/') || trimmed.contains(' ')) {
      return false;
    }
    return RegExp(r'^[a-zA-Z0-9_-]{10,50}$').hasMatch(trimmed);
  }

  /// Builds a verified, reliable external web URL for [song], or returns null
  /// if no reliable link is available (preventing 404 links on other platforms).
  static String? buildReliableSongUrl(Song song) {
    // 1. Explicit YouTube ID
    if (isValidYouTubeVideoId(song.youtubeId)) {
      return 'https://music.youtube.com/watch?v=${song.youtubeId}';
    }

    // 2. Song ID if it is a pure YouTube video ID
    if (isValidYouTubeVideoId(song.id)) {
      return 'https://music.youtube.com/watch?v=${song.id}';
    }

    // 3. Direct canonical web stream URL if on trusted YouTube host
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
      final uri = Uri.tryParse(song.streamUrl!);
      if (uri != null && uri.hasScheme && uri.hasAuthority && isYouTubePlaylistHost(uri.host)) {
        return song.streamUrl;
      }
    }

    return null;
  }

  /// Builds a verified external web URL for [playlist], or returns null.
  static String? buildReliablePlaylistUrl(Playlist playlist) {
    if (isValidYouTubePlaylistId(playlist.youtubePlaylistId)) {
      return 'https://music.youtube.com/playlist?list=${playlist.youtubePlaylistId}';
    }
    if (playlist.spotifyPlaylistId != null &&
        RegExp(r'^[a-zA-Z0-9]{15,35}$').hasMatch(playlist.spotifyPlaylistId!)) {
      return 'https://open.spotify.com/playlist/${playlist.spotifyPlaylistId}';
    }
    return null;
  }

  /// Formats a clean, reliable share text for a song.
  /// If the URL is verified, includes the URL.
  /// If not, generates a rich metadata card (title, artist, album, duration)
  /// without producing 404 links.
  static String formatShareableSongText(Song song) {
    final url = buildReliableSongUrl(song);
    final buffer = StringBuffer();
    buffer.writeln('🎵 ${song.title}');
    buffer.writeln('Artist: ${song.artist}');
    if (song.album != null && song.album!.trim().isNotEmpty) {
      buffer.writeln('Album: ${song.album!.trim()}');
    }
    if (song.duration > Duration.zero) {
      buffer.writeln('Duration: ${_formatDuration(song.duration)}');
    }
    if (url != null) {
      buffer.writeln('\nListen: $url');
    }
    buffer.writeln('\nShared from Prism Music');
    return buffer.toString().trim();
  }

  /// Formats a structured, high-polish shareable playlist summary card.
  static String formatShareablePlaylistCard(Playlist playlist) {
    final songs = playlist.songs ?? const <Song>[];
    final buffer = StringBuffer();
    buffer.writeln('🎶 ${playlist.name}');
    if (playlist.description != null && playlist.description!.trim().isNotEmpty) {
      buffer.writeln(playlist.description!.trim());
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━');

    final totalSeconds = songs.fold<int>(0, (sum, s) => sum + s.duration.inSeconds);
    final durationFormatted = _formatTotalDuration(Duration(seconds: totalSeconds));
    buffer.writeln('📋 ${songs.length} tracks • $durationFormatted');

    // Distinct top artists (up to 3)
    final artists = <String>{};
    for (final s in songs) {
      if (s.artist.trim().isNotEmpty) artists.add(s.artist.trim());
      if (artists.length >= 3) break;
    }
    if (artists.isNotEmpty) {
      buffer.writeln('🌟 Featuring: ${artists.join(', ')}');
    }

    final link = buildReliablePlaylistUrl(playlist);
    if (link != null) {
      buffer.writeln('🔗 $link');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Shared from Prism Music');
    return buffer.toString().trim();
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _formatTotalDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }
}

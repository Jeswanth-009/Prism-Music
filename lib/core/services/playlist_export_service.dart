import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../utils/logger.dart';

/// Service responsible for exporting playlist data to standard formats (M3U8, JSON)
/// and sharing via system share dialog.
class PlaylistExportService {
  const PlaylistExportService();

  static const PlaylistExportService instance = PlaylistExportService();

  /// Sanitizes playlist name for use in filesystem filenames.
  static String sanitizeFilename(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'playlist' : sanitized;
  }

  /// Exports the playlist as an extended M3U8 file (.m3u8) with track metadata
  /// and stream/YouTube links, then opens the system share sheet.
  Future<File?> exportM3u8(Playlist playlist) async {
    try {
      final songs = playlist.songs ?? const <Song>[];
      final buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      buffer.writeln('#PLAYLIST:${playlist.name}');
      if (playlist.description != null && playlist.description!.trim().isNotEmpty) {
        buffer.writeln('#COMMENT:${playlist.description!.trim()}');
      }

      for (final song in songs) {
        final durationSec = song.duration.inSeconds;
        buffer.writeln('#EXTINF:$durationSec,${song.artist} - ${song.title}');
        final trackId = song.youtubeId ?? song.id;
        buffer.writeln('https://music.youtube.com/watch?v=$trackId');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = '${sanitizeFilename(playlist.name)}.m3u8';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(buffer.toString(), flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'audio/x-mpegurl', name: fileName)],
        subject: playlist.name,
        text: 'Exported playlist: ${playlist.name} (${songs.length} songs)',
      );

      return file;
    } catch (e, st) {
      logError('Failed to export playlist to M3U8: $e\n$st');
      return null;
    }
  }

  /// Exports the playlist as a structured JSON archive (.json) with complete
  /// metadata, track details, and source identifiers, then shares it.
  Future<File?> exportJson(Playlist playlist) async {
    try {
      final songs = playlist.songs ?? const <Song>[];
      final payload = {
        'format': 'prism_playlist_archive',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'playlist': {
          'id': playlist.id,
          'name': playlist.name,
          'description': playlist.description,
          'author': playlist.author,
          'isUserCreated': playlist.isUserCreated,
          'spotifyPlaylistId': playlist.spotifyPlaylistId,
          'youtubePlaylistId': playlist.youtubePlaylistId,
          'thumbnailUrl': playlist.thumbnailUrl,
          'trackCount': songs.length,
          'tracks': songs.map((s) => {
            'id': s.id,
            'title': s.title,
            'artist': s.artist,
            'album': s.album,
            'durationSeconds': s.duration.inSeconds,
            'thumbnailUrl': s.thumbnailUrl,
            'youtubeId': s.youtubeId,
            'streamUrl': s.streamUrl,
          }).toList(),
        },
      };

      final jsonContent = const JsonEncoder.withIndent('  ').convert(payload);
      final tempDir = await getTemporaryDirectory();
      final fileName = '${sanitizeFilename(playlist.name)}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonContent, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json', name: fileName)],
        subject: playlist.name,
        text: 'Exported playlist archive: ${playlist.name}',
      );

      return file;
    } catch (e, st) {
      logError('Failed to export playlist to JSON: $e\n$st');
      return null;
    }
  }

  /// Formats the playlist as a clean text tracklist and opens the share sheet.
  Future<void> shareText(Playlist playlist) async {
    try {
      final songs = playlist.songs ?? const <Song>[];
      final buffer = StringBuffer();
      buffer.writeln('🎶 ${playlist.name}');
      if (playlist.description != null && playlist.description!.trim().isNotEmpty) {
        buffer.writeln(playlist.description!.trim());
      }
      buffer.writeln('${songs.length} tracks\n');

      for (var i = 0; i < songs.length; i++) {
        final s = songs[i];
        final dur = _formatDuration(s.duration);
        buffer.writeln('${i + 1}. ${s.title} — ${s.artist} ($dur)');
      }

      buffer.writeln('\nShared from Prism Music');

      await Share.share(
        buffer.toString(),
        subject: playlist.name,
      );
    } catch (e, st) {
      logError('Failed to share playlist as text: $e\n$st');
    }
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

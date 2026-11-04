import 'dart:convert';
import 'dart:io';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../utils/logger.dart';

/// Peer-to-peer playlist collaboration service that generates compressed,
/// self-contained QR codes and shareable links with zero server dependency.
class PlaylistCollaborationService {
  const PlaylistCollaborationService._();

  static const PlaylistCollaborationService instance = PlaylistCollaborationService._();

  static const String linkScheme = 'prism';
  static const String linkHost = 'playlist';
  static const String webFallbackPrefix = 'https://jeswanth-009.github.io/Prism-Music/playlist#data=';

  /// Serializes a playlist into a compact, compressed, URL-safe Base64 payload.
  String encodePlaylistPayload(Playlist playlist) {
    final songs = playlist.songs ?? const <Song>[];
    final map = <String, dynamic>{
      'v': 1,
      'n': playlist.name,
      if (playlist.description != null && playlist.description!.trim().isNotEmpty)
        'd': playlist.description!.trim(),
      't': songs.map((s) => <String, dynamic>{
        't': s.title,
        'a': s.artist,
        's': s.duration.inSeconds,
        if (s.album != null && s.album!.trim().isNotEmpty) 'l': s.album!.trim(),
        if (s.youtubeId != null && s.youtubeId!.isNotEmpty) 'y': s.youtubeId,
        if (s.isrc != null && s.isrc!.isNotEmpty) 'i': s.isrc,
      }).toList(),
    };

    final jsonStr = jsonEncode(map);
    final rawBytes = utf8.encode(jsonStr);
    final compressed = gzip.encode(rawBytes);
    return base64Url.encode(compressed);
  }

  /// Builds a `prism://playlist?data=...` app link for scanning or peer transmission.
  String buildAppShareLink(Playlist playlist) {
    final payload = encodePlaylistPayload(playlist);
    return '$linkScheme://$linkHost?data=$payload';
  }

  /// Builds a web-compatible fallback link with payload in the fragment identifier.
  String buildWebShareLink(Playlist playlist) {
    final payload = encodePlaylistPayload(playlist);
    return '$webFallbackPrefix$payload';
  }

  /// Parses and reconstructs a [Playlist] from an app deep link, web fallback,
  /// or raw compressed base64 payload.
  Playlist? decodePlaylistPayload(String rawInput) {
    try {
      var token = rawInput.trim();
      if (token.isEmpty) return null;

      // Extract parameter if formatted as a URL
      if (token.contains('data=')) {
        final uri = Uri.tryParse(token);
        if (uri != null && uri.queryParameters.containsKey('data')) {
          token = uri.queryParameters['data']!;
        } else if (token.contains('#data=')) {
          token = token.split('#data=').last;
        } else {
          token = token.split('data=').last;
        }
      }

      // Remove any lingering URL fragments or trailing queries
      if (token.contains('&')) token = token.split('&').first;
      if (token.contains('#')) token = token.split('#').first;

      // Normalize base64url padding
      var normalized = token.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }

      final compressedBytes = base64.decode(normalized);

      // Decompress gzip payload, with fallback to zlib or plain json
      List<int> decompressedBytes;
      try {
        decompressedBytes = gzip.decode(compressedBytes);
      } catch (_) {
        try {
          decompressedBytes = zlib.decode(compressedBytes);
        } catch (_) {
          decompressedBytes = compressedBytes;
        }
      }

      final jsonStr = utf8.decode(decompressedBytes);
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;

      final name = decoded['n']?.toString().trim() ?? 'Shared Playlist';
      final description = decoded['d']?.toString().trim();
      final tracksRaw = decoded['t'] as List<dynamic>? ?? const [];

      final songs = <Song>[];
      for (var i = 0; i < tracksRaw.length; i++) {
        final t = tracksRaw[i];
        if (t is! Map<String, dynamic>) continue;
        final title = t['t']?.toString().trim() ?? '';
        final artist = t['a']?.toString().trim() ?? 'Unknown Artist';
        final sec = (t['s'] as num?)?.toInt() ?? 0;
        final album = t['l']?.toString().trim();
        final youtubeId = t['y']?.toString().trim();
        final isrc = t['i']?.toString().trim();

        if (title.isEmpty) continue;

        songs.add(
          Song(
            id: youtubeId != null && youtubeId.isNotEmpty
                ? youtubeId
                : 'p2p_${name.hashCode}_${i}_${title.hashCode}',
            title: title,
            artist: artist,
            album: album,
            duration: Duration(seconds: sec),
            thumbnails: const Thumbnails(),
            youtubeId: youtubeId,
            isrc: isrc,
            source: youtubeId != null ? MusicSource.youtube : MusicSource.unknown,
          ),
        );
      }

      final now = DateTime.now();
      return Playlist(
        id: 'p2p_imported_${now.millisecondsSinceEpoch}',
        name: name,
        description: description != null && description.isNotEmpty
            ? '$description (Shared P2P)'
            : 'Shared via peer-to-peer Prism link',
        author: 'Prism Peer',
        isUserCreated: true,
        createdAt: now,
        updatedAt: now,
        trackCount: songs.length,
        songs: songs,
        totalDuration: Duration(
          seconds: songs.fold(0, (sum, s) => sum + s.duration.inSeconds),
        ),
      );
    } catch (e, st) {
      logError('PlaylistCollaborationService: Failed to decode payload: $e\n$st');
      return null;
    }
  }
}

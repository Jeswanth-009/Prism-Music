import '../../domain/entities/song.dart';

/// Maps arbitrary backend payloads into Song domain objects.
class BackendSongMapper {
  static Song fromMap(
    Map<String, dynamic> raw, {
    required MusicSource source,
  }) {
    final id = _pickString(raw, const ['id', 'videoId', 'trackId', 'songId']);
    final youtubeId = _pickString(raw, const ['youtubeId', 'videoId']);
    final jioSaavnId = _pickString(raw, const ['jioSaavnId', 'jiosaavnId']);
    final title = _pickString(raw, const ['title', 'name'], fallback: 'Unknown Title');

    final artists = _extractArtists(raw);
    final artist = artists.isNotEmpty
        ? artists.first
        : _pickString(raw, const ['artist', 'author', 'primaryArtists'], fallback: 'Unknown Artist');

    final durationMs = _pickInt(raw, const ['durationMs', 'duration_ms']);
    final durationSec = _pickInt(raw, const ['duration', 'durationSeconds', 'duration_sec']);
    final duration = durationMs != null
        ? Duration(milliseconds: durationMs)
        : Duration(seconds: durationSec ?? 0);

    final thumb = _pickString(
      raw,
      const ['thumbnailUrl', 'thumbnail', 'artwork', 'image', 'coverUrl'],
    );

    return Song(
      id: id.isNotEmpty ? id : (youtubeId.isNotEmpty ? youtubeId : jioSaavnId),
      title: title,
      artist: artist,
      artists: artists,
      album: _pickString(raw, const ['album', 'albumName']),
      albumId: _pickString(raw, const ['albumId']),
      duration: duration,
      thumbnails: Thumbnails.fromUrl(thumb),
      source: source,
      youtubeId: youtubeId.isNotEmpty ? youtubeId : null,
      jioSaavnId: jioSaavnId.isNotEmpty ? jioSaavnId : null,
      spotifyId: _pickString(raw, const ['spotifyId']),
      streamUrl: _pickString(raw, const ['streamUrl', 'url']),
      year: _pickInt(raw, const ['year']),
      isExplicit: _pickBool(raw, const ['explicit', 'isExplicit', 'explicitContent']),
    );
  }

  static List<Song> fromList(
    List<Map<String, dynamic>> payloads, {
    required MusicSource source,
  }) {
    return payloads.map((raw) => fromMap(raw, source: source)).toList();
  }

  static String _pickString(
    Map<String, dynamic> raw,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = raw[key];
      if (value == null) continue;
      final s = value.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  static int? _pickInt(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool _pickBool(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = (value?.toString() ?? '').toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return false;
  }

  static List<String> _extractArtists(Map<String, dynamic> raw) {
    final value = raw['artists'];
    if (value is List) {
      return value
          .map((e) {
            if (e is String) return e.trim();
            if (e is Map<String, dynamic>) {
              return _pickString(e, const ['name', 'title']);
            }
            return '';
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final artistText = _pickString(raw, const ['artist', 'author', 'primaryArtists']);
    if (artistText.isEmpty) return const [];
    return artistText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}

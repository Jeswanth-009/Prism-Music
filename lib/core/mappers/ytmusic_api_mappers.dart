import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';

Song songFromYtMusicApi(Map<String, dynamic> item) {
  final videoId = _readString(item, const ['videoId', 'id']);
  final title = _readString(item, const ['title', 'name']);

  final artists = _extractArtistNames(item);
  final primaryArtist = artists.isNotEmpty
      ? artists.first
      : _readString(item, const ['artist', 'author']);

  final album = _readNestedString(
    item,
    const [
      ['album', 'name'],
      ['album', 'title'],
    ],
  );

  final durationSeconds = _durationSeconds(item);
  final thumbnailUrl = _extractThumbnailUrl(item) ?? '';

  return Song(
    id: videoId,
    title: title,
    artist: primaryArtist,
    artists: artists,
    album: album,
    duration: Duration(seconds: durationSeconds),
    thumbnails: Thumbnails.fromUrl(thumbnailUrl),
    source: MusicSource.youtubeMusic,
    youtubeId: videoId,
  );
}

Artist artistFromYtMusicApi(Map<String, dynamic> item) {
  final id = _readString(item, const ['browseId', 'artistId', 'id']);
  return Artist(
    id: id,
    name: _readString(item, const ['name', 'title']),
    thumbnails: Thumbnails.fromUrl(_extractThumbnailUrl(item) ?? ''),
    youtubeChannelId: id,
  );
}

Album albumFromYtMusicApi(Map<String, dynamic> item) {
  final id = _readString(item, const ['browseId', 'albumId', 'id']);
  final type = (_readString(item, const ['type'])).toLowerCase();

  return Album(
    id: id,
    title: _readString(item, const ['title', 'name']),
    artist: _readString(item, const ['artist', 'author']),
    thumbnails: Thumbnails.fromUrl(_extractThumbnailUrl(item) ?? ''),
    trackCount: int.tryParse(_readString(item, const ['trackCount', 'count'])),
    youtubePlaylistId: _readString(item, const ['playlistId']),
    type: type == 'single' ? AlbumType.single : AlbumType.album,
  );
}

Playlist playlistFromYtMusicApi(Map<String, dynamic> item) {
  final id = _readString(item, const ['playlistId', 'browseId', 'id']);
  return Playlist(
    id: id,
    name: _readString(item, const ['title', 'name']),
    trackCount: int.tryParse(_readString(item, const ['trackCount', 'count'])) ?? 0,
    thumbnails: Thumbnails.fromUrl(_extractThumbnailUrl(item) ?? ''),
    youtubePlaylistId: id,
  );
}

String _readString(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

String? _readNestedString(
  Map<String, dynamic> item,
  List<List<String>> candidatePaths,
) {
  for (final path in candidatePaths) {
    dynamic current = item;
    bool ok = true;
    for (final segment in path) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        ok = false;
        break;
      }
    }
    if (!ok) {
      continue;
    }
    if (current is String && current.trim().isNotEmpty) {
      return current.trim();
    }
  }

  return null;
}

List<String> _extractArtistNames(Map<String, dynamic> item) {
  final result = <String>[];

  final rawArtists = item['artists'];
  if (rawArtists is List) {
    for (final entry in rawArtists) {
      if (entry is String && entry.trim().isNotEmpty) {
        result.add(entry.trim());
      } else if (entry is Map) {
        final name = (entry['name'] ?? entry['title'])?.toString() ?? '';
        if (name.trim().isNotEmpty) {
          result.add(name.trim());
        }
      }
    }
  }

  if (result.isEmpty) {
    final artistText = _readString(item, const ['artist', 'author']);
    if (artistText.isNotEmpty) {
      result.addAll(
        artistText
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    }
  }

  return result;
}

int _durationSeconds(Map<String, dynamic> item) {
  final secondsRaw = _readString(item, const ['durationSeconds']);
  final direct = int.tryParse(secondsRaw);
  if (direct != null) {
    return direct;
  }

  final durationText = _readString(item, const ['duration']);
  if (durationText.isEmpty) {
    return 0;
  }

  final parts = durationText.split(':').map((p) => int.tryParse(p) ?? 0).toList();
  if (parts.length == 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  if (parts.length == 2) {
    return parts[0] * 60 + parts[1];
  }
  if (parts.length == 1) {
    return parts[0];
  }
  return 0;
}

String? _extractThumbnailUrl(Map<String, dynamic> item) {
  final thumbnails = item['thumbnails'];
  if (thumbnails is List && thumbnails.isNotEmpty) {
    final last = thumbnails.last;
    if (last is String && last.trim().isNotEmpty) {
      return last.trim();
    }
    if (last is Map) {
      final url = last['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        return url;
      }
    }
  }

  final thumbnail = item['thumbnail'];
  if (thumbnail is String && thumbnail.trim().isNotEmpty) {
    return thumbnail.trim();
  }
  if (thumbnail is Map) {
    final nested = thumbnail['thumbnails'];
    if (nested is List && nested.isNotEmpty) {
      final last = nested.last;
      if (last is Map) {
        final url = last['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          return url;
        }
      }
    }
  }

  return null;
}

import 'package:equatable/equatable.dart';

import 'album.dart';
import 'artist.dart';
import 'playlist.dart';
import 'song.dart';

/// Wraps the single best candidate identified by the ranking engine.
class SearchTopResult extends Equatable {
  final Song? song;
  final Artist? artist;
  final Album? album;

  const SearchTopResult({
    this.song,
    this.artist,
    this.album,
  }) : assert(
          song != null || artist != null || album != null,
          'At least one entity must be present in SearchTopResult',
        );

  factory SearchTopResult.song(Song song) => SearchTopResult(song: song);
  factory SearchTopResult.artist(Artist artist) =>
      SearchTopResult(artist: artist);
  factory SearchTopResult.album(Album album) => SearchTopResult(album: album);

  bool get isSong => song != null;
  bool get isArtist => artist != null;
  bool get isAlbum => album != null;

  String get id {
    if (song != null) return song!.id;
    if (artist != null) return artist!.id;
    if (album != null) return album!.id;
    return '';
  }

  String get title {
    if (song != null) return song!.title;
    if (artist != null) return artist!.name;
    if (album != null) return album!.title;
    return '';
  }

  String get subtitle {
    if (song != null) return song!.artist;
    if (artist != null) return 'Artist';
    if (album != null) return album!.artist;
    return '';
  }

  String get thumbnailUrl {
    if (song != null) return song!.thumbnailUrl;
    if (artist != null) return artist!.thumbnailUrl ?? '';
    if (album != null) {
      return album!.thumbnails.high ??
          album!.thumbnails.medium ??
          album!.thumbnails.low ??
          '';
    }
    return '';
  }

  String get kindLabel {
    if (song != null) return 'Song';
    if (artist != null) return 'Artist';
    if (album != null) return 'Album';
    return '';
  }

  @override
  List<Object?> get props => [song, artist, album];
}

/// Structured search results bundle supporting top result and categorized feeds.
class SearchResultsBundle extends Equatable {
  final SearchTopResult? topResult;
  final List<Song> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;
  final List<Song> videos;

  const SearchResultsBundle({
    this.topResult,
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.videos = const [],
  });

  bool get isEmpty =>
      topResult == null &&
      songs.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty &&
      videos.isEmpty;

  SearchResultsBundle copyWith({
    SearchTopResult? topResult,
    List<Song>? songs,
    List<Artist>? artists,
    List<Album>? albums,
    List<Playlist>? playlists,
    List<Song>? videos,
  }) {
    return SearchResultsBundle(
      topResult: topResult ?? this.topResult,
      songs: songs ?? this.songs,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      playlists: playlists ?? this.playlists,
      videos: videos ?? this.videos,
    );
  }

  @override
  List<Object?> get props => [
        topResult,
        songs,
        artists,
        albums,
        playlists,
        videos,
      ];
}

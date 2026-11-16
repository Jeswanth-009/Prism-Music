/// Supported search filter categories in Prism Music
enum SearchCategory {
  all,
  songs,
  albums,
  artists,
  videos,
  playlists,
  downloads;

  String get label => switch (this) {
        SearchCategory.all => 'All',
        SearchCategory.songs => 'Songs',
        SearchCategory.albums => 'Albums',
        SearchCategory.artists => 'Artists',
        SearchCategory.videos => 'Videos',
        SearchCategory.playlists => 'Playlists',
        SearchCategory.downloads => 'Downloaded',
      };
}

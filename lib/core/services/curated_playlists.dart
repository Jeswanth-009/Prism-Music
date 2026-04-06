import 'package:flutter/material.dart';

/// A curated YouTube/YouTube Music playlist shown on the home page.
class CuratedPlaylist {
  final String id;
  final String name;
  final String playlistId;
  final String category;
  final List<Color> gradient;
  final IconData icon;

  const CuratedPlaylist({
    required this.id,
    required this.name,
    required this.playlistId,
    required this.category,
    required this.gradient,
    required this.icon,
  });
}

/// All curated playlists grouped by category.
class CuratedPlaylists {
  CuratedPlaylists._();

  // ── Global ─────────────────────────────────────────────────────────
  static const _global = [
    CuratedPlaylist(
      id: 'top_100_global',
      name: 'Top 100 Songs Global',
      playlistId: 'PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i',
      category: 'Global',
      gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
      icon: Icons.public,
    ),
    CuratedPlaylist(
      id: 'daily_top_music_global',
      name: 'Daily Top Music Videos',
      playlistId: 'PL4fGSI1pDJn6t3TXLGiiJdD-sZbrG3tG0',
      category: 'Global',
      gradient: [Color(0xFFe52d27), Color(0xFFb31217)],
      icon: Icons.trending_up,
    ),
  ];

  // ── India (General) ────────────────────────────────────────────────
  static const _india = [
    CuratedPlaylist(
      id: 'trending_20_india',
      name: 'Trending 20 India',
      playlistId: 'OLAK5uy_lSTp1DIuzZBUyee3kDsXwPgP25WdfwB40',
      category: 'India',
      gradient: [Color(0xFFFF9933), Color(0xFF138808)],
      icon: Icons.flag,
    ),
    CuratedPlaylist(
      id: 'the_hit_list',
      name: 'The Hit List',
      playlistId: 'RDCLAK5uy_kmPRjHDECIcuVwnKsx2Ng7fyNgFKWNJFs',
      category: 'India',
      gradient: [Color(0xFFff0844), Color(0xFFffb199)],
      icon: Icons.whatshot,
    ),
    CuratedPlaylist(
      id: 'hashtag_hits',
      name: 'Hashtag Hits',
      playlistId: 'RDCLAK5uy_mZt1Mh5Ii8bratgrwVtBY6z9BDS7pIMug',
      category: 'India',
      gradient: [Color(0xFF11998e), Color(0xFF38ef7d)],
      icon: Icons.tag,
    ),
    CuratedPlaylist(
      id: 'the_short_list',
      name: 'The Short List',
      playlistId: 'RDCLAK5uy_kXyXCKQgJzsjFWrCop6_9l2YBN_OKkJfo',
      category: 'India',
      gradient: [Color(0xFF6a11cb), Color(0xFF2575fc)],
      icon: Icons.short_text,
    ),
    CuratedPlaylist(
      id: 'country_hotlist',
      name: 'Country Hotlist',
      playlistId: 'RDCLAK5uy_lJ8xZWiZj2GCw7MArjakb6b0zfvqwldps',
      category: 'India',
      gradient: [Color(0xFFf7971e), Color(0xFFffd200)],
      icon: Icons.local_fire_department,
    ),
  ];

  // ── Pop / Bollywood ────────────────────────────────────────────────
  static const _popBollywood = [
    CuratedPlaylist(
      id: 'pop_certified',
      name: 'Pop Certified',
      playlistId: 'RDCLAK5uy_lBNUteBRencHzKelu5iDHwLF6mYqjL-JU',
      category: 'Pop & Bollywood',
      gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
      icon: Icons.star,
    ),
    CuratedPlaylist(
      id: 'bollywood_hitlist',
      name: 'Bollywood Hitlist',
      playlistId: 'RDCLAK5uy_n9Fbdw7e6ap-98_A-8JYBmPv64v-Uaq1g',
      category: 'Pop & Bollywood',
      gradient: [Color(0xFFe52d27), Color(0xFFb31217)],
      icon: Icons.movie,
    ),
    CuratedPlaylist(
      id: 'make_out_jams_bollywood',
      name: 'Make Out Jams: Bollywood',
      playlistId: 'RDCLAK5uy_lbfDqlFOiRJekoTwNgiES65gcham4ZelA',
      category: 'Pop & Bollywood',
      gradient: [Color(0xFFff6a88), Color(0xFFff99ac)],
      icon: Icons.favorite,
    ),
    CuratedPlaylist(
      id: 'pop_tadka',
      name: 'Pop Tadka',
      playlistId: 'RDCLAK5uy_lZQJ2uAh2UWSQ16Z8ry8g3ttQDLNiXiWs',
      category: 'Pop & Bollywood',
      gradient: [Color(0xFFf7971e), Color(0xFFffd200)],
      icon: Icons.music_note,
    ),
    CuratedPlaylist(
      id: 'i_pop_hits',
      name: 'I-Pop Hits!',
      playlistId: 'RDCLAK5uy_lj-zBExVYl7YN_NxXboDIh4A-wKGfgzNY',
      category: 'Pop & Bollywood',
      gradient: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      icon: Icons.headphones,
    ),
  ];

  // ── Tollywood / Telugu ─────────────────────────────────────────────
  static const _tollywood = [
    CuratedPlaylist(
      id: 'tollywood_hitlist',
      name: 'Tollywood Hitlist',
      playlistId: 'RDCLAK5uy_lyVnWI5JnuwKJiuE-n1x-Un0mj9WlEyZw',
      category: 'Tollywood',
      gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
      icon: Icons.movie_filter,
    ),
    CuratedPlaylist(
      id: 'new_music_telugu',
      name: 'New Music Telugu',
      playlistId: 'RDCLAK5uy_l8CaYQvBQWVT2st1VsW9JjODWisR_vd3U',
      category: 'Tollywood',
      gradient: [Color(0xFF11998e), Color(0xFF38ef7d)],
      icon: Icons.new_releases,
    ),
    CuratedPlaylist(
      id: 'tollywood_dance_hitlist',
      name: 'Tollywood Dance Hitlist',
      playlistId: 'RDCLAK5uy_n0a1W54UyoGGn07f8CqYeQoXt2bhmgRPM',
      category: 'Tollywood',
      gradient: [Color(0xFFff0844), Color(0xFFffb199)],
      icon: Icons.nightlife,
    ),
    CuratedPlaylist(
      id: 'tollywood_party',
      name: 'Tollywood Party',
      playlistId: 'RDCLAK5uy_nGC5IUV3lYF-P_wGb-LzMPFydA-RkPblc',
      category: 'Tollywood',
      gradient: [Color(0xFFf7971e), Color(0xFFffd200)],
      icon: Icons.celebration,
    ),
    CuratedPlaylist(
      id: 'iconic_tollywood_hits',
      name: 'Iconic Tollywood Hits',
      playlistId: 'RDCLAK5uy_kNVZmuXhmEKIMMdOtksUzOwpJ98rZMvo8',
      category: 'Tollywood',
      gradient: [Color(0xFF6a11cb), Color(0xFF2575fc)],
      icon: Icons.emoji_events,
    ),
  ];

  /// All curated playlists.
  static List<CuratedPlaylist> get all => [
        ..._global,
        ..._india,
        ..._popBollywood,
        ..._tollywood,
      ];

  /// All unique category names (preserving order).
  static List<String> get categories {
    final seen = <String>{};
    final result = <String>[];
    for (final p in all) {
      if (seen.add(p.category)) result.add(p.category);
    }
    return result;
  }

  /// Playlists for a given category.
  static List<CuratedPlaylist> forCategory(String category) =>
      all.where((p) => p.category == category).toList();
}

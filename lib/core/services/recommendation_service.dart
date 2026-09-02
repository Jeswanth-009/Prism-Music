import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../domain/repositories/library_repository.dart';
import '../utils/logger.dart';
import 'settings_service.dart';

enum RecommendationMode {
  similar, // Similar songs to currently playing / seed song
  discover, // Discover new songs user might like based on taste profile
}

/// Regular expression to detect official music videos and high-quality releases
final _officialMusicRegex = RegExp(
  r"official\s*(video|audio|music\s*video|lyric\s*video|visualizer|track)",
  caseSensitive: false,
);

/// Non-music title patterns — interviews, reactions, podcasts, tutorials, mashups, compilations, etc.
final _nonMusicTitleRegex = RegExp(
  r'interview|reacts? to|talks? about|talks? upcoming|responds to|'
  r'reveals|breaks down|explains|podcast|episode|ep\.?\s*\d|'
  r'behind the scenes|making of|documentary|trailer|teaser|'
  r'unboxing|haul|vlog|Q&A|AMA|livestream|live stream|'
  r'freestyle|cipher|top \d|ranking|tier list|'
  r'reaction|commentary|review|roast|exposed|drama|'
  r'tutorial|how to|lesson|learn|guide|tips|'
  r'full album|discography|jukebox|mega mix|megamix|'
  r'mashup|mash up|non stop|nonstop|non-stop|compilation|'
  r'1 hour|10 hours|1hr|10hr|slowed\s*\+\s*reverb|slowed and reverb|'
  r'speed up|sped up|nightcore|8d audio|karaoke|instrumental cover',
  caseSensitive: false,
);

/// Non-music channel/artist patterns
final _nonMusicArtistRegex = RegExp(
  r'entertainment tonight|billboard news|billboard and billboard|access hollywood|'
  r'the tonight show|jimmy kimmel|jimmy fallon|late night|good morning|today show|'
  r'the breakfast club|hot 97|siriusxm|genius|complex|xxl mag|the fader|'
  r'pitchfork|nardwuar|zane lowe|react|fine brothers|'
  r'first we feast|hot ones|npr music|colors show|vevo lift|'
  r'podcast|radio|news|reacts|reaction|commentary|t-series bhakti|'
  r'bhajan|devotional|mantra|aarti|meditation music|relaxing music',
  caseSensitive: false,
);

/// Returns true if a song result is likely NOT actual standalone music
bool _isLikelyNonMusic(Song song) {
  if (_nonMusicTitleRegex.hasMatch(song.title)) return true;
  if (_nonMusicArtistRegex.hasMatch(song.artist)) return true;
  return false;
}

bool _isLikelyNonMusicArtistName(String artist) {
  return _nonMusicArtistRegex.hasMatch(artist);
}

/// Clean a song title by removing extraneous parenthetical tags for cleaner search queries
String _cleanTitle(String title) {
  return title
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Universal Recommendation Service
///
/// Provides intelligent music recommendations by:
/// 1. Learning from playback history and favorites without data inflation.
/// 2. Leveraging YouTube Music Watch-Next (Up Next) and Radio Mix queues.
/// 3. Leveraging JioSaavn algorithmic recommendations for regional Indian tracks.
/// 4. Maintaining strict language consistency for Similar mode.
/// 5. Providing multi-seed, balanced diversity for Discover mode.
class RecommendationService {
  static const String _settingsBoxName = 'recommendation_settings';
  static const String _profileBoxName = 'user_taste_profile';

  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final SettingsService _settingsService = SettingsService.instance;

  Box? _settingsBox;
  Box? _profileBox;

  // User taste profile - built freshly from listening history and favorites
  Map<String, int> _artistPlayCounts = {};
  Map<String, int> _genrePlayCounts = {};
  Map<String, int> _languagePlayCounts = {};
  Set<String> _recentlyPlayedKeys = {};
  DateTime? _profileCacheTime;
  static const _profileCacheDuration = Duration(minutes: 3);

  RecommendationService(this._musicRepository, this._libraryRepository);

  Future<void> initialize() async {
    try {
      if (Hive.isBoxOpen(_settingsBoxName)) {
        _settingsBox = Hive.box(_settingsBoxName);
      } else {
        _settingsBox = await Hive.openBox(_settingsBoxName);
      }

      if (Hive.isBoxOpen(_profileBoxName)) {
        _profileBox = Hive.box(_profileBoxName);
      } else {
        _profileBox = await Hive.openBox(_profileBoxName);
      }

      _loadCachedProfile();
      logDebug('RecommendationService: Initialized successfully');
    } catch (e) {
      logError('Recommendation service initialization error', e, StackTrace.current);
      rethrow;
    }
  }

  void _loadCachedProfile() {
    try {
      final artistData = _profileBox?.get('artist_counts');
      if (artistData is Map) {
        _artistPlayCounts = Map<String, int>.from(artistData);
      }

      final genreData = _profileBox?.get('genre_counts');
      if (genreData is Map) {
        _genrePlayCounts = Map<String, int>.from(genreData);
      }

      final languageData = _profileBox?.get('language_counts');
      if (languageData is Map) {
        _languagePlayCounts = Map<String, int>.from(languageData);
      }

      logDebug('Loaded cached taste profile: ${_artistPlayCounts.length} artists, ${_genrePlayCounts.length} genres, ${_languagePlayCounts.length} languages');
    } catch (e) {
      logError('Error loading cached profile', e, StackTrace.current);
    }
  }

  Future<void> _saveTasteProfile() async {
    try {
      await _profileBox?.put('artist_counts', _artistPlayCounts);
      await _profileBox?.put('genre_counts', _genrePlayCounts);
      await _profileBox?.put('language_counts', _languagePlayCounts);
      await _profileBox?.put('last_updated', DateTime.now().toIso8601String());
    } catch (e) {
      logError('Error saving taste profile', e, StackTrace.current);
    }
  }

  // Get current recommendation mode
  RecommendationMode get mode {
    try {
      final modeString = _settingsBox?.get('recommendation_mode', defaultValue: 'similar') ?? 'similar';
      return modeString == 'discover'
          ? RecommendationMode.discover
          : RecommendationMode.similar;
    } catch (e) {
      logError('Error getting recommendation mode', e, StackTrace.current);
      return RecommendationMode.similar;
    }
  }

  // Set recommendation mode
  Future<void> setMode(RecommendationMode mode) async {
    await _settingsBox?.put(
      'recommendation_mode',
      mode == RecommendationMode.discover ? 'discover' : 'similar',
    );
  }

  /// Record a song play - updates profile and recently played tracks
  Future<void> recordPlay(Song song) async {
    try {
      final artistKey = song.artist.toLowerCase().trim();
      if (artistKey.isNotEmpty && !_isLikelyNonMusicArtistName(artistKey)) {
        _artistPlayCounts[artistKey] = (_artistPlayCounts[artistKey] ?? 0) + 1;
      }

      final genre = _detectGenre(song);
      if (genre != null) {
        _genrePlayCounts[genre] = (_genrePlayCounts[genre] ?? 0) + 1;
      }

      final language = _detectLanguage(song);
      if (language != null) {
        _languagePlayCounts[language] = (_languagePlayCounts[language] ?? 0) + 1;
      }

      final playKey = '${song.title.toLowerCase().trim()}|${song.artist.toLowerCase().trim()}';
      _recentlyPlayedKeys.add(playKey);

      if (_recentlyPlayedKeys.length > 200) {
        _recentlyPlayedKeys = _recentlyPlayedKeys.toList().sublist(_recentlyPlayedKeys.length - 200).toSet();
      }

      await _saveTasteProfile();
      logDebug('Recorded play: ${song.artist} - ${song.title} (language: $language, genre: $genre)');
    } catch (e) {
      logError('Error recording play', e, StackTrace.current);
    }
  }

  /// Get recommendations based on current mode
  Future<List<Song>> getRecommendations({
    Song? currentSong,
    int limit = 10,
  }) async {
    await _refreshListeningProfile();

    if (mode == RecommendationMode.similar) {
      if (currentSong != null) {
        return _getSimilarSongs(currentSong, limit);
      }
      final seed = await _resolveFallbackSeedSong();
      if (seed != null) {
        return _getSimilarSongs(seed, limit);
      }
      return _getDiscoverySongs(null, limit);
    } else {
      return _getDiscoverySongs(currentSong, limit);
    }
  }

  Future<Song?> _resolveFallbackSeedSong() async {
    try {
      final historyResult = await _libraryRepository.getListeningHistory(limit: 1);
      return historyResult.fold((_) => null, (songs) => songs.firstOrNull);
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Listening profile — rebuilds clean taste snapshot from history and favorites
  // ──────────────────────────────────────────────────────────────────

  Future<void> _refreshListeningProfile() async {
    if (_profileCacheTime != null &&
        DateTime.now().difference(_profileCacheTime!) < _profileCacheDuration) {
      return; // Cache is still fresh
    }

    try {
      final historyResult = await _libraryRepository.getListeningHistory(limit: 100);
      final favoritesResult = await _libraryRepository.getLikedSongs();

      final newArtistCounts = <String, int>{};
      final newGenreCounts = <String, int>{};
      final newLanguageCounts = <String, int>{};
      final newRecentKeys = <String>{};

      historyResult.fold(
        (failure) => logError('Failed to load listening history for profile: ${failure.message}'),
        (songs) {
          for (final s in songs) {
            final key = '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}';
            newRecentKeys.add(key);

            final artistKey = s.artist.toLowerCase().trim();
            if (artistKey.isNotEmpty && !_isLikelyNonMusicArtistName(artistKey)) {
              newArtistCounts[artistKey] = (newArtistCounts[artistKey] ?? 0) + 1;
            }

            final genre = _detectGenre(s);
            if (genre != null) {
              newGenreCounts[genre] = (newGenreCounts[genre] ?? 0) + 1;
            }

            final language = _detectLanguage(s);
            if (language != null) {
              newLanguageCounts[language] = (newLanguageCounts[language] ?? 0) + 1;
            }
          }
        },
      );

      favoritesResult.fold(
        (failure) => null,
        (favorites) {
          for (final s in favorites) {
            final artistKey = s.artist.toLowerCase().trim();
            if (artistKey.isNotEmpty && !_isLikelyNonMusicArtistName(artistKey)) {
              newArtistCounts[artistKey] = (newArtistCounts[artistKey] ?? 0) + 3; // Boost favorites
            }

            final genre = _detectGenre(s);
            if (genre != null) {
              newGenreCounts[genre] = (newGenreCounts[genre] ?? 0) + 2;
            }

            final language = _detectLanguage(s);
            if (language != null) {
              newLanguageCounts[language] = (newLanguageCounts[language] ?? 0) + 2;
            }
          }
        },
      );

      _artistPlayCounts = newArtistCounts;
      _genrePlayCounts = newGenreCounts;
      _languagePlayCounts = newLanguageCounts;
      _recentlyPlayedKeys = newRecentKeys;
      _profileCacheTime = DateTime.now();

      await _saveTasteProfile();
      logDebug('Refreshed listening profile: ${_artistPlayCounts.length} artists, ${_genrePlayCounts.length} genres, ${_languagePlayCounts.length} languages, ${_recentlyPlayedKeys.length} recent tracks');
    } catch (e) {
      logError('Error building listening profile', e, StackTrace.current);
    }
  }

  /// Get top N entries from a play count map
  List<String> _getTopN(Map<String, int> counts, int n) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Get top languages based on listening history
  List<String> get _topLanguages => _getTopN(_languagePlayCounts, 3);

  /// Get preferred language based on listening history
  String? get _preferredLanguage => _topLanguages.firstOrNull;

  /// Get top artists based on listening history
  List<String> get _topArtists => _getTopN(_artistPlayCounts, 20)
      .where((artist) => !_isLikelyNonMusicArtistName(artist))
      .take(10)
      .toList();

  /// Get preferred genre based on listening history
  String? get _preferredGenre => _getTopN(_genrePlayCounts, 1).firstOrNull;

  // ──────────────────────────────────────────────────────────────────
  // SIMILAR mode — songs that sound like what's playing
  // Uses YouTube Music Watch Next, Radio Mix (RDAMVM), and JioSaavn suggestions
  // ──────────────────────────────────────────────────────────────────

  Future<List<Song>> _getSimilarSongs(Song song, int limit) async {
    final candidatePool = <Song>[];
    final directAlgorithmicKeys = <String>{};

    try {
      logDebug('Getting similar songs for: "${song.title}" by ${song.artist}');

      final songLanguage = _detectLanguage(song);
      final songGenre = _detectGenre(song) ?? _preferredGenre;
      final videoId = song.youtubeId ??
          (song.source == MusicSource.youtube || song.source == MusicSource.youtubeMusic ? song.id : null) ??
          (song.playableId.isNotEmpty ? song.playableId : null);
      final jioSaavnId = song.jioSaavnId ??
          (song.source == MusicSource.jiosaavn ? song.id : null);

      logDebug('Similar seed: videoId=$videoId, jioSaavnId=$jioSaavnId, language=$songLanguage, genre=$songGenre');

      final futures = <Future>[];

      // 1. Primary: YouTube Music UpNext & Mix Radio (Highest Quality)
      if (videoId != null && videoId.isNotEmpty) {
        futures.add(
          _musicRepository.getRelatedSongs(videoId, limit: limit * 2).then((result) {
            result.fold(
              (failure) => logDebug('getRelatedSongs failed: ${failure.message}'),
              (songs) {
                logDebug('Found ${songs.length} songs from YouTube related');
                for (final s in songs) {
                  final k = '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}';
                  directAlgorithmicKeys.add(k);
                  candidatePool.add(s);
                }
              },
            );
          }),
        );
      }

      // 2. JioSaavn Suggestions (for Indian & regional tracks)
      if (jioSaavnId != null && jioSaavnId.isNotEmpty) {
        futures.add(
          _musicRepository.getJioSaavnSuggestions(jioSaavnId, limit: limit * 2).then((result) {
            result.fold(
              (failure) => logDebug('JioSaavn suggestions failed: ${failure.message}'),
              (songs) {
                logDebug('Found ${songs.length} songs from JioSaavn suggestions');
                for (final s in songs) {
                  final k = '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}';
                  directAlgorithmicKeys.add(k);
                  candidatePool.add(s);
                }
              },
            );
          }),
        );
      }

      // 3. Supplemental search queries if needed (only clean, high-precision searches)
      final cleanSeedTitle = _cleanTitle(song.title);
      futures.add(
        _musicRepository.searchSongs(
          '${song.artist} $cleanSeedTitle',
          limit: 10,
        ).then((r) => r.fold((_) => null, (songs) => candidatePool.addAll(songs))),
      );

      futures.add(
        _musicRepository.searchSongs(
          '${song.artist} top songs',
          limit: 10,
        ).then((r) => r.fold((_) => null, (songs) => candidatePool.addAll(songs))),
      );

      await Future.wait(futures);

      // Filter out seed song, invalid lengths, and junk
      final filtered = _filterCandidates(
        candidatePool,
        seedSong: song,
        minDurationSec: 75,
        maxDurationSec: 450,
      );

      // Rank candidates using similarity scoring
      final ranked = _rankSimilar(
        filtered,
        seedSong: song,
        seedLanguage: songLanguage,
        directKeys: directAlgorithmicKeys,
        limit: limit,
      );

      logDebug('Returning ${ranked.length} similar songs (${candidatePool.length} raw → ${filtered.length} filtered)');
      return ranked;
    } catch (e, st) {
      logError('Error getting similar songs', e, st);
      return [];
    }
  }

  /// Rank songs for similar mode
  List<Song> _rankSimilar(
    List<Song> songs, {
    required Song seedSong,
    required String? seedLanguage,
    required Set<String> directKeys,
    required int limit,
  }) {
    final seedArtistLower = seedSong.artist.toLowerCase().trim();
    final artistCountMap = <String, int>{};
    final scored = <_ScoredSong>[];

    for (final song in songs) {
      int score = 0;
      final songArtistLower = song.artist.toLowerCase().trim();
      final songKey = '${song.title.toLowerCase().trim()}|$songArtistLower';

      // 1. Direct Algorithmic Recommendation bonus (from UpNext / JioSaavn)
      if (directKeys.contains(songKey)) {
        score += 8;
      }

      // 2. Artist Balance: Allow up to 3 songs by the same artist without penalizing
      final currentArtistCount = artistCountMap[songArtistLower] ?? 0;
      if (songArtistLower == seedArtistLower) {
        if (currentArtistCount < 2) {
          score += 4; // Same artist bonus for 1-2 tracks
        } else if (currentArtistCount == 2) {
          score += 1; // Neutral for 3rd track
        } else {
          score -= 5; // Demote beyond 3 tracks to preserve variety
        }
      } else {
        if (currentArtistCount < 3) {
          score += 3;
        } else {
          score -= 4;
        }
      }

      // 3. Language Consistency — Must match seed song's language family
      if (seedLanguage != null) {
        final songLang = _detectLanguage(song);
        if (songLang == seedLanguage) {
          score += 6; // Matching language → strong boost
        } else if (songLang != null && songLang != seedLanguage && songLang != 'English') {
          score -= 7; // Different regional language → strong penalty
        }
      }

      // 4. Official high-quality release
      if (_officialMusicRegex.hasMatch(song.title.toLowerCase())) {
        score += 2;
      }

      // 5. Ideal radio track duration (2 to 5 minutes)
      final durationSec = song.duration.inSeconds;
      if (durationSec >= 120 && durationSec <= 300) {
        score += 2;
      }

      // 6. User familiarity bonus (if artist is in history)
      if (_artistPlayCounts.containsKey(songArtistLower)) {
        score += 1;
      }

      artistCountMap[songArtistLower] = currentArtistCount + 1;
      scored.add(_ScoredSong(song: song, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Cap same artist to at most 3 in the final output
    final finalSongs = <Song>[];
    final finalArtistCounts = <String, int>{};

    for (final item in scored) {
      final aKey = item.song.artist.toLowerCase().trim();
      final count = finalArtistCounts[aKey] ?? 0;
      if (count >= 3) continue;

      finalArtistCounts[aKey] = count + 1;
      finalSongs.add(item.song);
      if (finalSongs.length >= limit) break;
    }

    return finalSongs;
  }

  // ──────────────────────────────────────────────────────────────────
  // Shared filter: dedup, remove covers/mashups/compilations, valid duration
  // ──────────────────────────────────────────────────────────────────

  List<Song> _filterCandidates(
    List<Song> candidates, {
    Song? seedSong,
    int minDurationSec = 75,
    int maxDurationSec = 450,
  }) {
    final seenTracks = <String>{};
    if (seedSong != null) {
      seenTracks.add('${seedSong.title.toLowerCase().trim()}|${seedSong.artist.toLowerCase().trim()}');
    }

    final filtered = <Song>[];

    for (final s in candidates) {
      if (s.playableId.isEmpty) continue;

      final titleLower = s.title.toLowerCase().trim();
      final artistLower = s.artist.toLowerCase().trim();
      final trackKey = '$titleLower|$artistLower';

      if (seenTracks.contains(trackKey)) continue;
      if (_isLikelyNonMusicArtistName(s.artist)) continue;
      if (_isLikelyNonMusic(s)) continue;

      final dur = s.duration.inSeconds;
      // If duration is known, enforce strict bounds
      if (dur > 0 && (dur < minDurationSec || dur > maxDurationSec)) {
        continue;
      }

      seenTracks.add(trackKey);
      filtered.add(s);
    }

    return filtered;
  }

  // ──────────────────────────────────────────────────────────────────
  // DISCOVER mode — finds fresh music based on user's full taste profile
  // ──────────────────────────────────────────────────────────────────

  Future<List<Song>> _getDiscoverySongs(Song? seedSong, int limit) async {
    final candidatePool = <Song>[];

    try {
      final countryCode = _settingsService.countryCode;
      final countryName = _settingsService.selectedCountry.name;
      final currentYear = DateTime.now().year;
      final topArtists = _topArtists;
      final topLanguages = _topLanguages;
      final topGenre = _preferredGenre;

      logDebug('Discover: country=$countryCode, topArtists=$topArtists, topLanguages=$topLanguages, topGenre=$topGenre');

      final futures = <Future>[];

      // 1. Multi-Seed Source: Top Played Artists' Radios & Top Tracks
      if (topArtists.isNotEmpty) {
        for (final artist in topArtists.take(3)) {
          futures.add(
            _musicRepository.searchSongs('$artist songs', limit: 8).then(
              (r) => r.fold((_) => null, (songs) => candidatePool.addAll(songs)),
            ),
          );
        }
      }

      // 2. Genre Discovery
      if (topGenre != null && topGenre.isNotEmpty) {
        futures.add(
          _musicRepository.searchSongs('best $topGenre songs $currentYear', limit: 8).then(
            (r) => r.fold((_) => null, (songs) => candidatePool.addAll(songs)),
          ),
        );
      }

      // 3. Language Trending
      if (topLanguages.isNotEmpty && topLanguages.first != 'English') {
        final lang = topLanguages.first;
        futures.add(
          _musicRepository.searchSongs('trending $lang songs $currentYear', limit: 8).then(
            (r) => r.fold((_) => null, (songs) => candidatePool.addAll(songs)),
          ),
        );
      }

      // 4. Regional Trending (Always included for fresh chart hits)
      futures.add(
        _musicRepository.getTrending(region: countryCode, limit: 20).then(
          (r) => r.fold((_) => null, (songs) => candidatePool.addAll(songs)),
        ),
      );

      // 5. Global / Regional Fallbacks for cold start (fresh installs)
      if (topArtists.isEmpty) {
        futures.add(
          _musicRepository.searchSongs('top hits $countryName $currentYear', limit: 12).then(
            (r) => r.fold((_) => null, (songs) => candidatePool.addAll(songs)),
          ),
        );
      }

      await Future.wait(futures);

      // Filter out songs already played recently, invalid durations, non-music
      final seenKeys = Set<String>.from(_recentlyPlayedKeys);
      if (seedSong != null) {
        seenKeys.add('${seedSong.title.toLowerCase().trim()}|${seedSong.artist.toLowerCase().trim()}');
      }

      final filtered = <Song>[];
      for (final s in candidatePool) {
        if (s.playableId.isEmpty) continue;
        final k = '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}';
        if (seenKeys.contains(k)) continue;
        if (_isLikelyNonMusic(s) || _isLikelyNonMusicArtistName(s.artist)) continue;

        final dur = s.duration.inSeconds;
        if (dur > 0 && (dur < 75 || dur > 420)) continue;

        seenKeys.add(k);
        filtered.add(s);
      }

      logDebug('Filtered to ${filtered.length} unique discovery candidates');

      if (filtered.isEmpty) {
        // Fallback to trending
        final trendingResult = await _musicRepository.getTrending(region: countryCode, limit: limit);
        return trendingResult.fold((_) => [], (songs) => songs.take(limit).toList());
      }

      // Score discovery candidates
      final scored = filtered.map((s) {
        int score = 0;
        final sArtist = s.artist.toLowerCase().trim();
        final sLang = _detectLanguage(s);
        final sGenre = _detectGenre(s);

        // Language affinity
        if (topLanguages.contains(sLang)) {
          score += 5;
        }

        // Genre affinity
        if (sGenre != null && _genrePlayCounts.containsKey(sGenre)) {
          score += 4;
        }

        // Discover bonus: artists related to taste but not over-listened
        if (_artistPlayCounts.containsKey(sArtist)) {
          score += 2; // Familiar favorite
        } else {
          score += 4; // True discovery: new artist
        }

        // Official content priority
        if (_officialMusicRegex.hasMatch(s.title.toLowerCase())) {
          score += 2;
        }

        // Duration bonus (ideal single length)
        final dur = s.duration.inSeconds;
        if (dur >= 130 && dur <= 270) {
          score += 2;
        }

        return _ScoredSong(song: s, score: score);
      }).toList();

      scored.sort((a, b) => b.score.compareTo(a.score));

      // Diversity cap: Max 2 songs per artist in Discover mode
      final output = <Song>[];
      final artistCounts = <String, int>{};

      for (final item in scored) {
        final aKey = item.song.artist.toLowerCase().trim();
        final count = artistCounts[aKey] ?? 0;
        if (count >= 2) continue;

        artistCounts[aKey] = count + 1;
        output.add(item.song);
        if (output.length >= limit) break;
      }

      logDebug('Returning ${output.length} discovery songs');
      return output;
    } catch (e, st) {
      logError('Error getting discovery songs', e, st);
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Genre detection
  // ──────────────────────────────────────────────────────────────────

  String? _detectGenre(Song song) {
    if (song.genre != null && song.genre!.isNotEmpty) {
      return song.genre;
    }

    final combined = '${song.title} ${song.artist} ${song.album ?? ''}'.toLowerCase();

    if (combined.contains('rap') || combined.contains('hip hop') || combined.contains('hip-hop') || combined.contains('trap')) {
      return 'Hip Hop Rap';
    }
    if (combined.contains('bollywood') || combined.contains('hindi movie') || combined.contains('filmi')) {
      return 'Bollywood';
    }
    if (combined.contains('punjabi') || combined.contains('bhangra')) {
      return 'Punjabi Pop';
    }
    if (combined.contains('telugu') || combined.contains('tollywood')) {
      return 'Tollywood';
    }
    if (combined.contains('tamil') || combined.contains('kollywood')) {
      return 'Kollywood';
    }
    if (combined.contains('rock') || combined.contains('metal') || combined.contains('punk') || combined.contains('grunge')) {
      return 'Rock';
    }
    if (combined.contains('edm') || combined.contains('electronic') || combined.contains('dance') || combined.contains('house') || combined.contains('techno')) {
      return 'Electronic Dance';
    }
    if (combined.contains('r&b') || combined.contains('soul') || combined.contains('rnb')) {
      return 'R&B Soul';
    }
    if (combined.contains('latin') || combined.contains('reggaeton') || combined.contains('salsa') || combined.contains('bachata')) {
      return 'Latin';
    }
    if (combined.contains('k-pop') || combined.contains('kpop')) {
      return 'K-Pop';
    }
    if (combined.contains('j-pop') || combined.contains('jpop') || combined.contains('anime')) {
      return 'J-Pop';
    }
    if (combined.contains('country') || combined.contains('folk') || combined.contains('bluegrass')) {
      return 'Country';
    }
    if (combined.contains('jazz') || combined.contains('blues')) {
      return 'Jazz';
    }
    if (combined.contains('reggae') || combined.contains('dancehall') || combined.contains('afrobeats')) {
      return 'Reggae & Afro';
    }
    if (combined.contains('classical') || combined.contains('orchestra') || combined.contains('piano') || combined.contains('symphony')) {
      return 'Classical';
    }
    if (combined.contains('indie') || combined.contains('alternative') || combined.contains('acoustic')) {
      return 'Indie Alternative';
    }
    if (combined.contains('pop')) {
      return 'Pop';
    }

    return null;
  }

  // ──────────────────────────────────────────────────────────────────
  // Language detection — multi-script & keyword based intelligence
  // ──────────────────────────────────────────────────────────────────

  static final _hindiKeywords = RegExp(
    r'hindi|bollywood|arijit|atif aslam|shreya ghoshal|neha kakkar|jubin|'
    r'badshah|honey singh|armaan malik|darshan raval|sonu nigam|'
    r'kumar sanu|kishore kumar|lata mangeshkar|asha bhosle|alka yagnik|'
    r'udit narayan|mohd rafi|sunidhi chauhan|shankar mahadevan|t-series|'
    r'zee music|tips official|saregama|yrf|pritam|vishal mishra|jasleen|'
    r'sachet-parampara|mithoon|b praak',
    caseSensitive: false,
  );

  static final _punjabiKeywords = RegExp(
    r'punjabi|sidhu moose|ap dhillon|diljit|guru randhawa|harrdy sandhu|'
    r'karan aujla|ammy virk|jassie gill|garry sandhu|jasmine sandlas|'
    r'jaani|amrinder gill|gurdas maan|shubh|jordan sandhu|speed records|'
    r'white hill music',
    caseSensitive: false,
  );

  static final _tamilKeywords = RegExp(
    r'tamil|anirudh ravichander|yuvan shankar|ar rahman|a\.r\. rahman|sid sriram|'
    r'harris jayaraj|d imman|hiphop tamizha|gv prakash|santhosh narayanan|'
    r'sony music south|think music|kollywood|ilaiyaraaja|vijay antony',
    caseSensitive: false,
  );

  static final _teluguKeywords = RegExp(
    r'telugu|tollywood|devi sri prasad|dsp|thaman|aditya music|'
    r'mango music|lahari music|anup rubens|ram miriyala|anurag kulkarni|'
    r'keeravani|m\.m\. keeravani|geetha madhuri',
    caseSensitive: false,
  );

  static final _malayalamKeywords = RegExp(
    r'malayalam|mollywood|sushin shyam|shaan rahman|heshem abdul|'
    r'gopi sundar|job kurian|vijay yesudas|ks chithra',
    caseSensitive: false,
  );

  static final _kannadaKeywords = RegExp(
    r'kannada|sandalwood|charan raj|arjun janya|ravi basrur|vasuki vaibhav|vijay prakash',
    caseSensitive: false,
  );

  static final _spanishKeywords = RegExp(
    r'spanish|latino|reggaeton|bad bunny|j balvin|ozuna|'
    r'daddy yankee|maluma|nicky jam|anuel|karol g|'
    r'rauw alejandro|rosalía|farruko|becky g|sech|peso pluma|bizarrap|'
    r'feid|myke towers|manuel turizo|sebastian yatra',
    caseSensitive: false,
  );

  static final _koreanKeywords = RegExp(
    r'korean|k-pop|kpop|bts|blackpink|twice|stray kids|'
    r'aespa|newjeans|ive|seventeen|exo|nct|txt|ateez|'
    r'itzy|le sserafim|hybe|enhypen|illit|jungkook|jimin',
    caseSensitive: false,
  );

  static final _japaneseKeywords = RegExp(
    r'japanese|j-pop|jpop|anime|yoasobi|ado|kenshi yonezu|'
    r'official hige|lisa|vaundy|fujii kaze|imase|'
    r'one ok rock|radwimps|aimer|eve|king gnu',
    caseSensitive: false,
  );

  /// Detect language/region from song's title, artist name, and script
  String? _detectLanguage(Song song) {
    final original = '${song.title} ${song.artist} ${song.album ?? ''}';
    final combined = original.toLowerCase();

    // 1. Script-based detection (100% deterministic)
    if (RegExp(r'[\u0900-\u097F]').hasMatch(original)) return 'Hindi';
    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(original)) return 'Punjabi';
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(original)) return 'Tamil';
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(original)) return 'Telugu';
    if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(original)) return 'Malayalam';
    if (RegExp(r'[\u0C80-\u0CFF]').hasMatch(original)) return 'Kannada';
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(original)) return 'Bengali';
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(original)) return 'Gujarati';
    if (RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]').hasMatch(original)) return 'Korean';
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(original)) return 'Japanese';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(original)) return 'Arabic';

    // 2. Keyword-based detection
    if (_hindiKeywords.hasMatch(combined)) return 'Hindi';
    if (_punjabiKeywords.hasMatch(combined)) return 'Punjabi';
    if (_tamilKeywords.hasMatch(combined)) return 'Tamil';
    if (_teluguKeywords.hasMatch(combined)) return 'Telugu';
    if (_malayalamKeywords.hasMatch(combined)) return 'Malayalam';
    if (_kannadaKeywords.hasMatch(combined)) return 'Kannada';
    if (_spanishKeywords.hasMatch(combined)) return 'Spanish';
    if (_koreanKeywords.hasMatch(combined)) return 'Korean';
    if (_japaneseKeywords.hasMatch(combined)) return 'Japanese';

    // 3. Latin alphabet defaults to English
    if (RegExp(r'[a-zA-Z]').hasMatch(original)) {
      return 'English';
    }

    return null;
  }

  // Get recommendation description based on mode
  String getModeDescription() {
    switch (mode) {
      case RecommendationMode.similar:
        return 'Playing songs with a similar vibe';
      case RecommendationMode.discover:
        return 'Discovering new music based on your taste';
    }
  }

  String getModeName() {
    switch (mode) {
      case RecommendationMode.similar:
        return 'Similar';
      case RecommendationMode.discover:
        return 'Discover';
    }
  }

  /// Dispose of resources and clear caches
  Future<void> dispose() async {
    if (_settingsBox?.isOpen ?? false) {
      await _settingsBox?.close();
    }
    if (_profileBox?.isOpen ?? false) {
      await _profileBox?.close();
    }
    _settingsBox = null;
    _profileBox = null;
  }

  /// Get a summary of the user's taste profile (for debugging or display)
  Map<String, dynamic> getTasteProfileSummary() {
    return {
      'topArtists': _topArtists.take(5).toList(),
      'preferredGenre': _preferredGenre,
      'preferredLanguage': _preferredLanguage,
      'totalArtistsTracked': _artistPlayCounts.length,
      'totalGenresTracked': _genrePlayCounts.length,
      'totalLanguagesTracked': _languagePlayCounts.length,
      'recentlyPlayedCount': _recentlyPlayedKeys.length,
    };
  }
}

/// Helper class for scoring songs by relevance
class _ScoredSong {
  final Song song;
  final int score;

  _ScoredSong({required this.song, required this.score});
}

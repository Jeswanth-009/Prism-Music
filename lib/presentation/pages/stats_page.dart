import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injection.dart';
import '../../core/services/listening_activity_feed_service.dart';
import '../../domain/entities/listening_stats.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/library_repository.dart';
import '../blocs/library/library.dart';
import '../theme/prism_theme.dart';
import '../../core/utils/formatters.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/prism/prism_states.dart';
import '../widgets/stats/stats_export_sheet.dart';

/// Full listening overview: headline numbers, weekly recap feed, and annual
/// "Your Year in Music" recap derived from play history.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<HistoryEntry> _entries = const [];
  bool _loadingHistory = true;
  int _selectedTab = 0; // 0: Overview, 1: Weekly Recap, 2: Year in Music
  static const _feedService = ListeningActivityFeedService();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final result = await getIt<LibraryRepository>().getHistoryEntries();
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loadingHistory = false),
      (entries) => setState(() {
        _entries = entries;
        _loadingHistory = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export or share stats',
            onPressed: () {
              final stats = context.read<LibraryBloc>().state.stats;
              if (stats == null || stats.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No listening data to export yet.')),
                );
                return;
              }
              StatsExportSheet.show(
                context,
                stats: stats,
                entries: _entries,
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final stats = state.stats;
          if (stats == null || stats.isEmpty) {
            return const PrismEmptyState(
              icon: Icons.bar_chart_rounded,
              message: 'No listening data yet',
              hint: 'Play a few songs and your stats will build up here.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Overview'),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Weekly Recap'),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text('Year in Music'),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (set) =>
                        setState(() => _selectedTab = set.first),
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    _OverviewTab(
                      stats: stats,
                      entries: _entries,
                      loadingHistory: _loadingHistory,
                    ),
                    _WeeklyRecapTab(
                      entries: _entries,
                      loadingHistory: _loadingHistory,
                      feedService: _feedService,
                    ),
                    _YearInReviewTab(
                      entries: _entries,
                      loadingHistory: _loadingHistory,
                      feedService: _feedService,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const PrismPersistentMiniPlayer(),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.stats,
    required this.entries,
    required this.loadingHistory,
  });

  final ListeningStats stats;
  final List<HistoryEntry> entries;
  final bool loadingHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        _HeadlineStats(stats: stats),
        const SizedBox(height: 24),
        if (!loadingHistory) ...[
          Text(
            'Last 14 days',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _PlaysChart(entries: entries),
          const SizedBox(height: 24),
        ],
        Text(
          'Top of your rotation',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _TopRow(
          icon: Icons.person_rounded,
          label: 'Top artist',
          title: stats.topArtist ?? '—',
          meta: stats.topArtist == null
              ? null
              : '${stats.topArtistCount} plays',
        ),
        _TopRow(
          icon: Icons.music_note_rounded,
          label: 'Most played song',
          title: stats.mostPlayedSong?.title ?? '—',
          meta: stats.mostPlayedSong == null
              ? null
              : '${stats.mostPlayedCount} plays · '
                  '${stats.mostPlayedSong!.artist}',
        ),
        if (stats.topGenre != null)
          _TopRow(
            icon: Icons.category_rounded,
            label: 'Top genre',
            title: stats.topGenre!,
            meta: '${stats.topGenreCount} plays',
          ),
        const SizedBox(height: 16),
        const _DataRetentionCard(),
        if (stats.firstPlayed != null) ...[
          const SizedBox(height: 18),
          Text(
            'Listening since '
            '${Formatters.formatDate(stats.firstPlayed!)} · last play '
            '${Formatters.formatDate(stats.lastPlayed ?? stats.firstPlayed!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _WeeklyRecapTab extends StatelessWidget {
  const _WeeklyRecapTab({
    required this.entries,
    required this.loadingHistory,
    required this.feedService,
  });

  final List<HistoryEntry> entries;
  final bool loadingHistory;
  final ListeningActivityFeedService feedService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recap = feedService.generateWeeklyRecap(entries);

    if (loadingHistory) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (recap.isEmpty) {
      return const PrismEmptyState(
        icon: Icons.calendar_today_rounded,
        message: 'No activity this week',
        hint: 'Play some music this week to unlock your weekly recap.',
      );
    }

    final hours = recap.totalListeningTime.inHours;
    final mins = recap.totalListeningTime.inMinutes % 60;
    final timeStr = hours > 0 ? '$hours hr $mins m' : '$mins mins';
    final trendText = recap.trendPercentage > 0
        ? '+${recap.trendPercentage.toStringAsFixed(0)}% vs last week'
        : recap.trendPercentage < 0
            ? '${recap.trendPercentage.toStringAsFixed(0)}% vs last week'
            : 'Same as last week';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                theme.colorScheme.surfaceContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            border: Border.all(color: context.prismSpec.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WEEKLY RECAP',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trendText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: recap.trendPercentage >= 0
                            ? Colors.greenAccent.shade700
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${recap.totalPlays} plays · $timeStr',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Formatters.formatDate(recap.startDate)} – ${Formatters.formatDate(recap.endDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Top Songs This Week',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < recap.topSongs.length; i++)
          _RankedSongRow(
            rank: i + 1,
            song: recap.topSongs[i].key,
            playCount: recap.topSongs[i].value,
          ),
        const SizedBox(height: 20),
        Text(
          'Top Artists This Week',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final artist in recap.topArtists)
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    '${artist.value}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                label: Text(artist.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _YearInReviewTab extends StatelessWidget {
  const _YearInReviewTab({
    required this.entries,
    required this.loadingHistory,
    required this.feedService,
  });

  final List<HistoryEntry> entries;
  final bool loadingHistory;
  final ListeningActivityFeedService feedService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = feedService.generateYearInReview(entries);

    if (loadingHistory) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (review.isEmpty) {
      return const PrismEmptyState(
        icon: Icons.auto_awesome_rounded,
        message: 'No annual listening records',
        hint: 'Keep listening throughout the year to build your Year in Music.',
      );
    }

    final totalMins = review.totalListeningTime.inMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.tertiaryContainer.withValues(alpha: 0.8),
                theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                theme.colorScheme.surfaceContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            border: Border.all(color: context.prismSpec.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOUR YEAR IN MUSIC',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${review.year}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      review.personalityBadge,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                review.personalityDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatTile(value: '$totalMins', label: 'Minutes listened'),
            const SizedBox(width: 10),
            _StatTile(value: '${review.uniqueSongs}', label: 'Unique tracks'),
            const SizedBox(width: 10),
            _StatTile(value: '${review.uniqueArtists}', label: 'Artists discovered'),
          ],
        ),
        if (review.mostActiveMonth != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(PrismRadius.md),
              border: Border.all(color: context.prismSpec.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your peak listening month was ${review.mostActiveMonth} with ${review.mostActiveMonthPlays} plays.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Top Songs of ${review.year}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < review.topSongs.take(5).length; i++)
          _RankedSongRow(
            rank: i + 1,
            song: review.topSongs[i].key,
            playCount: review.topSongs[i].value,
          ),
        const SizedBox(height: 20),
        Text(
          'Top Artists of ${review.year}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final artist in review.topArtists.take(8))
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    '${artist.value}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                label: Text(artist.key),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Your Year in Music'),
            onPressed: () {
              final topSong = review.topSongs.isNotEmpty ? review.topSongs.first.key.title : '—';
              final topArtist = review.topArtists.isNotEmpty ? review.topArtists.first.key : '—';
              final shareText = '''
🎵 My Prism Year in Music (${review.year})
• Personality: ${review.personalityBadge}
• Listening Time: $totalMins minutes
• Top Song: $topSong
• Top Artist: $topArtist
• Unique Tracks: ${review.uniqueSongs}
Streamed on Prism Music.
''';
              Share.share(shareText, subject: 'My ${review.year} in Music');
            },
          ),
        ),
      ],
    );
  }
}

class _RankedSongRow extends StatelessWidget {
  const _RankedSongRow({
    required this.rank,
    required this.song,
    required this.playCount,
  });

  final int rank;
  final Song song;
  final int playCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(PrismRadius.md),
          border: Border.all(color: context.prismSpec.hairline),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: rank <= 3 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$playCount plays',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRetentionCard extends StatelessWidget {
  const _DataRetentionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border.all(color: context.prismSpec.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private & On-Device',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Listening history and play counts are stored strictly on this device to calculate your personal trends. You can clear your history anytime from Recently Played.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlineStats extends StatelessWidget {
  const _HeadlineStats({required this.stats});

  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final hours = stats.totalListeningTime.inHours;
    final minutes = stats.totalListeningTime.inMinutes % 60;
    final listeningTime = hours > 0 ? '$hours hr $minutes m' : '$minutes min';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  _StatTile(value: '${stats.totalPlays}', label: 'Plays'),
                  const SizedBox(width: 10),
                  _StatTile(value: '${stats.uniqueSongs}', label: 'Unique songs'),
                ],
              ),
              const SizedBox(height: 10),
              _StatTile(value: listeningTime, label: 'Listening time'),
            ],
          );
        }
        return Row(
          children: [
            _StatTile(value: '${stats.totalPlays}', label: 'Plays'),
            const SizedBox(width: 10),
            _StatTile(value: '${stats.uniqueSongs}', label: 'Unique songs'),
            const SizedBox(width: 10),
            _StatTile(value: listeningTime, label: 'Listening time'),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          border: Border.all(color: context.prismSpec.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple bar chart of plays per day for the last 14 days. Bars are plain
/// containers — no chart dependency.
class _PlaysChart extends StatelessWidget {
  const _PlaysChart({required this.entries});

  final List<HistoryEntry> entries;

  List<int> _dailyCounts() {
    final today = DateTime.now();
    final counts = List<int>.filled(14, 0);
    for (final entry in entries) {
      final played = entry.playedAt;
      final dayDelta =
          DateTime(today.year, today.month, today.day)
              .difference(DateTime(played.year, played.month, played.day))
              .inDays;
      if (dayDelta >= 0 && dayDelta < 14) {
        counts[13 - dayDelta]++;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _dailyCounts();
    final maxCount = counts.fold(1, math.max);
    final spec = context.prismSpec;

    return Semantics(
      label: 'Listening activity chart for the last 14 days. Today: ${counts.last} plays.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          border: Border.all(color: spec.hairline),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < counts.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (counts[i] > 0)
                              Text(
                                '${counts[i]}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Flexible(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: counts[i] == 0
                                      ? theme.colorScheme.surfaceContainerHigh
                                      : (i == counts.length - 1
                                          ? theme.colorScheme.primary
                                          : spec.accentSoft.withValues(
                                              alpha: .55 + .45 * (counts[i] / maxCount),
                                            )),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                                height: counts[i] == 0
                                    ? 4
                                    : (counts[i] / maxCount) * 64,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DefaultTextStyle(
              style: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('14 days ago'), Text('Today')],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.icon,
    required this.label,
    required this.title,
    this.meta,
  });

  final IconData icon;
  final String label;
  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(PrismRadius.md),
          border: Border.all(color: context.prismSpec.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.prismSpec.accentSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (meta != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/listening_stats.dart';
import '../../domain/repositories/library_repository.dart';
import '../blocs/library/library.dart';
import '../theme/prism_theme.dart';
import '../widgets/prism/prism_states.dart';
import 'dart:math' as math;

/// Full listening overview: headline numbers, a plays-per-day chart for the
/// last two weeks, and the current top artists / songs / genres.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<HistoryEntry> _entries = const [];
  bool _loadingHistory = true;

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Listening stats')),
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _HeadlineStats(stats: stats),
              const SizedBox(height: 24),
              if (!_loadingHistory) ...[
                Text(
                  'Last 14 days',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _PlaysChart(entries: _entries),
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
              if (stats.firstPlayed != null) ...[
                const SizedBox(height: 18),
                Text(
                  'Listening since '
                  '${_formatDate(stats.firstPlayed!)} · last play '
                  '${_formatDate(stats.lastPlayed ?? stats.firstPlayed!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _HeadlineStats extends StatelessWidget {
  const _HeadlineStats({required this.stats});

  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final hours = stats.totalListeningTime.inHours;
    final minutes = stats.totalListeningTime.inMinutes % 60;
    final listeningTime = hours > 0 ? '$hours hr $minutes min' : '$minutes min';

    return Row(
      children: [
        _StatTile(value: '${stats.totalPlays}', label: 'Plays'),
        const SizedBox(width: 12),
        _StatTile(value: '${stats.uniqueSongs}', label: 'Unique songs'),
        const SizedBox(width: 12),
        _StatTile(value: listeningTime, label: 'Listening time'),
      ],
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

    return Container(
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
              Text(
                meta!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

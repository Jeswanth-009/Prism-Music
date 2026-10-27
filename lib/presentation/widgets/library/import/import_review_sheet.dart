import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/entities.dart';
import '../../../blocs/library/library_bloc.dart';
import '../../../blocs/library/library_event.dart';
import '../../../pages/playlist_detail_page.dart';
import '../../prism/prism_artwork.dart';
import '../../prism/prism_sheet.dart';
import 'manual_track_match_dialog.dart';

/// Interactive review sheet displaying outcome of external playlist import,
/// match percentages, unmatched track lists with manual reconciliation, and clipboard export.
@visibleForTesting
class ImportReviewSheet extends StatefulWidget {
  final ImportPlaylistResult result;

  const ImportReviewSheet({super.key, required this.result});

  @override
  State<ImportReviewSheet> createState() => ImportReviewSheetState();
}

@visibleForTesting
class ImportReviewSheetState extends State<ImportReviewSheet> {
  late Playlist _playlist;
  late List<Song> _matchedTracks;
  late List<Song> _unmatchedTracks;
  late List<ImportPreviewItem> _previewItems;
  int _selectedFilterIndex = 0; // 0: All, 1: Uncertain, 2: Unmatched

  @override
  void initState() {
    super.initState();
    _playlist = widget.result.playlist;
    _matchedTracks = List.from(widget.result.matchedTracks);
    _unmatchedTracks = List.from(widget.result.unmatchedTracks);
    _previewItems = List.from(widget.result.effectivePreviewItems);
  }

  int get _total => _matchedTracks.length + _unmatchedTracks.length;
  int get _matchPercent =>
      _total == 0 ? 100 : ((_matchedTracks.length / _total) * 100).round();
  double get _matchRate =>
      _total == 0 ? 1.0 : (_matchedTracks.length / _total).clamp(0.0, 1.0);

  int get _uncertainCount => _previewItems
      .where((i) => i.confidenceLevel == ImportConfidenceLevel.uncertain)
      .length;

  List<ImportPreviewItem> get _displayedItems {
    switch (_selectedFilterIndex) {
      case 1:
        return _previewItems
            .where((i) => i.confidenceLevel == ImportConfidenceLevel.uncertain)
            .toList();
      case 2:
        return _previewItems
            .where((i) => i.confidenceLevel == ImportConfidenceLevel.unmatched)
            .toList();
      case 0:
      default:
        return _previewItems
            .where((i) => i.confidenceLevel != ImportConfidenceLevel.unmatched)
            .toList();
    }
  }

  Future<void> _matchTrackManually(Song unmatched) async {
    final matchedSong = await showDialog<Song>(
      context: context,
      builder: (ctx) => ManualTrackMatchDialog(unmatchedTrack: unmatched),
    );

    if (matchedSong != null && mounted) {
      context.read<LibraryBloc>().add(
            AddToPlaylistEvent(
              playlistId: _playlist.id,
              song: matchedSong,
            ),
          );

      setState(() {
        _unmatchedTracks.removeWhere(
            (t) => t.id == unmatched.id && t.title == unmatched.title);
        _matchedTracks.add(matchedSong);
        _playlist = _playlist.copyWith(
          trackCount: _matchedTracks.length,
          songs: _matchedTracks,
        );
        final idx = _previewItems.indexWhere(
          (t) =>
              t.sourceTrack.id == unmatched.id &&
              t.sourceTrack.title == unmatched.title,
        );
        if (idx != -1) {
          _previewItems[idx] = _previewItems[idx].copyWith(
            matchedSong: matchedSong,
            confidenceScore: 1.0,
            confidenceLevel: ImportConfidenceLevel.exact,
          );
        } else {
          _previewItems.add(
            ImportPreviewItem.fromMatch(
              sourceTrack: unmatched,
              matchedSong: matchedSong,
              confidence: 1.0,
            ),
          );
        }
      });

      showPrismToast(
        context,
        'Matched "${unmatched.title}" with "${matchedSong.title}"',
      );
    }
  }

  Future<void> _correctMatch(ImportPreviewItem item) async {
    final correctedSong = await showDialog<Song>(
      context: context,
      builder: (ctx) => ManualTrackMatchDialog(unmatchedTrack: item.sourceTrack),
    );

    if (correctedSong != null && mounted) {
      context.read<LibraryBloc>().add(
            AddToPlaylistEvent(
              playlistId: _playlist.id,
              song: correctedSong,
            ),
          );

      setState(() {
        if (item.matchedSong != null) {
          final oldIdx =
              _matchedTracks.indexWhere((s) => s.id == item.matchedSong!.id);
          if (oldIdx != -1) {
            _matchedTracks[oldIdx] = correctedSong;
          } else {
            _matchedTracks.add(correctedSong);
          }
        } else {
          _unmatchedTracks.removeWhere((s) => s.id == item.sourceTrack.id);
          _matchedTracks.add(correctedSong);
        }

        _playlist = _playlist.copyWith(
          trackCount: _matchedTracks.length,
          songs: _matchedTracks,
        );

        final idx = _previewItems.indexOf(item);
        if (idx != -1) {
          _previewItems[idx] = item.copyWith(
            matchedSong: correctedSong,
            confidenceScore: 1.0,
            confidenceLevel: ImportConfidenceLevel.exact,
          );
        }
      });

      showPrismToast(
        context,
        'Matched "${item.sourceTrack.title}" with "${correctedSong.title}"',
      );
    }
  }

  Widget _buildConfidenceBadge(ImportConfidenceLevel level, int percent) {
    final Color badgeColor;
    final IconData icon;
    final String label;

    switch (level) {
      case ImportConfidenceLevel.exact:
        badgeColor = Colors.green;
        icon = Icons.verified_rounded;
        label = 'Exact ($percent%)';
        break;
      case ImportConfidenceLevel.high:
        badgeColor = Colors.teal;
        icon = Icons.check_circle_outline_rounded;
        label = 'High ($percent%)';
        break;
      case ImportConfidenceLevel.uncertain:
        badgeColor = Colors.amber;
        icon = Icons.help_outline_rounded;
        label = 'Uncertain ($percent%)';
        break;
      case ImportConfidenceLevel.unmatched:
        badgeColor = Colors.redAccent;
        icon = Icons.cancel_outlined;
        label = 'No Match';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                PrismArtwork(
                  url: _playlist.thumbnails?.best ?? '',
                  width: 54,
                  height: 54,
                  borderRadius: 8,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _playlist.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_matchedTracks.length} of $_total tracks matched ($_matchPercent%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _matchPercent >= 80
                              ? Colors.green
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _matchRate,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _matchPercent >= 80
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Filter segmented chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${_previewItems.length})'),
                    selected: _selectedFilterIndex == 0,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilterIndex = 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Uncertain ($_uncertainCount)'),
                    selected: _selectedFilterIndex == 1,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilterIndex = 1);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Unmatched (${_unmatchedTracks.length})'),
                    selected: _selectedFilterIndex == 2,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilterIndex = 2);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (widget.result.isEmbedFallback)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Embed scraper was used (first 100 tracks). Add Spotify Developer keys in Settings for uncapped imports.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.result.wasCancelled)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Import was stopped early. ${_matchedTracks.length} tracks were saved.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedFilterIndex == 2 ||
                (_selectedFilterIndex == 0 && _unmatchedTracks.isNotEmpty)) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unmatched Tracks (${_unmatchedTracks.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final missed = _unmatchedTracks
                          .map((t) => '${t.artist} - ${t.title}')
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: missed));
                      showPrismToast(
                          context, 'Missed tracks copied to clipboard');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy List'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._unmatchedTracks.map((track) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        leading: const Icon(
                          Icons.music_off_outlined,
                          size: 18,
                        ),
                        title: Text(
                          track.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${track.artist} • ${Formatters.formatDuration(track.duration)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Match'),
                          onPressed: () => _matchTrackManually(track),
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (_selectedFilterIndex != 2 && _displayedItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _selectedFilterIndex == 1
                      ? 'Uncertain Matches (${_displayedItems.length})'
                      : 'Matched Tracks (${_displayedItems.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ..._displayedItems.map((item) {
                final source = item.sourceTrack;
                final matched = item.matchedSong;
                final isUncertain =
                    item.confidenceLevel == ImportConfidenceLevel.uncertain;
                final isUnmatched =
                    item.confidenceLevel == ImportConfidenceLevel.unmatched;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: isUncertain
                        ? Colors.amber.withValues(alpha: 0.08)
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      leading: Icon(
                        isUnmatched
                            ? Icons.music_off_outlined
                            : Icons.music_note_rounded,
                        size: 20,
                        color: isUncertain
                            ? Colors.amber
                            : theme.colorScheme.primary,
                      ),
                      title: Text(
                        source.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${source.artist} • ${Formatters.formatDuration(source.duration)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (matched != null &&
                              (matched.title != source.title ||
                                  matched.artist != source.artist))
                            Text(
                              'Matched candidate: ${matched.title} - ${matched.artist}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isUncertain
                                    ? Colors.amber.shade700
                                    : theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          _buildConfidenceBadge(
                            item.confidenceLevel,
                            item.confidencePercent,
                          ),
                        ],
                      ),
                      trailing: isUncertain || isUnmatched
                          ? FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon:
                                  const Icon(Icons.edit_note_rounded, size: 16),
                              label: Text(isUnmatched ? 'Match' : 'Correct'),
                              onPressed: () => _correctMatch(item),
                            )
                          : null,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (_unmatchedTracks.isEmpty &&
                widget.result.unmatchedTracks.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'All unmatched tracks successfully reconciled!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailPage(
                            playlist: _playlist,
                          ),
                        ),
                      );
                    },
                    child: const Text('View Playlist'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

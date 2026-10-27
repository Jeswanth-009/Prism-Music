import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/song.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../prism/prism_artwork.dart';

/// Dialog for manually searching YouTube Music and reconciling an unmatched track.
class ManualTrackMatchDialog extends StatefulWidget {
  final Song unmatchedTrack;

  const ManualTrackMatchDialog({super.key, required this.unmatchedTrack});

  @override
  State<ManualTrackMatchDialog> createState() => _ManualTrackMatchDialogState();
}

class _ManualTrackMatchDialogState extends State<ManualTrackMatchDialog> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  List<Song> _results = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${widget.unmatchedTrack.title} ${widget.unmatchedTrack.artist}',
    );
    _performSearch(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!getIt.isRegistered<MusicRepository>()) {
        setState(() {
          _isLoading = false;
          _results = const [];
        });
        return;
      }

      final repo = getIt<MusicRepository>();
      final result = await repo.searchSongs(trimmed);
      if (!mounted) return;

      result.fold(
        (failure) => setState(() {
          _isLoading = false;
          _error = failure.message;
          _results = const [];
        }),
        (songs) => setState(() {
          _isLoading = false;
          _results = songs;
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _results = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reconcile Track',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.music_off_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.unmatchedTrack.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.unmatchedTrack.artist} • ${Formatters.formatDuration(widget.unmatchedTrack.duration)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _performSearch,
                decoration: InputDecoration(
                  hintText: 'Search YouTube Music',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    onPressed: () => _performSearch(_controller.text),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching tracks found.\nTry a different search query.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _results.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final song = _results[index];
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                    leading: PrismArtwork(
                                      url: song.thumbnailUrl,
                                      width: 42,
                                      height: 42,
                                      borderRadius: 6,
                                    ),
                                    title: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${song.artist} • ${Formatters.formatDuration(song.duration)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    trailing: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Colors.green,
                                      size: 22,
                                    ),
                                    onTap: () => Navigator.pop(context, song),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/utils/lyrics_matching.dart';
import '../../../data/datasources/remote/lyrics/custom_lyrics_storage.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/repositories/music_repository.dart';
import '../prism/prism_sheet.dart';

/// Modal sheet allowing users to manually correct mismatched lyrics locally,
/// edit raw plain or LRC lines, or re-search with adjusted song/artist metadata.
class LyricsEditSheet extends StatefulWidget {
  const LyricsEditSheet({
    super.key,
    required this.song,
    this.currentLyrics,
    this.onLyricsUpdated,
  });

  final Song song;
  final Lyrics? currentLyrics;
  final void Function(Lyrics? newLyrics)? onLyricsUpdated;

  static Future<void> show(
    BuildContext context, {
    required Song song,
    Lyrics? currentLyrics,
    void Function(Lyrics? newLyrics)? onLyricsUpdated,
  }) {
    return showPrismSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LyricsEditSheet(
        song: song,
        currentLyrics: currentLyrics,
        onLyricsUpdated: onLyricsUpdated,
      ),
    );
  }

  @override
  State<LyricsEditSheet> createState() => _LyricsEditSheetState();
}

class _LyricsEditSheetState extends State<LyricsEditSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _textController;
  late TextEditingController _titleQueryController;
  late TextEditingController _artistQueryController;

  bool _isLrcMode = false;
  bool _isSearching = false;
  bool _isSaving = false;
  bool _hasCustomLyrics = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _isLrcMode = widget.currentLyrics?.isSynced ?? false;
    _textController = TextEditingController(text: _formatInitialLyrics());
    _titleQueryController = TextEditingController(text: widget.song.title);
    _artistQueryController = TextEditingController(text: widget.song.artist);

    _checkExistingCustomLyrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _titleQueryController.dispose();
    _artistQueryController.dispose();
    super.dispose();
  }

  String _formatInitialLyrics() {
    final lyrics = widget.currentLyrics;
    if (lyrics == null) return '';

    if (lyrics.isSynced) {
      final buffer = StringBuffer();
      for (final line in lyrics.syncedLyrics!) {
        final totalSeconds = (line.startTimeMs / 1000).floor();
        final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
        final hundredths = ((line.startTimeMs % 1000) ~/ 10).toString().padLeft(2, '0');
        buffer.writeln('[$minutes:$seconds.$hundredths]${line.text}');
      }
      return buffer.toString().trim();
    }

    return lyrics.plainLyrics?.trim() ?? '';
  }

  Future<void> _checkExistingCustomLyrics() async {
    final hasCustom = await CustomLyricsStorage.instance.hasCustomLyrics(
      widget.song.id,
      widget.song.title,
      widget.song.artist,
    );
    if (mounted) setState(() => _hasCustomLyrics = hasCustom);
  }

  Future<void> _searchRemoteLyrics() async {
    final qTitle = _titleQueryController.text.trim();
    final qArtist = _artistQueryController.text.trim();
    if (qTitle.isEmpty) return;

    setState(() {
      _isSearching = true;
      _statusMessage = null;
    });

    try {
      final musicRepo = getIt<MusicRepository>();
      final result = await musicRepo.getLyrics(
        qTitle,
        qArtist,
        duration: widget.song.duration.inSeconds >= 30 ? widget.song.duration : null,
        forceRefresh: true,
      );

      if (!mounted) return;
      result.fold(
        (failure) {
          setState(() {
            _isSearching = false;
            _statusMessage = 'No lyrics found for "$qTitle" by "$qArtist"';
          });
        },
        (lyrics) {
          setState(() {
            _isSearching = false;
            _isLrcMode = lyrics.isSynced;
            if (lyrics.isSynced) {
              final buffer = StringBuffer();
              for (final line in lyrics.syncedLyrics!) {
                final totalSeconds = (line.startTimeMs / 1000).floor();
                final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
                final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
                final hundredths = ((line.startTimeMs % 1000) ~/ 10).toString().padLeft(2, '0');
                buffer.writeln('[$minutes:$seconds.$hundredths]${line.text}');
              }
              _textController.text = buffer.toString().trim();
            } else {
              _textController.text = lyrics.plainLyrics?.trim() ?? '';
            }
            _tabController.animateTo(0);
            _statusMessage = 'Matched lyrics loaded from provider! Tap "Save" to keep locally.';
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'Search failed: $e';
        });
      }
    }
  }

  Future<void> _saveCustomLyrics() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      String? plainLyrics;
      String? syncedLrc;
      List<LyricLine>? syncedLines;

      if (_isLrcMode || text.contains(RegExp(r'\[\d{1,2}:\d{2}'))) {
        syncedLrc = text;
        syncedLines = parseLrc(text);
        plainLyrics = syncedLines.map((l) => l.text).join('\n');
      } else {
        plainLyrics = text;
      }

      await CustomLyricsStorage.instance.saveCustomLyrics(
        widget.song.id,
        widget.song.title,
        widget.song.artist,
        plainLyrics: plainLyrics,
        syncedLrc: syncedLrc,
      );

      final updated = Lyrics(
        songId: widget.song.id,
        plainLyrics: plainLyrics,
        syncedLyrics: syncedLines != null && syncedLines.isNotEmpty ? syncedLines : null,
        source: 'User Edited',
      );

      widget.onLyricsUpdated?.call(updated);

      if (mounted) {
        Navigator.of(context).pop();
        showPrismToast(context, 'Custom lyrics saved locally');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Failed to save: $e';
        });
      }
    }
  }

  Future<void> _resetToOriginal() async {
    setState(() => _isSaving = true);
    try {
      await CustomLyricsStorage.instance.clearCustomLyrics(
        widget.song.id,
        widget.song.title,
        widget.song.artist,
      );

      final musicRepo = getIt<MusicRepository>();
      final result = await musicRepo.getLyrics(
        widget.song.title,
        widget.song.artist,
        duration: widget.song.duration.inSeconds >= 30 ? widget.song.duration : null,
        forceRefresh: true,
      );

      Lyrics? originalLyrics;
      result.fold((_) => null, (lyrics) => originalLyrics = lyrics);

      widget.onLyricsUpdated?.call(originalLyrics);

      if (mounted) {
        Navigator.of(context).pop();
        showPrismToast(context, 'Reset to provider lyrics');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Failed to reset: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Lyrics / Correct Mismatch',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${widget.song.title} • ${widget.song.artist}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_hasCustomLyrics)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Custom',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual Editor'),
                  Tab(icon: Icon(Icons.search_rounded), text: 'Search Match'),
                ],
              ),
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    _statusMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Manual Text / LRC Editor
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isLrcMode ? 'LRC Format ([mm:ss.xx] text)' : 'Plain Text Format',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Row(
                                children: [
                                  Text('LRC Synced', style: theme.textTheme.labelSmall),
                                  Switch(
                                    value: _isLrcMode,
                                    onChanged: (val) => setState(() => _isLrcMode = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                hintText: _isLrcMode
                                    ? '[00:15.20] First line of lyrics\n[00:20.50] Second line of lyrics'
                                    : 'Paste or type plain lyrics line by line…',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tab 2: Custom Search Match
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'If the wrong lyrics were matched, edit the search query below and fetch candidates from LRCLIB:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _titleQueryController,
                            decoration: const InputDecoration(
                              labelText: 'Track Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _artistQueryController,
                            decoration: const InputDecoration(
                              labelText: 'Artist Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSearching ? null : _searchRemoteLyrics,
                              icon: _isSearching
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.search_rounded),
                              label: Text(_isSearching ? 'Searching…' : 'Fetch New Match'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    if (_hasCustomLyrics) ...[
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _resetToOriginal,
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveCustomLyrics,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving ? 'Saving…' : 'Save Locally'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

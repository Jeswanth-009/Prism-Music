import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/playlist_collaboration_service.dart';
import '../../../../data/datasources/local/local_datasource.dart';
import '../../../../domain/entities/playlist.dart';
import '../../../blocs/library/library_bloc.dart';
import '../../../blocs/library/library_event.dart';
import '../../prism/prism_sheet.dart';

/// Modal sheet for importing peer-to-peer playlists from links, QR codes, or text payloads.
class P2PPlaylistImportSheet extends StatefulWidget {
  const P2PPlaylistImportSheet({super.key, this.initialData});

  final String? initialData;

  static Future<void> show(BuildContext context, {String? initialData}) {
    return showPrismSheet<void>(
      context: context,
      builder: (_) => P2PPlaylistImportSheet(initialData: initialData),
    );
  }

  @override
  State<P2PPlaylistImportSheet> createState() => _P2PPlaylistImportSheetState();
}

class _P2PPlaylistImportSheetState extends State<P2PPlaylistImportSheet> {
  final _controller = TextEditingController();
  Playlist? _previewPlaylist;
  bool _isImporting = false;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _controller.text = widget.initialData!;
      _tryParse(widget.initialData!);
    } else {
      _checkClipboard();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && (text.startsWith('prism://playlist') || text.contains('playlist#data='))) {
        _controller.text = text;
        _tryParse(text);
      }
    } catch (_) {}
  }

  void _tryParse(String input) {
    setState(() {
      _parseError = null;
      _previewPlaylist = null;
    });

    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final decoded = PlaylistCollaborationService.instance.decodePlaylistPayload(trimmed);
    if (decoded != null) {
      setState(() {
        _previewPlaylist = decoded;
      });
    } else {
      setState(() {
        _parseError = 'Invalid or unrecognized Prism playlist link/code';
      });
    }
  }

  Future<void> _savePlaylist() async {
    final playlist = _previewPlaylist;
    if (playlist == null) return;

    setState(() => _isImporting = true);
    try {
      final localDataSource = getIt<LocalDataSource>();
      await localDataSource.saveImportedPlaylist(playlist);

      if (mounted) {
        context.read<LibraryBloc>().add(const LoadLibraryEvent());
        Navigator.of(context).pop();
        showPrismToast(context, 'Imported "${playlist.name}" (${playlist.songs?.length ?? 0} tracks)');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _parseError = 'Failed to save playlist: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlist = _previewPlaylist;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Import P2P Playlist',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Paste a peer-to-peer playlist link or scan code to import',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'prism://playlist?data=... or paste share link',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_rounded),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _controller.text = data!.text!.trim();
                        _tryParse(_controller.text);
                      }
                    },
                  ),
                  errorText: _parseError,
                ),
                onChanged: _tryParse,
              ),
              if (playlist != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.playlist_play_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              playlist.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${playlist.songs?.length ?? 0} tracks',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlist.songs?.length ?? 0,
                          itemBuilder: (context, index) {
                            final song = playlist.songs![index];
                            final min = song.duration.inMinutes;
                            final sec = (song.duration.inSeconds % 60).toString().padLeft(2, '0');
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '${index + 1}.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${song.title} • ${song.artist}',
                                      style: theme.textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$min:$sec',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _savePlaylist,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_done_rounded),
                    label: Text(_isImporting ? 'Importing…' : 'Add to My Playlists'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

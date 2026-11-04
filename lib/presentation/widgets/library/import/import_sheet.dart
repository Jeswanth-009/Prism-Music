import 'package:flutter/material.dart';

import '../../../../core/utils/link_validation.dart';
import 'p2p_playlist_import_sheet.dart';

/// Playlist import sources.
enum PlaylistImportSource { spotify, youtube, appleMusic }

/// Source picker + URL entry for playlist import. Pops with the chosen
/// source and url, or null when cancelled.
class LibraryImportSheet extends StatefulWidget {
  const LibraryImportSheet({super.key});

  @override
  State<LibraryImportSheet> createState() => _LibraryImportSheetState();
}

class _LibraryImportSheetState extends State<LibraryImportSheet> {
  PlaylistImportSource _source = PlaylistImportSource.spotify;
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String get _hint => switch (_source) {
        PlaylistImportSource.spotify => 'https://open.spotify.com/playlist/…',
        PlaylistImportSource.youtube =>
          'https://music.youtube.com/playlist?list=… or playlist ID (also mixes)',
        PlaylistImportSource.appleMusic =>
          'https://music.apple.com/…/playlist/…',
      };

  bool get _isValidUrl {
    final text = _urlController.text.trim();
    if (text.length < 10) return false;
    final uri = Uri.tryParse(text);
    if (uri == null) return false;

    return switch (_source) {
      PlaylistImportSource.spotify => uri.scheme == 'spotify' ||
          (uri.isScheme('https') &&
              (isSpotifyPlaylistHost(uri.host) ||
                  isSpotifyShortLinkHost(uri.host))),
      PlaylistImportSource.youtube =>
        uri.isScheme('https') && isYouTubePlaylistHost(uri.host),
      PlaylistImportSource.appleMusic =>
        uri.isScheme('https') && isAppleMusicPlaylistHost(uri.host),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import playlist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PlaylistImportSource>(
              segments: const [
                ButtonSegment(
                  value: PlaylistImportSource.spotify,
                  icon: Icon(Icons.graphic_eq_rounded),
                  label: Text('Spotify'),
                ),
                ButtonSegment(
                  value: PlaylistImportSource.youtube,
                  icon: Icon(Icons.play_circle_outline_rounded),
                  label: Text('YouTube'),
                ),
                ButtonSegment(
                  value: PlaylistImportSource.appleMusic,
                  icon: Icon(Icons.music_note_rounded),
                  label: Text('Apple'),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (selection) =>
                  setState(() => _source = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                if (_isValidUrl) {
                  Navigator.of(context)
                      .pop((source: _source, url: value.trim()));
                }
              },
              decoration: InputDecoration(
                hintText: _hint,
                border: const OutlineInputBorder(),
                errorText: _urlController.text.isNotEmpty && !_isValidUrl
                    ? 'That does not look like a ${_source == PlaylistImportSource.appleMusic ? "Apple Music" : _source.name} playlist link'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isValidUrl
                      ? () => Navigator.of(context)
                          .pop((source: _source, url: _urlController.text.trim()))
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Import'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  P2PPlaylistImportSheet.show(context);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Import via P2P Link / QR Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

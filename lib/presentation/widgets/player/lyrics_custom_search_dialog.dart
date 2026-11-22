import 'package:flutter/material.dart';
import '../../theme/prism_theme.dart';

/// Modal dialog allowing the user to search lyrics using alternative track metadata.
class LyricsCustomSearchDialog extends StatefulWidget {
  final String initialTitle;
  final String initialArtist;
  final void Function(String title, String artist) onSearch;

  const LyricsCustomSearchDialog({
    super.key,
    required this.initialTitle,
    required this.initialArtist,
    required this.onSearch,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialTitle,
    required String initialArtist,
    required void Function(String title, String artist) onSearch,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => LyricsCustomSearchDialog(
        initialTitle: initialTitle,
        initialArtist: initialArtist,
        onSearch: onSearch,
      ),
    );
  }

  @override
  State<LyricsCustomSearchDialog> createState() => _LyricsCustomSearchDialogState();
}

class _LyricsCustomSearchDialogState extends State<LyricsCustomSearchDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _artistController = TextEditingController(text: widget.initialArtist);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      title: Text(
        'Search with another title',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter alternative song title or artist if the automatic lookup missed lyrics.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Song Title',
                prefixIcon: const Icon(Icons.music_note_rounded, size: 20),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistController,
              decoration: InputDecoration(
                labelText: 'Artist',
                prefixIcon: const Icon(Icons.person_rounded, size: 20),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final t = _titleController.text.trim();
            final a = _artistController.text.trim();
            if (t.isNotEmpty) {
              Navigator.of(context).pop();
              widget.onSearch(t, a);
            }
          },
          child: const Text('Search'),
        ),
      ],
    );
  }
}

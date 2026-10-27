import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/cancellation_token.dart';
import '../../../blocs/library/library_bloc.dart';
import '../../../blocs/library/library_event.dart';
import '../../../blocs/library/library_state.dart';

/// Modal dialog showing active playlist import progress with cooperative cancel button.
@visibleForTesting
class ImportProgressDialog extends StatelessWidget {
  final ImportCancellationToken cancelToken;
  final VoidCallback onDismiss;

  const ImportProgressDialog({
    super.key,
    required this.cancelToken,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<LibraryBloc, LibraryState>(
      listener: (context, state) {
        if (state.status != LibraryStatus.importing) {
          onDismiss();
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      },
      builder: (context, state) {
        final progress = state.importProgress;
        final current = state.importCurrentTrack ?? 0;
        final total = state.importTotalTracks ?? 0;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_rounded),
              SizedBox(width: 12),
              Flexible(child: Text('Importing Playlist')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (progress != null && total > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress),
                ),
                const SizedBox(height: 12),
                Text(
                  'Matching track $current of $total...',
                  style: theme.textTheme.bodyMedium,
                ),
              ] else ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Reading playlist metadata...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel Import'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () {
                cancelToken.cancel();
                context.read<LibraryBloc>().add(const CancelImportEvent());
                onDismiss();
                Navigator.of(context, rootNavigator: true).maybePop();
              },
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/audio_player_service.dart';
import '../../../core/services/media_resolver_service.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/stream_info.dart';
import '../../blocs/library/library_bloc.dart';
import '../../blocs/library/library_event.dart' hide DownloadSongEvent;
import '../../blocs/library/library_state.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/player/player_event.dart';
import '../../blocs/player/player_state.dart';
import '../../theme/prism_theme.dart';
import '../equalizer/equalizer_bottom_sheet.dart';
import '../prism/prism_sheet.dart';
import '../prism/prism_song_actions.dart';
import 'provider_health_sheet.dart';

/// Opens the equalizer modal sheet.
void showPlayerEqualizerSheet(BuildContext context) {
  final audioPlayerService = getIt<AudioPlayerService>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        EqualizerBottomSheet(equalizerService: audioPlayerService.equalizer),
  );
}

/// Opens the full options sheet for the currently playing song.
void showPlayerOptionsMenu(BuildContext context, Song song) {
  showPrismSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          PrismSheetAction(
            icon: Icons.playlist_add_rounded,
            label: 'Add to queue',
            onTap: () {
              Navigator.pop(sheetContext);
              context.read<PlayerBloc>().add(AddToQueueEvent(song: song));
              showPrismToast(context, 'Added to queue');
            },
          ),
          PrismSheetAction(
            icon: Icons.playlist_add_rounded,
            label: 'Add to playlist',
            onTap: () {
              Navigator.pop(sheetContext);
              showPrismPlaylistPicker(context, song);
            },
          ),
          BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, libraryState) => PrismSheetAction(
              icon: libraryState.isSongLiked(song.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              label: libraryState.isSongLiked(song.id)
                  ? 'Remove from liked'
                  : 'Add to liked songs',
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<LibraryBloc>().add(ToggleLikeSongEvent(song));
              },
            ),
          ),
          PrismSheetAction(
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: () {
              Navigator.pop(sheetContext);
              context.read<PlayerBloc>().add(DownloadSongEvent(song));
              showPrismToast(context, 'Downloading "${song.title}"…');
            },
          ),
          PrismSheetAction(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () {
              Navigator.pop(sheetContext);
              ShareSong.shareSong(song);
            },
          ),
          BlocBuilder<PlayerBloc, PlayerState>(
            builder: (context, playerState) {
              final end = playerState.sleepTimerEnd;
              final remaining = end?.difference(DateTime.now());
              Widget? trailingWidget;
              if (playerState.sleepTimerEndOfTrack) {
                trailingWidget = Text(
                  'End of track',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                );
              } else if (remaining != null && !remaining.isNegative) {
                trailingWidget = Text(
                  '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                );
              }

              return PrismSheetAction(
                icon: Icons.bedtime_rounded,
                label: 'Sleep timer',
                trailing: trailingWidget,
                onTap: () {
                  Navigator.pop(sheetContext);
                  showPlayerSleepTimerSheet(context, playerState);
                },
              );
            },
          ),
          PrismSheetAction(
            icon: Icons.health_and_safety_rounded,
            label: 'Provider health & audio sources',
            onTap: () {
              Navigator.pop(sheetContext);
              showProviderHealthSheet(context);
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

/// Off / end-of-track / fixed durations. Dispatches [SetSleepTimerEvent].
void showPlayerSleepTimerSheet(BuildContext context, PlayerState state) {
  final options = <({String label, Duration? duration, bool endOfTrack})>[
    const (label: 'Off', duration: null, endOfTrack: false),
    const (label: 'End of track', duration: null, endOfTrack: true),
    ...const [5, 10, 15, 30, 45, 60, 90].map(
      (minutes) => (
        label: '$minutes minutes',
        duration: Duration(minutes: minutes),
        endOfTrack: false,
      ),
    ),
  ];

  showPrismSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sleep timer',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          for (final option in options)
            ListTile(
              leading: const Icon(Icons.bedtime_rounded),
              title: Text(option.label),
              trailing: (option.endOfTrack && state.sleepTimerEndOfTrack) ||
                      (!option.endOfTrack &&
                          option.duration == null &&
                          !state.sleepTimerEndOfTrack &&
                          state.sleepTimerEnd == null)
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<PlayerBloc>().add(
                      SetSleepTimerEvent(
                        option.duration,
                        endOfTrack: option.endOfTrack,
                      ),
                    );
                if (option.duration != null || option.endOfTrack) {
                  showPrismToast(context, 'Sleep timer set: ${option.label}');
                } else {
                  showPrismToast(context, 'Sleep timer cancelled');
                }
              },
            ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

/// Audio stream diagnostics sheet with provenance source, bitrate, codec,
/// and live resolver reload/switch actions.
void showPlayerStreamDetailsSheet(
  BuildContext context,
  Song song,
  StreamInfo? streamInfo,
) {
  showPrismSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: Theme.of(sheetContext).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Stream Diagnostics',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    Theme.of(sheetContext).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                border: Border.all(
                  color: Theme.of(sheetContext)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _diagnosticRow(
                    sheetContext,
                    'Resolution Source',
                    formatAudioProvenance(streamInfo?.streamProvenance, song),
                  ),
                  const Divider(height: 16),
                  _diagnosticRow(
                    sheetContext,
                    'Audio Codec',
                    streamInfo?.codec.toUpperCase() ?? 'Direct Media',
                  ),
                  const Divider(height: 16),
                  _diagnosticRow(
                    sheetContext,
                    'Nominal Bitrate',
                    streamInfo != null && streamInfo.bitrate > 0
                        ? '${streamInfo.bitrate} kbps'
                        : 'Standard',
                  ),
                  const Divider(height: 16),
                  _diagnosticRow(
                    sheetContext,
                    'Container Format',
                    streamInfo?.container != null &&
                            streamInfo!.container.isNotEmpty
                        ? '.${streamInfo.container}'
                        : 'Stream (HTTP Live)',
                  ),
                  if (streamInfo?.matchConfidence != null) ...[
                    const Divider(height: 16),
                    _diagnosticRow(
                      sheetContext,
                      'Match Confidence',
                      '${(streamInfo!.matchConfidence! * 100).round()}% Verified',
                      trailingIcon: Icons.verified_rounded,
                      trailingColor:
                          Theme.of(sheetContext).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            if (song.source != MusicSource.local) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    streamInfo?.streamProvenance == 'jiosaavn_matched'
                        ? Icons.play_circle_fill_rounded
                        : Icons.graphic_eq_rounded,
                    size: 17,
                  ),
                  label: Text(
                    streamInfo?.streamProvenance == 'jiosaavn_matched'
                        ? 'Switch to YouTube Audio'
                        : 'Try JioSaavn Match',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    final playerBloc = context.read<PlayerBloc>();
                    final state = playerBloc.state;
                    final targetResolver =
                        streamInfo?.streamProvenance == 'jiosaavn_matched'
                            ? 'youtube_explode'
                            : 'jiosaavn';
                    playerBloc.add(
                      PlaySongEvent(
                        song: song,
                        queue: state.queue,
                        queueIndex: state.queueIndex,
                        userInitiated: true,
                        preferredResolver: targetResolver,
                      ),
                    );
                    showPrismToast(
                      context,
                      targetResolver == 'youtube_explode'
                          ? 'Switching to YouTube Audio...'
                          : 'Attempting JioSaavn match...',
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.health_and_safety_rounded, size: 17),
                  label: const Text('Provider Health & Safe Switch'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showProviderHealthSheet(context);
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reload Fresh Stream'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  final mediaResolver = getIt<MediaResolverService>();
                  mediaResolver.invalidate(song.playableId);
                  final playerBloc = context.read<PlayerBloc>();
                  final state = playerBloc.state;
                  playerBloc.add(
                    PlaySongEvent(
                      song: song,
                      queue: state.queue,
                      queueIndex: state.queueIndex,
                      userInitiated: true,
                    ),
                  );
                  showPrismToast(context, 'Re-resolving fresh audio stream...');
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Formats provenance code into human-readable label.
String formatAudioProvenance(String? provenance, Song song) {
  if (song.source == MusicSource.local) return 'Local Offline Storage';
  switch (provenance) {
    case 'jiosaavn_matched':
      return 'JioSaavn High-Fidelity Match';
    case 'youtube_explode':
      return 'YouTube Explode Audio-Only';
    case 'piped_proxy':
      return 'Piped Private Proxy';
    case 'invidious_instance':
      return 'Invidious Community Node';
    default:
      return 'Direct Stream Provider';
  }
}

Widget _diagnosticRow(
  BuildContext context,
  String label,
  String value, {
  IconData? trailingIcon,
  Color? trailingColor,
}) {
  final theme = Theme.of(context);
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (trailingIcon != null) ...[
              Icon(trailingIcon, size: 14, color: trailingColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

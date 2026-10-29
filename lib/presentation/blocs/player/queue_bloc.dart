import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/queue_persistence_service.dart';
import '../../../core/services/recommendation_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import 'player_event.dart';

/// Represents queue state in isolation.
class QueueState extends Equatable {
  final List<Song> queue;
  final List<Song> originalQueue;
  final int queueIndex;
  final bool isShuffleEnabled;
  final RepeatMode repeatMode;
  final bool autoPlay;
  final bool isRestoredSession;

  const QueueState({
    this.queue = const [],
    this.originalQueue = const [],
    this.queueIndex = 0,
    this.isShuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.autoPlay = true,
    this.isRestoredSession = false,
  });

  Song? get currentSong =>
      (queueIndex >= 0 && queueIndex < queue.length) ? queue[queueIndex] : null;

  bool get hasNext => queueIndex < queue.length - 1;
  bool get hasPrevious => queueIndex > 0;

  QueueState copyWith({
    List<Song>? queue,
    List<Song>? originalQueue,
    int? queueIndex,
    bool? isShuffleEnabled,
    RepeatMode? repeatMode,
    bool? autoPlay,
    bool? isRestoredSession,
  }) {
    return QueueState(
      queue: queue ?? this.queue,
      originalQueue: originalQueue ?? this.originalQueue,
      queueIndex: queueIndex ?? this.queueIndex,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      autoPlay: autoPlay ?? this.autoPlay,
      isRestoredSession: isRestoredSession ?? this.isRestoredSession,
    );
  }

  @override
  List<Object?> get props => [
        queue,
        originalQueue,
        queueIndex,
        isShuffleEnabled,
        repeatMode,
        autoPlay,
        isRestoredSession,
      ];
}

class _InternalAddRecommendationsEvent extends PlayerEvent {
  final List<Song> songs;
  const _InternalAddRecommendationsEvent(this.songs);
  @override
  List<Object?> get props => [songs];
}

/// Standalone BLoC for queue management, reordering, shuffle, repeat, and recommendations.
class QueueBloc extends Bloc<PlayerEvent, QueueState> {
  final MusicRepository _musicRepository;
  final RecommendationService? _recommendationService;
  final SettingsService _settingsService;

  int _recommendationGeneration = 0;
  bool _isFetchingRecommendations = false;
  String? _lastRecommendationSongId;

  static const int _recommendTopUpRemaining = 3;
  static const int _recommendationBatchSize = 10;

  QueueBloc({
    required MusicRepository musicRepository,
    RecommendationService? recommendationService,
    SettingsService? settingsService,
  })  : _musicRepository = musicRepository,
        _recommendationService = recommendationService,
        _settingsService = settingsService ?? SettingsService.instance,
        super(QueueState(autoPlay: (settingsService ?? SettingsService.instance).autoPlay)) {
    on<AddToQueueEvent>(_onAddToQueue);
    on<RemoveFromQueueEvent>(_onRemoveFromQueue);
    on<ReorderQueueEvent>(_onReorderQueue);
    on<ClearQueueEvent>(_onClearQueue);
    on<SetShuffleEvent>(_onSetShuffle);
    on<ToggleShuffleEvent>(_onToggleShuffle);
    on<SetRepeatModeEvent>(_onSetRepeatMode);
    on<CycleRepeatModeEvent>(_onCycleRepeatMode);
    on<ToggleAutoPlayEvent>(_onToggleAutoPlay);
    on<MarkSongNotInterestedEvent>(_onMarkSongNotInterested);
    on<RestoreQueueEvent>(_onRestoreQueue);
    on<ClearPersistedQueueEvent>(_onClearPersistedQueue);
    on<_InternalAddRecommendationsEvent>(_onAddRecommendations);
  }

  void _onAddToQueue(AddToQueueEvent event, Emitter<QueueState> emit) {
    final updatedQueue = List<Song>.from(state.queue);
    final updatedOriginal = List<Song>.from(
      state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
    );
    if (event.playNext) {
      final insertIndex = (state.queueIndex + 1).clamp(0, updatedQueue.length);
      updatedQueue.insert(insertIndex, event.song);
      updatedOriginal.add(event.song);
    } else {
      updatedQueue.add(event.song);
      updatedOriginal.add(event.song);
    }

    emit(state.copyWith(queue: updatedQueue, originalQueue: updatedOriginal));
  }

  void _onRemoveFromQueue(RemoveFromQueueEvent event, Emitter<QueueState> emit) {
    if (event.index < 0 || event.index >= state.queue.length) return;

    final removedSong = state.queue[event.index];
    final updatedQueue = List<Song>.from(state.queue)..removeAt(event.index);

    final updatedOriginal = List<Song>.from(
      state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
    );
    final origIdx = updatedOriginal.indexWhere(
      (s) => s.playableId == removedSong.playableId,
    );
    if (origIdx != -1) {
      updatedOriginal.removeAt(origIdx);
    }

    int newIndex = state.queueIndex;
    if (event.index < state.queueIndex) {
      newIndex--;
    } else if (event.index == state.queueIndex) {
      if (updatedQueue.isEmpty) {
        emit(state.copyWith(
          queue: const [],
          originalQueue: const [],
          queueIndex: 0,
        ));
        return;
      } else {
        if (newIndex >= updatedQueue.length) {
          newIndex = updatedQueue.length - 1;
        }
      }
    }

    if (updatedQueue.isNotEmpty && newIndex >= updatedQueue.length) {
      newIndex = updatedQueue.length - 1;
    }

    emit(state.copyWith(
      queue: updatedQueue,
      originalQueue: updatedOriginal,
      queueIndex: newIndex,
    ));
  }

  void _onReorderQueue(ReorderQueueEvent event, Emitter<QueueState> emit) {
    if (event.oldIndex < 0 ||
        event.oldIndex >= state.queue.length ||
        event.newIndex < 0 ||
        event.newIndex >= state.queue.length ||
        event.oldIndex == event.newIndex) {
      return;
    }

    final updatedQueue = List<Song>.from(state.queue);
    final song = updatedQueue.removeAt(event.oldIndex);
    updatedQueue.insert(event.newIndex, song);

    int newIndex = state.queueIndex;
    if (state.queueIndex == event.oldIndex) {
      newIndex = event.newIndex;
    } else if (event.oldIndex < state.queueIndex &&
        event.newIndex >= state.queueIndex) {
      newIndex--;
    } else if (event.oldIndex > state.queueIndex &&
        event.newIndex <= state.queueIndex) {
      newIndex++;
    }

    emit(state.copyWith(queue: updatedQueue, queueIndex: newIndex));
  }

  void _onClearQueue(ClearQueueEvent event, Emitter<QueueState> emit) {
    final current = state.currentSong;
    final preserved = current != null ? [current] : <Song>[];
    emit(state.copyWith(
      queue: preserved,
      originalQueue: preserved,
      queueIndex: 0,
    ));
  }

  void _onSetShuffle(SetShuffleEvent event, Emitter<QueueState> emit) {
    if (event.enabled && !state.isShuffleEnabled) {
      final current = state.currentSong;
      final currentIdx = state.queueIndex;
      final original = List<Song>.from(
        state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
      );

      final shuffled = List<Song>.from(state.queue);
      if (current != null && currentIdx >= 0 && currentIdx < shuffled.length) {
        final activeSong = shuffled.removeAt(currentIdx);
        shuffled.shuffle();
        shuffled.insert(0, activeSong);
        emit(state.copyWith(
          isShuffleEnabled: true,
          queue: shuffled,
          originalQueue: original,
          queueIndex: 0,
        ));
      } else {
        shuffled.shuffle();
        emit(state.copyWith(
          isShuffleEnabled: true,
          queue: shuffled,
          originalQueue: original,
        ));
      }
    } else if (!event.enabled && state.isShuffleEnabled) {
      final restored = List<Song>.from(
        state.originalQueue.isNotEmpty ? state.originalQueue : state.queue,
      );
      int originalIndex = -1;
      if (state.currentSong != null) {
        originalIndex = restored.indexWhere(
          (s) => s.playableId == state.currentSong!.playableId,
        );
      }
      if (originalIndex == -1) {
        originalIndex = state.queueIndex.clamp(
          0,
          (restored.length - 1).clamp(0, 999999),
        );
      }

      emit(state.copyWith(
        isShuffleEnabled: false,
        queue: restored,
        queueIndex: originalIndex,
      ));
    }
  }

  void _onToggleShuffle(ToggleShuffleEvent event, Emitter<QueueState> emit) {
    add(SetShuffleEvent(!state.isShuffleEnabled));
  }

  void _onSetRepeatMode(SetRepeatModeEvent event, Emitter<QueueState> emit) {
    emit(state.copyWith(repeatMode: event.mode));
  }

  void _onCycleRepeatMode(CycleRepeatModeEvent event, Emitter<QueueState> emit) {
    final modes = RepeatMode.values;
    final currentIndex = modes.indexOf(state.repeatMode);
    final nextMode = modes[(currentIndex + 1) % modes.length];
    add(SetRepeatModeEvent(nextMode));
  }

  Future<void> _onToggleAutoPlay(
    ToggleAutoPlayEvent event,
    Emitter<QueueState> emit,
  ) async {
    final next = !state.autoPlay;
    await _settingsService.setAutoPlay(next);
    emit(state.copyWith(autoPlay: next));
    if (next) {
      checkAndAddRecommendations(state.currentSong);
    }
  }

  Future<void> _onMarkSongNotInterested(
    MarkSongNotInterestedEvent event,
    Emitter<QueueState> emit,
  ) async {
    final song = event.song;
    await _settingsService.markSongNotInterested(song.playableId);
    if (song.id.isNotEmpty && song.id != song.playableId) {
      await _settingsService.markSongNotInterested(song.id);
    }
    await _recommendationService?.markSongNotInterested(song);
    final targetIndex =
        state.queue.indexWhere((s) => s.playableId == song.playableId);
    if (targetIndex != -1) {
      add(RemoveFromQueueEvent(targetIndex));
    }
  }

  void _onRestoreQueue(RestoreQueueEvent event, Emitter<QueueState> emit) {
    emit(
      state.copyWith(
        queue: event.queue,
        originalQueue: event.queue,
        queueIndex: event.queueIndex,
        isRestoredSession: true,
      ),
    );
  }

  void _onClearPersistedQueue(
    ClearPersistedQueueEvent event,
    Emitter<QueueState> emit,
  ) {
    unawaited(QueuePersistenceService.instance.clearSession());
    emit(state.copyWith(isRestoredSession: false));
  }

  void _onAddRecommendations(
    _InternalAddRecommendationsEvent event,
    Emitter<QueueState> emit,
  ) {
    final availableCapacity = 50 - state.queue.length;
    if (availableCapacity <= 0) return;

    final uniqueSongs = <Song>[];
    final seenKeys = state.queue
        .map(
          (s) =>
              '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}',
        )
        .toSet();
    final seenIds = state.queue
        .map((s) => s.playableId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final song in event.songs) {
      if (uniqueSongs.length >= availableCapacity) break;
      final key =
          '${song.title.toLowerCase().trim()}|${song.artist.toLowerCase().trim()}';
      if (seenKeys.contains(key)) continue;
      if (song.playableId.isNotEmpty && !seenIds.add(song.playableId)) continue;
      seenKeys.add(key);
      uniqueSongs.add(song);
    }

    if (uniqueSongs.isNotEmpty) {
      final updatedQueue = [...state.queue, ...uniqueSongs];
      emit(state.copyWith(queue: updatedQueue));
    }
  }

  /// Check if queue is running low and fetch fresh recommendations.
  void checkAndAddRecommendations(
    Song? currentSong, {
    void Function(List<Song>)? onAppend,
  }) {
    if (_isFetchingRecommendations || _recommendationService == null) return;
    if (currentSong == null || state.queue.isEmpty) return;
    if (!state.autoPlay || !_settingsService.autoPlay) return;
    if (state.repeatMode != RepeatMode.off) return;
    if (state.queue.length >= 50) return;

    final int currentIndex = state.queueIndex;
    final int queueLength = state.queue.length;
    final int songsRemaining = queueLength - currentIndex - 1;

    if (songsRemaining >= _recommendTopUpRemaining ||
        _lastRecommendationSongId == currentSong.playableId) {
      return;
    }

    _lastRecommendationSongId = currentSong.playableId;
    final requestGen = ++_recommendationGeneration;

    final delay = songsRemaining == 0
        ? Duration.zero
        : const Duration(milliseconds: 500);

    Future.delayed(delay, () async {
      if (requestGen != _recommendationGeneration ||
          state.currentSong?.playableId != currentSong.playableId) {
        return;
      }
      await _fetchAndAppendRecommendations(currentSong, requestGen, onAppend);
    });
  }

  Future<void> _fetchAndAppendRecommendations(
    Song seedSong,
    int requestGen,
    void Function(List<Song>)? onAppend,
  ) async {
    final recommendationService = _recommendationService;
    if (recommendationService == null || _isFetchingRecommendations) return;

    _isFetchingRecommendations = true;
    try {
      final recommendations = await recommendationService.getRecommendations(
        currentSong: seedSong,
        limit: _recommendationBatchSize,
      );

      if (requestGen != _recommendationGeneration) return;

      if (recommendations.isNotEmpty) {
        if (onAppend != null) {
          onAppend(recommendations);
        } else {
          add(_InternalAddRecommendationsEvent(recommendations));
        }
        return;
      }

      final fallback = await _musicRepository.getRecommendations(
        limit: _recommendationBatchSize,
      );

      if (requestGen != _recommendationGeneration) return;

      fallback.fold(
        (_) {},
        (songs) {
          if (songs.isNotEmpty && requestGen == _recommendationGeneration) {
            if (onAppend != null) {
              onAppend(songs);
            } else {
              add(_InternalAddRecommendationsEvent(songs));
            }
          }
        },
      );
    } finally {
      _isFetchingRecommendations = false;
    }
  }

  /// Persist current queue session state.
  void persistCurrentSession({required Duration position}) {
    final song = state.currentSong;
    if (song != null && state.queue.isNotEmpty) {
      unawaited(
        QueuePersistenceService.instance.saveSession(
          currentSong: song,
          queue: state.queue,
          queueIndex: state.queueIndex,
          position: position,
        ),
      );
    }
  }
}

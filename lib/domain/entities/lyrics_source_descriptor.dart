import 'stream_info.dart';

/// Descriptor for a lyrics source showing its human-readable title,
/// technical identifier, capability level, and current availability status.
class LyricsSourceDescriptor {
  final String id;
  final String displayName;
  final LyricsSyncType supportedType;
  final bool isAvailable;
  final String statusDescription;

  const LyricsSourceDescriptor({
    required this.id,
    required this.displayName,
    required this.supportedType,
    required this.isAvailable,
    required this.statusDescription,
  });

  /// Factory indicating provider capability and availability
  factory LyricsSourceDescriptor.fromAvailability({
    required String id,
    required String displayName,
    required LyricsSyncType type,
    required bool available,
  }) {
    String desc;
    if (!available) {
      desc = 'Not available for this song';
    } else {
      switch (type) {
        case LyricsSyncType.wordSynced:
          desc = 'Karaoke · lights up word by word';
          break;
        case LyricsSyncType.lineSynced:
          desc = 'Time-synced lines';
          break;
        case LyricsSyncType.plain:
          desc = 'Plain text';
          break;
      }
    }
    return LyricsSourceDescriptor(
      id: id,
      displayName: displayName,
      supportedType: type,
      isAvailable: available,
      statusDescription: desc,
    );
  }
}

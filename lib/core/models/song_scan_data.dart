import 'dart:convert';

/// Physical acoustic scan data for a song.
///
/// Contains EBU R128 loudness measurements, BPM tempo estimation,
/// Camelot musical key, silence boundaries, and song climax drop window.
class SongScanData {
  final String songId;
  final double integratedLufs;
  final double truePeakDbfs;
  final double bpm;
  final String camelotKey;
  final double leadSilenceSeconds;
  final double tailSilenceSeconds;
  final double bestPartStartSeconds;
  final double bestPartEndSeconds;
  final DateTime scannedAt;

  const SongScanData({
    required this.songId,
    required this.integratedLufs,
    required this.truePeakDbfs,
    required this.bpm,
    required this.camelotKey,
    required this.leadSilenceSeconds,
    required this.tailSilenceSeconds,
    required this.bestPartStartSeconds,
    required this.bestPartEndSeconds,
    required this.scannedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'integratedLufs': integratedLufs,
      'truePeakDbfs': truePeakDbfs,
      'bpm': bpm,
      'camelotKey': camelotKey,
      'leadSilenceSeconds': leadSilenceSeconds,
      'tailSilenceSeconds': tailSilenceSeconds,
      'bestPartStartSeconds': bestPartStartSeconds,
      'bestPartEndSeconds': bestPartEndSeconds,
      'scannedAt': scannedAt.toIso8601String(),
    };
  }

  factory SongScanData.fromMap(Map<dynamic, dynamic> map) {
    return SongScanData(
      songId: map['songId']?.toString() ?? '',
      integratedLufs: (map['integratedLufs'] as num?)?.toDouble() ?? -14.0,
      truePeakDbfs: (map['truePeakDbfs'] as num?)?.toDouble() ?? -1.0,
      bpm: (map['bpm'] as num?)?.toDouble() ?? 120.0,
      camelotKey: map['camelotKey']?.toString() ?? '8B',
      leadSilenceSeconds: (map['leadSilenceSeconds'] as num?)?.toDouble() ?? 0.0,
      tailSilenceSeconds: (map['tailSilenceSeconds'] as num?)?.toDouble() ?? 0.0,
      bestPartStartSeconds: (map['bestPartStartSeconds'] as num?)?.toDouble() ?? 0.0,
      bestPartEndSeconds: (map['bestPartEndSeconds'] as num?)?.toDouble() ?? 0.0,
      scannedAt: map['scannedAt'] != null
          ? DateTime.tryParse(map['scannedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory SongScanData.fromJson(String source) =>
      SongScanData.fromMap(json.decode(source) as Map<dynamic, dynamic>);

  SongScanData copyWith({
    String? songId,
    double? integratedLufs,
    double? truePeakDbfs,
    double? bpm,
    String? camelotKey,
    double? leadSilenceSeconds,
    double? tailSilenceSeconds,
    double? bestPartStartSeconds,
    double? bestPartEndSeconds,
    DateTime? scannedAt,
  }) {
    return SongScanData(
      songId: songId ?? this.songId,
      integratedLufs: integratedLufs ?? this.integratedLufs,
      truePeakDbfs: truePeakDbfs ?? this.truePeakDbfs,
      bpm: bpm ?? this.bpm,
      camelotKey: camelotKey ?? this.camelotKey,
      leadSilenceSeconds: leadSilenceSeconds ?? this.leadSilenceSeconds,
      tailSilenceSeconds: tailSilenceSeconds ?? this.tailSilenceSeconds,
      bestPartStartSeconds: bestPartStartSeconds ?? this.bestPartStartSeconds,
      bestPartEndSeconds: bestPartEndSeconds ?? this.bestPartEndSeconds,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SongScanData &&
        other.songId == songId &&
        other.integratedLufs == integratedLufs &&
        other.truePeakDbfs == truePeakDbfs &&
        other.bpm == bpm &&
        other.camelotKey == camelotKey &&
        other.leadSilenceSeconds == leadSilenceSeconds &&
        other.tailSilenceSeconds == tailSilenceSeconds &&
        other.bestPartStartSeconds == bestPartStartSeconds &&
        other.bestPartEndSeconds == bestPartEndSeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      songId,
      integratedLufs,
      truePeakDbfs,
      bpm,
      camelotKey,
      leadSilenceSeconds,
      tailSilenceSeconds,
      bestPartStartSeconds,
      bestPartEndSeconds,
    );
  }

  @override
  String toString() {
    return 'SongScanData(id: $songId, LUFS: $integratedLufs, Peak: $truePeakDbfs, BPM: $bpm, Key: $camelotKey, BestPart: ${bestPartStartSeconds}s-${bestPartEndSeconds}s)';
  }
}

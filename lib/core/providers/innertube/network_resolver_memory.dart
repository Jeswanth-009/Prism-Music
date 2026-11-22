import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Performance memory statistics for a specific resolver on a network type.
class ResolverStat {
  final String resolverName;
  final int successCount;
  final int failureCount;
  final double averageLatencyMs;

  const ResolverStat({
    required this.resolverName,
    this.successCount = 0,
    this.failureCount = 0,
    this.averageLatencyMs = 0.0,
  });

  double get score {
    final total = successCount + failureCount;
    if (total == 0) return 0.5; // neutral baseline
    final successRate = successCount / total;
    // Lower latency is better (normalized up to 3000ms)
    final latencyScore = (1.0 - (averageLatencyMs / 3000.0)).clamp(0.0, 1.0);
    return (successRate * 0.7) + (latencyScore * 0.3);
  }

  Map<String, dynamic> toMap() => {
        'resolverName': resolverName,
        'successCount': successCount,
        'failureCount': failureCount,
        'averageLatencyMs': averageLatencyMs,
      };

  factory ResolverStat.fromMap(Map<dynamic, dynamic> map) => ResolverStat(
        resolverName: map['resolverName']?.toString() ?? 'unknown',
        successCount: (map['successCount'] as num?)?.toInt() ?? 0,
        failureCount: (map['failureCount'] as num?)?.toInt() ?? 0,
        averageLatencyMs: (map['averageLatencyMs'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Tracks per-network resolver affinity and success memory (WiFi vs Cellular)
/// to reduce stream startup latency.
class NetworkResolverMemory {
  static const String _boxName = 'network_resolver_memory';
  Box? _box;

  NetworkResolverMemory({Box? box}) : _box = box;

  Future<Box?> _getBox() async {
    try {
      if (_box != null && _box!.isOpen) return _box!;
      if (Hive.isBoxOpen(_boxName)) {
        _box = Hive.box(_boxName);
      } else {
        _box = await Hive.openBox(_boxName);
      }
      return _box;
    } catch (e) {
      debugPrint('NetworkResolverMemory._getBox error: $e');
      return null;
    }
  }

  String _buildKey(String networkType, String resolverName) =>
      '${networkType}_$resolverName';

  /// Records the outcome of a resolution attempt.
  Future<void> recordResolution({
    required String networkType,
    required String resolverName,
    required bool success,
    required Duration latency,
  }) async {
    try {
      final box = await _getBox();
      if (box == null) return;
      final key = _buildKey(networkType, resolverName);
      final raw = box.get(key);

      ResolverStat current = const ResolverStat(resolverName: '');
      if (raw is Map) {
        current = ResolverStat.fromMap(raw);
      }

      final newSuccess = current.successCount + (success ? 1 : 0);
      final newFailure = current.failureCount + (success ? 0 : 1);
      final totalSuccess = newSuccess > 0 ? newSuccess : 1;
      final newLatency = success
          ? (current.averageLatencyMs * current.successCount +
                  latency.inMilliseconds) /
              totalSuccess
          : current.averageLatencyMs;

      final updated = ResolverStat(
        resolverName: resolverName,
        successCount: newSuccess,
        failureCount: newFailure,
        averageLatencyMs: newLatency,
      );

      await box.put(key, updated.toMap());
    } catch (e) {
      debugPrint('NetworkResolverMemory.recordResolution error: $e');
    }
  }

  /// Returns sorted list of resolvers prioritized by performance on [networkType].
  Future<List<String>> getPrioritizedResolvers({
    required String networkType,
    required List<String> availableResolvers,
  }) async {
    try {
      final box = await _getBox();
      if (box == null) return availableResolvers;
      final scored = <String, double>{};

      for (final r in availableResolvers) {
        final key = _buildKey(networkType, r);
        final raw = box.get(key);
        if (raw is Map) {
          final stat = ResolverStat.fromMap(raw);
          scored[r] = stat.score;
        } else {
          scored[r] = 0.5; // Default unweighted
        }
      }

      final sorted = List<String>.from(availableResolvers);
      sorted.sort((a, b) => (scored[b] ?? 0.5).compareTo(scored[a] ?? 0.5));
      return sorted;
    } catch (_) {
      return availableResolvers;
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Tracks latency, failure rates, and quarantine states for third-party
/// public API and proxy instances (Piped, Invidious).
class InstanceHealthService {
  static final InstanceHealthService _instance = InstanceHealthService._internal();

  factory InstanceHealthService() => _instance;

  InstanceHealthService._internal();

  /// Default curated Piped API instances
  static const List<String> defaultPipedApiInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
    'https://api.piped.privacydev.net',
    'https://pipedapi.r4fo.com',
    'https://piped-api.lunar.icu',
  ];

  /// Default curated Piped audio proxy instances
  static const List<String> defaultPipedProxyInstances = [
    'https://pipedproxy.kavin.rocks',
    'https://pipedproxy-cdg.kavin.rocks',
    'https://pipedproxy-ams.kavin.rocks',
    'https://pipedproxy-fra.kavin.rocks',
  ];

  /// Default curated Invidious instances
  static const List<String> defaultInvidiousInstances = [
    'https://inv.nadeko.net',
    'https://invidious.f5.si',
    'https://invidious.private.coffee',
    'https://inv.tux.pizza',
    'https://yewtu.be',
    'https://invidious.nerdvpn.de',
  ];

  /// Active mutable pools seeded with defaults
  final List<String> _pipedApiInstances = List.from(defaultPipedApiInstances);
  final List<String> _pipedProxyInstances = List.from(defaultPipedProxyInstances);
  final List<String> _invidiousInstances = List.from(defaultInvidiousInstances);

  List<String> get pipedApiPool => List.unmodifiable(_pipedApiInstances);
  List<String> get pipedProxyPool => List.unmodifiable(_pipedProxyInstances);
  List<String> get invidiousPool => List.unmodifiable(_invidiousInstances);

  /// Quarantined until timestamp per host
  final Map<String, DateTime> _quarantineUntil = {};

  /// Consecutive failure count per host
  final Map<String, int> _consecutiveFailures = {};

  /// Rolling latency estimate in milliseconds per host
  final Map<String, int> _latencyMs = {};

  /// Total successful requests per host
  final Map<String, int> _successCounts = {};

  /// Threshold of consecutive failures before quarantining an instance
  static const int failureThreshold = 2;

  /// Duration to quarantine a failing instance (10 minutes)
  static const Duration quarantineDuration = Duration(minutes: 10);

  /// Check if a specific host is currently in quarantine
  bool isHostQuarantined(String host) {
    final until = _quarantineUntil[host];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _quarantineUntil.remove(host);
      _consecutiveFailures[host] = 0;
      return false;
    }
    return true;
  }

  /// Record a successful call to a host
  void recordSuccess(String host, Duration latency) {
    _consecutiveFailures[host] = 0;
    _quarantineUntil.remove(host);
    _successCounts[host] = (_successCounts[host] ?? 0) + 1;

    // Exponential moving average for latency
    final currentLatency = _latencyMs[host];
    if (currentLatency == null) {
      _latencyMs[host] = latency.inMilliseconds;
    } else {
      _latencyMs[host] = ((currentLatency * 0.7) + (latency.inMilliseconds * 0.3)).round();
    }
  }

  /// Record a failure for a host, quarantining if threshold reached
  void recordFailure(String host, [Object? error]) {
    final count = (_consecutiveFailures[host] ?? 0) + 1;
    _consecutiveFailures[host] = count;

    if (count >= failureThreshold) {
      final until = DateTime.now().add(quarantineDuration);
      _quarantineUntil[host] = until;
      debugPrint(
        'InstanceHealthService: Quarantining $host for 10m ($count consecutive failures. Error: $error)',
      );
    } else {
      debugPrint('InstanceHealthService: Warning - $host failure count: $count');
    }
  }

  /// Add an Invidious instance to the active pool
  void addInvidiousInstance(String host) {
    final cleanHost = host.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanHost.isNotEmpty && !_invidiousInstances.contains(cleanHost)) {
      _invidiousInstances.add(cleanHost);
    }
  }

  /// Add a Piped API instance to the active pool
  void addPipedApiInstance(String host) {
    final cleanHost = host.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanHost.isNotEmpty && !_pipedApiInstances.contains(cleanHost)) {
      _pipedApiInstances.add(cleanHost);
    }
  }

  /// Add a Piped proxy instance to the active pool
  void addPipedProxyInstance(String host) {
    final cleanHost = host.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanHost.isNotEmpty && !_pipedProxyInstances.contains(cleanHost)) {
      _pipedProxyInstances.add(cleanHost);
    }
  }

  /// Discover and sync healthy Invidious and Piped instances from public registries
  Future<void> syncInstancesFromRemote({Dio? dio}) async {
    final client = dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );

    try {
      final response = await client.get('https://api.invidious.io/instances.json?sort_by=health');
      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        int added = 0;
        for (final item in list) {
          if (item is List && item.length >= 2) {
            final details = item[1];
            if (details is Map) {
              final type = details['type'];
              final api = details['api'];
              final uri = details['uri']?.toString();
              if (type == 'https' && api == true && uri != null && uri.startsWith('https://')) {
                addInvidiousInstance(uri);
                added++;
                if (added >= 5) break; // Limit newly added to top 5
              }
            }
          }
        }
        debugPrint('InstanceHealthService: Synced $added healthy Invidious instances from remote registry');
      }
    } catch (e) {
      debugPrint('InstanceHealthService: Remote instance sync non-fatal error: $e');
    }
  }

  /// Get the best available Piped API instance, prioritizing non-quarantined
  /// and lowest-latency hosts.
  String getHealthyPipedApi() {
    return _selectBestHost(_pipedApiInstances);
  }

  /// Get the best available Piped proxy instance
  String getHealthyPipedProxy() {
    return _selectBestHost(_pipedProxyInstances);
  }

  /// Get the best available Invidious instance
  String getHealthyInvidious() {
    return _selectBestHost(_invidiousInstances);
  }

  /// Select the best host from a candidate pool
  String _selectBestHost(List<String> pool) {
    if (pool.isEmpty) throw ArgumentError('Candidate pool cannot be empty');

    // 1. Filter out quarantined hosts
    final healthy = pool.where((h) => !isHostQuarantined(h)).toList();

    if (healthy.isNotEmpty) {
      // Sort by recorded latency (prefer lowest latency; hosts without data placed in middle)
      healthy.sort((a, b) {
        final latA = _latencyMs[a] ?? 1000;
        final latB = _latencyMs[b] ?? 1000;
        return latA.compareTo(latB);
      });
      return healthy.first;
    }

    // 2. All hosts in pool are quarantined: fail soft by picking the host
    // whose quarantine expires soonest.
    debugPrint('InstanceHealthService: All instances quarantined in pool! Failing soft to earliest expiry.');
    String bestFallback = pool.first;
    DateTime earliest = DateTime.now().add(const Duration(days: 1));

    for (final host in pool) {
      final expiry = _quarantineUntil[host] ?? DateTime.now();
      if (expiry.isBefore(earliest)) {
        earliest = expiry;
        bestFallback = host;
      }
    }

    return bestFallback;
  }

  /// Clear all quarantine states (e.g. on network reconnection)
  void resetQuarantines() {
    _quarantineUntil.clear();
    _consecutiveFailures.clear();
  }

  /// Diagnostic stats for telemetry and settings
  Map<String, dynamic> getStats() {
    return {
      'quarantinedCount': _quarantineUntil.length,
      'quarantinedHosts': _quarantineUntil.keys.toList(),
      'latencies': Map<String, int>.from(_latencyMs),
      'successCounts': Map<String, int>.from(_successCounts),
    };
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

/// Representation of an on-device sanitized crash / diagnostic log entry.
class CrashReport {
  final String id;
  final DateTime timestamp;
  final String error;
  final String stackTrace;
  final String? context;
  final String osPlatform;
  final String appVersion;

  const CrashReport({
    required this.id,
    required this.timestamp,
    required this.error,
    required this.stackTrace,
    this.context,
    required this.osPlatform,
    this.appVersion = '0.2.83',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'error': error,
    'stackTrace': stackTrace,
    'context': context,
    'osPlatform': osPlatform,
    'appVersion': appVersion,
  };

  factory CrashReport.fromMap(Map<dynamic, dynamic> map) {
    return CrashReport(
      id: map['id']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      error: map['error']?.toString() ?? '',
      stackTrace: map['stackTrace']?.toString() ?? '',
      context: map['context']?.toString(),
      osPlatform: map['osPlatform']?.toString() ?? Platform.operatingSystem,
      appVersion: map['appVersion']?.toString() ?? '0.2.83',
    );
  }
}

/// Privacy-first crash reporting service with local diagnostic logs and optional Sentry dispatch.
class CrashReportingService {
  static final CrashReportingService instance = CrashReportingService._internal();

  static const String _crashBoxName = 'crash_reports';
  static const int _maxStoredReports = 50;

  Box? _crashBox;
  bool _initialized = false;

  CrashReportingService._internal();

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Hive.isBoxOpen(_crashBoxName)) {
        _crashBox = Hive.box(_crashBoxName);
      } else {
        _crashBox = await Hive.openBox(_crashBoxName);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('CrashReportingService: initialization failed: $e');
    }
  }

  /// Sanitizes text to remove personally identifiable information, IPs, tokens, and file paths.
  static String sanitizeText(String text) {
    if (text.isEmpty) return text;

    var sanitized = text;

    // Redact IPv4 addresses
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
      '[REDACTED_IP]',
    );

    // Redact URL query strings that might hold tokens or user searches
    sanitized = sanitized.replaceAll(
      RegExp(r'\?[a-zA-Z0-9_=&%+-]{8,}'),
      '?[REDACTED_PARAMS]',
    );

    // Redact email addresses
    sanitized = sanitized.replaceAll(
      RegExp(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+'),
      '[REDACTED_EMAIL]',
    );

    // Redact local user directory paths
    sanitized = sanitized.replaceAll(
      RegExp(r'(/Users/[^/]+|C:\\Users\\[^\\]+)'),
      '[USER_DIR]',
    );

    return sanitized;
  }

  /// Record an uncaught error locally and dispatch to remote Sentry if opted-in
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) async {
    final sanitizedError = sanitizeText(error.toString());
    final sanitizedStack = sanitizeText(stackTrace.toString());
    final sanitizedContext = context != null ? sanitizeText(context) : null;

    final report = CrashReport(
      id: '${DateTime.now().millisecondsSinceEpoch}_${sanitizedError.hashCode.abs()}',
      timestamp: DateTime.now(),
      error: sanitizedError,
      stackTrace: sanitizedStack,
      context: sanitizedContext,
      osPlatform: Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
              ? 'iOS'
              : Platform.operatingSystem,
    );

    // 1. Save locally to Hive box
    try {
      if (_crashBox != null) {
        await _crashBox!.put(report.id, report.toMap());

        // Trim oldest if exceeding cap
        if (_crashBox!.length > _maxStoredReports) {
          final oldestKey = _crashBox!.keys.first;
          await _crashBox!.delete(oldestKey);
        }
      }
    } catch (e) {
      debugPrint('CrashReportingService: failed to write local crash report: $e');
    }

    // 2. Dispatch to remote Sentry if user opted in and DSN configured
    if (SettingsService.instance.crashReportingEnabled) {
      final dsn = SettingsService.instance.sentryDsn;
      if (dsn != null && dsn.isNotEmpty) {
        _dispatchToSentry(report, dsn).catchError((e) {
          debugPrint('CrashReportingService: Sentry dispatch error: $e');
        });
      }
    }
  }

  /// Send sanitized event to Sentry compatible HTTP endpoint
  Future<void> _dispatchToSentry(CrashReport report, String dsn) async {
    final uri = Uri.tryParse(dsn);
    if (uri == null) return;

    final userInfo = uri.userInfo.split(':');
    final publicKey = userInfo.first;
    final secretKey = userInfo.length > 1 ? userInfo[1] : '';
    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.isEmpty) return;
    final projectId = pathSegments.last;

    final host = uri.host;
    final scheme = uri.scheme;
    final port = uri.hasPort ? ':${uri.port}' : '';
    final endpoint = Uri.parse('$scheme://$host$port/api/$projectId/store/');

    final payload = {
      'event_id': report.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').padRight(32, '0').substring(0, 32),
      'timestamp': report.timestamp.toUtc().toIso8601String(),
      'platform': 'flutter',
      'level': 'error',
      'logger': 'prism.crash',
      'release': 'prism-music@${report.appVersion}',
      'environment': kDebugMode ? 'development' : 'production',
      'exception': {
        'values': [
          {
            'type': report.error.split(':').first,
            'value': report.error,
            'stacktrace': {
              'frames': report.stackTrace
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)
                  .map((line) => {'function': line.trim()})
                  .toList(),
            },
          }
        ],
      },
      'contexts': {
        'os': {'name': report.osPlatform},
      },
      if (report.context != null) 'extra': {'context': report.context},
    };

    final authHeader = 'Sentry sentry_version=7, '
        'sentry_client=prism-music-client/1.0, '
        'sentry_key=$publicKey'
        '${secretKey.isNotEmpty ? ', sentry_secret=$secretKey' : ''}';

    await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'X-Sentry-Auth': authHeader,
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 8));
  }

  /// Retrieve all recorded local crash reports (ordered newest first)
  List<CrashReport> getReports() {
    if (_crashBox == null) return const [];
    try {
      final reports = <CrashReport>[];
      for (final key in _crashBox!.keys) {
        final val = _crashBox!.get(key);
        if (val is Map) {
          reports.add(CrashReport.fromMap(val));
        }
      }
      reports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return reports;
    } catch (_) {
      return const [];
    }
  }

  /// Clear all on-device crash logs
  Future<void> clearReports() async {
    if (_crashBox == null) return;
    await _crashBox!.clear();
  }

  /// Export local reports as formatted text
  String exportReportsAsText() {
    final reports = getReports();
    if (reports.isEmpty) return 'No diagnostic crash logs recorded.';

    final buf = StringBuffer('=== Prism Music Diagnostic Reports ===\n');
    buf.writeln('Total entries: ${reports.length}\n');
    for (final r in reports) {
      buf.writeln('--- Report [${r.id}] ---');
      buf.writeln('Date: ${r.timestamp.toIso8601String()}');
      buf.writeln('Platform: ${r.osPlatform} | App Version: ${r.appVersion}');
      if (r.context != null) buf.writeln('Context: ${r.context}');
      buf.writeln('Error: ${r.error}');
      buf.writeln('Stack Trace:');
      buf.writeln(r.stackTrace);
      buf.writeln();
    }
    return buf.toString();
  }
}


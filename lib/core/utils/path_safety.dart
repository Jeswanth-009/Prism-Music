import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/settings_service.dart';
import 'logger.dart';

/// Sanitizes an untrusted string (provider id, song title, restored backup
/// value) for use as a single filename component.
///
/// Keeps only `[A-Za-z0-9_-]` so separators, colons and traversal sequences
/// cannot survive, collapses runs of removed characters, and caps the length.
String sanitizePathComponent(String input, {int maxLength = 120}) {
  final cleaned = input.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), ' ').trim();
  final collapsed = cleaned.replaceAll(RegExp(r'\s+'), '-');
  final capped = collapsed.length > maxLength ? collapsed.substring(0, maxLength) : collapsed;
  return capped.isEmpty ? 'unknown' : capped;
}

/// Random id usable in filenames (never derived from provider data).
String secureFileId() {
  final rand = Random.secure();
  final values = List<int>.generate(16, (_) => rand.nextInt(256));
  return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// True when [url] is an acceptable remote media URL: https only, except for
/// plain-http loopback addresses which may be used by local tooling.
bool isAcceptableStreamUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  if (uri.scheme == 'https') return true;
  if (uri.scheme == 'http') {
    const loopbackHosts = {'127.0.0.1', 'localhost', '::1', '10.0.2.2'};
    return loopbackHosts.contains(uri.host);
  }
  return false;
}

/// True when [path] unambiguously resolves inside one of [roots].
///
/// Both sides are canonicalized; when the target exists, symlinks are
/// resolved first so a link pointing outside the roots is rejected.
bool isPathWithinAllowedRoots(String path, List<String> roots) {
  if (path.isEmpty || roots.isEmpty) return false;

  String resolved = p.canonicalize(path);
  try {
    final entity = File(path);
    if (entity.existsSync()) {
      resolved = p.canonicalize(entity.resolveSymbolicLinksSync());
    } else {
      final dir = Directory(path);
      if (dir.existsSync()) {
        resolved = p.canonicalize(dir.resolveSymbolicLinksSync());
      }
    }
  } catch (_) {
    return false;
  }

  for (final root in roots) {
    if (root.isEmpty) continue;
    final canonicalRoot = p.canonicalize(root);
    // Never treat the root itself (or a parent of the root) as deletable.
    if (resolved == canonicalRoot) continue;
    if (p.isWithin(canonicalRoot, resolved)) return true;
  }
  return false;
}

/// Computes and caches the directories Prism Music owns for downloads, so
/// deletion of stored `localPath` values can be restricted to those roots.
///
/// Paths restored from backups or written by providers are untrusted; a value
/// outside these roots must never be handed to [File.delete].
class DownloadPathGuard {
  DownloadPathGuard._();

  static List<String>? _cachedRoots;

  /// App-owned roots: the user-configured download folder (if any) plus every
  /// app-specific/legacy PrismMusic directory the app may have used.
  static Future<List<String>> allowedRoots() async {
    final cached = _cachedRoots;
    if (cached != null) return cached;

    final roots = <String>{};

    try {
      final custom = SettingsService.instance.downloadFolderPath;
      if (custom != null && custom.isNotEmpty) roots.add(custom);
    } catch (_) {}

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) roots.add(ext.path);
    } catch (_) {}

    try {
      roots.add('/storage/emulated/0/Download/PrismMusic');
    } catch (_) {}

    for (final getter in <Future<Directory> Function()>[
      getApplicationDocumentsDirectory,
      getApplicationSupportDirectory,
      getTemporaryDirectory,
    ]) {
      try {
        roots.add((await getter()).path);
      } catch (_) {}
    }

    _cachedRoots = roots.toList(growable: false);
    return _cachedRoots!;
  }

  /// Whether a stored [path] may be deleted. Only existing files strictly
  /// inside an allowed root qualify; symlinks escaping a root are refused.
  static Future<bool> canDelete(String path, {List<String>? roots}) async {
    if (path.isEmpty) return false;
    final file = File(path);
    try {
      if (!await file.exists()) return false;
    } catch (_) {
      return false;
    }
    final effectiveRoots = roots ?? await allowedRoots();
    final allowed = isPathWithinAllowedRoots(path, effectiveRoots);
    if (!allowed) {
      logError('Refusing to delete file outside app-owned roots: $path');
    }
    return allowed;
  }

  /// Clears the cached roots (used by tests to inject fresh directories).
  static void resetForTesting() => _cachedRoots = null;
}

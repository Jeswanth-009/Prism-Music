import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the HTTPS-only network posture: the manifest must not re-enable
/// cleartext traffic, the network security config must deny it, and no Dart
/// source may embed a plain-http URL to a non-loopback host.
void main() {
  test('manifest denies cleartext and references the security config',
      () async {
    final manifest =
        await File('android/app/src/main/AndroidManifest.xml').readAsString();
    expect(manifest, isNot(contains('usesCleartextTraffic')));

    final config = await File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsString();
    expect(config, contains('cleartextTrafficPermitted="false"'));
    expect(manifest, contains('android:networkSecurityConfig='));
  });

  test('no plain-http URL to a non-loopback host appears in lib/', () async {
    final loopbackHosts = {'127.0.0.1', 'localhost', '10.0.2.2', '::1'};
    final offenders = <String>[];

    final entities = Directory('lib').listSync(recursive: true);
    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = await entity.readAsLines();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        var index = line.indexOf('http://');
        while (index != -1) {
          final rest = line
              .substring(index + 'http://'.length)
              .trim()
              .split(RegExp('[/:\\s\'"]'))
              .first;
          if (rest.isNotEmpty && !loopbackHosts.contains(rest)) {
            offenders.add('${entity.path}:${i + 1}: $rest');
          }
          index = line.indexOf('http://', index + 1);
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'cleartext URLs found (network security config denies them): '
            '${offenders.join(', ')}');
  });
}

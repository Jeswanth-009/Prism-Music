import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Keystore and Signing Security Audit', () {
    test('android/app/debug.keystore exists and contains standard debug key structure', () {
      final keystoreFile = File('android/app/debug.keystore');
      expect(keystoreFile.existsSync(), isTrue);

      final bytes = keystoreFile.readAsBytesSync();
      expect(bytes.length, greaterThan(1000));
      // PKCS#12 ASN.1 DER sequence header: 0x30 0x82
      expect(bytes[0], equals(0x30));
      expect(bytes[1], equals(0x82));
    });

    test('.gitignore excludes private keystore and properties files', () {
      final gitignoreFile = File('.gitignore');
      expect(gitignoreFile.existsSync(), isTrue);
      final content = gitignoreFile.readAsStringSync();

      expect(content, contains('key.properties'));
      expect(content, contains('*.jks'));
      expect(content, contains('*.p12'));
    });

    test('no release keys, keystores or key.properties are tracked in git index', () {
      final result = Process.runSync('git', [
        'ls-files',
        'android/key.properties',
        '*.jks',
        '*.p12',
      ]);
      expect(result.exitCode, equals(0));
      final trackedFiles = (result.stdout as String).trim();
      expect(trackedFiles, isEmpty,
          reason: 'No release signing keys or key.properties should ever be tracked in git: $trackedFiles');
    });

    test('tracked keystore is strictly debug.keystore', () {
      final result = Process.runSync('git', [
        'ls-files',
        '*.keystore',
      ]);
      expect(result.exitCode, equals(0));
      final trackedKeystores = (result.stdout as String)
          .split(RegExp(r'[\r\n]+'))
          .where((s) => s.isNotEmpty)
          .toList();

      expect(trackedKeystores, equals(['android/app/debug.keystore']));
    });
  });
}

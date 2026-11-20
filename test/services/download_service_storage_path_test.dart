import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scoped storage and backup rules configuration', () {
    test('backup_rules.xml exists and excludes private hive data and credentials', () {
      final file = File('android/app/src/main/res/xml/backup_rules.xml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('<exclude domain="file" path="app_flutter"'));
      expect(content, contains('<exclude domain="sharedpref" path="FlutterSecureStorage"'));
      expect(content, contains('<exclude domain="external" path="Downloads"'));
    });

    test('data_extraction_rules.xml exists and excludes private data for Android 12+', () {
      final file = File('android/app/src/main/res/xml/data_extraction_rules.xml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('<cloud-backup>'));
      expect(content, contains('<device-transfer>'));
      expect(content, contains('<exclude domain="file" path="app_flutter"'));
      expect(content, contains('<exclude domain="sharedpref" path="FlutterSecureStorage"'));
    });

    test('AndroidManifest.xml declares both fullBackupContent and dataExtractionRules', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content, contains('android:fullBackupContent="@xml/backup_rules"'));
      expect(content, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      expect(content, contains('android:allowBackup="false"'));
    });

    test('DownloadService does not write fallback to un-scoped /storage/emulated/0/Download', () {
      final serviceFile = File('lib/core/services/download_service.dart');
      expect(serviceFile.existsSync(), isTrue);

      final content = serviceFile.readAsStringSync();
      // Ensure the raw un-scoped public directory fallback is not present in DownloadService
      expect(content, isNot(contains("Directory('/storage/emulated/0/Download')")));
    });
  });
}

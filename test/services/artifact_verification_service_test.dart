import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/artifact_verification_service.dart';

void main() {
  group('ArtifactVerificationService Tests', () {
    final service = ArtifactVerificationService.instance;

    test('detectCurrentArch returns valid DeviceArch', () {
      final arch = service.detectCurrentArch();
      expect(arch, isA<DeviceArch>());
      expect(arch.displayName, isNotEmpty);
      expect(arch.artifactPattern, isNotEmpty);
    });

    test('getArtifactChoices returns complete catalog with architecture recommendations', () {
      final choicesArm64 = service.getArtifactChoices(detectedArch: DeviceArch.arm64);
      expect(choicesArm64.length, equals(4));

      final arm64Choice = choicesArm64.firstWhere((c) => c.arch == DeviceArch.arm64);
      expect(arm64Choice.isRecommended, isTrue);
      expect(arm64Choice.targetAudience, contains('Physical Android Phones'));

      final choicesX86 = service.getArtifactChoices(detectedArch: DeviceArch.x86_64);
      final x86Choice = choicesX86.firstWhere((c) => c.arch == DeviceArch.x86_64);
      expect(x86Choice.isRecommended, isTrue);
      expect(x86Choice.targetAudience, contains('Emulator'));
    });

    test('getHashVerificationCommand generates correct platform commands', () {
      final winCmd = service.getHashVerificationCommand(
        filename: 'prism-music-v0.2.51-arm64-v8a-release.apk',
        osName: 'windows',
      );
      expect(winCmd, contains('certutil -hashfile'));
      expect(winCmd, contains('SHA256'));

      final linuxCmd = service.getHashVerificationCommand(
        filename: 'prism-music-v0.2.51-arm64-v8a-release.apk',
        osName: 'linux',
      );
      expect(linuxCmd, equals('sha256sum "prism-music-v0.2.51-arm64-v8a-release.apk"'));

      final psCmd = service.getPowerShellVerificationCommand('prism-music.apk');
      expect(psCmd, equals('Get-FileHash -Algorithm SHA256 .\\prism-music.apk'));
    });

    test('getSigningCertificateMetadata contains required security verification fields', () {
      final cert = service.getSigningCertificateMetadata();
      expect(cert.containsKey('fingerprintSha256'), isTrue);
      expect(cert.containsKey('signingAlgorithm'), isTrue);
      expect(cert.containsKey('buildPipeline'), isTrue);
      expect(cert.containsKey('sbomUrl'), isTrue);
    });
  });
}

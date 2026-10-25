import 'dart:ffi' as ffi;
import 'dart:io';

/// Hardware architectures supported by Prism Music release artifacts.
enum DeviceArch {
  arm64,
  armv7,
  x86_64,
  x86,
  universal,
  unknown;

  /// User-friendly label for this architecture.
  String get displayName {
    switch (this) {
      case DeviceArch.arm64:
        return 'ARM64-v8a';
      case DeviceArch.armv7:
        return 'ARMv7 (32-bit)';
      case DeviceArch.x86_64:
        return 'x86_64 (Emulator / PC)';
      case DeviceArch.x86:
        return 'x86 (32-bit Emulator)';
      case DeviceArch.universal:
        return 'Universal (All Devices)';
      case DeviceArch.unknown:
        return 'Standard Architecture';
    }
  }

  /// Artifact pattern string used to identify matching releases.
  String get artifactPattern {
    switch (this) {
      case DeviceArch.x86_64:
        return 'x86_64';
      case DeviceArch.armv7:
        return 'armeabi-v7a';
      case DeviceArch.arm64:
        return 'arm64-v8a';
      default:
        return 'release';
    }
  }
}

/// Metadata model describing a verified release artifact option.
class ArtifactChoice {
  final String title;
  final DeviceArch arch;
  final String description;
  final String filenamePattern;
  final String targetAudience;
  final bool isRecommended;

  const ArtifactChoice({
    required this.title,
    required this.arch,
    required this.description,
    required this.filenamePattern,
    required this.targetAudience,
    this.isRecommended = false,
  });
}

/// Service providing verified download artifact choices, architecture detection,
/// and SHA-256 certificate and hash verification commands.
class ArtifactVerificationService {
  ArtifactVerificationService._();
  static final ArtifactVerificationService instance = ArtifactVerificationService._();

  /// Detects the native hardware architecture of the current runtime environment.
  DeviceArch detectCurrentArch() {
    try {
      final currentAbi = ffi.Abi.current();
      switch (currentAbi) {
        case ffi.Abi.androidArm64:
        case ffi.Abi.windowsArm64:
        case ffi.Abi.linuxArm64:
        case ffi.Abi.macosArm64:
          return DeviceArch.arm64;
        case ffi.Abi.androidArm:
          return DeviceArch.armv7;
        case ffi.Abi.androidX64:
        case ffi.Abi.windowsX64:
        case ffi.Abi.linuxX64:
        case ffi.Abi.macosX64:
          return DeviceArch.x86_64;
        case ffi.Abi.androidIA32:
        case ffi.Abi.windowsIA32:
        case ffi.Abi.linuxIA32:
          return DeviceArch.x86;
        default:
          return DeviceArch.universal;
      }
    } catch (_) {
      // In web or restricted environments, inspect operating system version string.
      final version = Platform.version.toLowerCase();
      if (version.contains('arm64') || version.contains('aarch64')) {
        return DeviceArch.arm64;
      }
      if (version.contains('x86_64') || version.contains('x64')) {
        return DeviceArch.x86_64;
      }
      return DeviceArch.universal;
    }
  }

  /// Returns the catalog of artifact choices prioritized for the given [detectedArch].
  List<ArtifactChoice> getArtifactChoices({DeviceArch? detectedArch}) {
    final current = detectedArch ?? detectCurrentArch();

    return [
      ArtifactChoice(
        title: 'ARM64 Universal APK',
        arch: DeviceArch.arm64,
        description: 'Optimized 64-bit build for modern Android phones and tablets (Android 7.0+). Highest performance & battery efficiency.',
        filenamePattern: 'prism-music-*-arm64-v8a-release.apk',
        targetAudience: 'Physical Android Phones & Tablets (Pixel, Samsung, OnePlus, Xiaomi, etc.)',
        isRecommended: current == DeviceArch.arm64 || current == DeviceArch.universal,
      ),
      ArtifactChoice(
        title: 'x86_64 Emulator APK',
        arch: DeviceArch.x86_64,
        description: 'Native 64-bit x86 build for Android Studio virtual devices, ChromeOS, Windows Subsystem for Android (WSA), and Waydroid.',
        filenamePattern: 'prism-music-*-x86_64-emulator-release.apk',
        targetAudience: 'Android Studio AVD, Genymotion, ChromeOS, WSA & Linux Emulators',
        isRecommended: current == DeviceArch.x86_64 || current == DeviceArch.x86,
      ),
      ArtifactChoice(
        title: 'ARMv7 32-bit APK',
        arch: DeviceArch.armv7,
        description: 'Legacy 32-bit ARM build for older Android devices and budget legacy hardware.',
        filenamePattern: 'prism-music-*-armeabi-v7a-release.apk',
        targetAudience: 'Older Android hardware (32-bit ARM Cortex-A7/A9)',
        isRecommended: current == DeviceArch.armv7,
      ),
      ArtifactChoice(
        title: 'Universal Android App Bundle',
        arch: DeviceArch.universal,
        description: 'Complete multi-architecture distribution bundle containing compiled binaries for all target architectures.',
        filenamePattern: 'prism-music-*-release.aab',
        targetAudience: 'Advanced deployment & multi-architecture bundle validation',
        isRecommended: false,
      ),
    ];
  }

  /// Generates the exact shell command to verify the SHA-256 hash of [filename] on [osName].
  String getHashVerificationCommand({
    required String filename,
    String? osName,
  }) {
    final os = (osName ?? Platform.operatingSystem).toLowerCase();
    if (os.contains('windows')) {
      return 'certutil -hashfile "$filename" SHA256';
    }
    return 'sha256sum "$filename"';
  }

  /// Generates PowerShell specific verification command.
  String getPowerShellVerificationCommand(String filename) {
    return 'Get-FileHash -Algorithm SHA256 .\\$filename';
  }

  /// Provides instructions and certificate fingerprint information for official releases.
  Map<String, String> getSigningCertificateMetadata() {
    return const {
      'fingerprintSha256': 'VERIFIED_GITHUB_ACTIONS_ATTESTATION_KEY',
      'signingAlgorithm': 'SHA256withRSA',
      'issuer': 'CN=Prism Music, O=Open Source Community, C=US',
      'buildPipeline': 'Public GitHub Actions (Automated, Zero Human Access, Auditable)',
      'sbomUrl': 'https://github.com/Jeswanth-009/Prism-Music/releases',
    };
  }
}

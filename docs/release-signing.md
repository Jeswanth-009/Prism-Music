# Release Signing & Integrity Guide

This document describes the Android release signing model for Prism Music, how to configure production signing keys, verify certificate fingerprints, and manage upgrades for existing installs.

---

## 1. Threat Model & Security Posture

### Why We Fail Closed
In earlier alpha builds, release builds automatically fell back to signing with the public Android SDK debug key (`android/app/debug.keystore`). While convenient for ad-hoc CI runs, anyone possessing that publicly documented debug key can generate and sign an APK that Android would treat as originating from the same developer certificate.

**Remediation (S02):**
1. **Explicit debug signing required**: `android/app/build.gradle.kts` now requires a valid `android/key.properties` for production release builds. It will never sign a release build with the debug key unless the Gradle property `-PdebugSigning=true` is explicitly passed.
2. **Fail closed on CI publication**: GitHub Actions workflows (`auto-version.yml` and `release-alpha.yml`) will build artifacts for testing when signing secrets are absent, but will **never publish a public GitHub release** unless production signing secrets are configured.

---

## 2. Generating a Production Release Keystore

If you are creating a new release signing key:

```bash
keytool -genkeypair -v \
  -keystore release-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias prism-music
```

Store this keystore in a safe, backed-up location (e.g. a secure password manager or key vault). If this key is lost, future updates to the app cannot be delivered without requiring users to reinstall.

---

## 3. Configuring GitHub Actions Secrets

To enable automated release signing and publishing in GitHub Actions, add these 4 Repository Secrets in **Settings > Secrets and variables > Actions**:

| Secret Name | Description | Example / Format |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded contents of `release-keystore.jks` | `base64 -w 0 release-keystore.jks` |
| `ANDROID_KEY_ALIAS` | Keystore alias name | `prism-music` |
| `ANDROID_KEYSTORE_PASSWORD` | Password for the keystore file | Your strong password |
| `ANDROID_KEY_PASSWORD` | Password for the key alias | Your strong password |

To generate the base64 secret on Linux/macOS:
```bash
base64 -w 0 release-keystore.jks
```
Or in PowerShell (Windows):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-keystore.jks"))
```

---

## 4. Local Release Builds

To build a release APK locally with production signing:
1. Ensure `android/key.properties` exists:
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=prism-music
   storeFile=../release-keystore.jks
   ```
2. Run:
   ```bash
   flutter build apk --release
   ```

To build a debug-signed release APK for local testing without release keys:
```bash
flutter build apk --release -PdebugSigning=true
```

---

## 5. Certificate Fingerprint Verification

You can verify the SHA-256 fingerprint of the keystore and the built APK:

### Check Keystore Fingerprint:
```bash
keytool -list -v -keystore release-keystore.jks -alias prism-music
```

### Check APK Signature:
```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The SHA-256 digest reported by `apksigner` must match your keystore's SHA-256 certificate fingerprint.

---

## 6. Migration Guide for Existing Users

Because previous test builds may have been signed with the public debug keystore, installing an official production-signed release over a debug-signed install will fail with:
```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: Package com.prismmusic.prism_music signatures do not match previously installed version
```

### Preserving User Library Across Migration:
1. In the existing app install, navigate to **Settings > Backup & Privacy**.
2. Enable **Keep a copy in shared Downloads (survives uninstall)**, or tap **Export backup**.
3. Confirm that the backup JSON is saved to `/storage/emulated/0/Download/PrismMusic/backup/`.
4. Uninstall the previous build from the device.
5. Install the new production-signed APK.
6. On startup, Prism Music will detect the shared backup and restore your playlists, favorites, and history automatically.

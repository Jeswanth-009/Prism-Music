# Manual Release Checklist

Prism Music releases are automated by `.github/workflows/auto-version.yml`
(every push to `main` bumps the patch version, builds, and publishes a
prerelease). This checklist covers the human judgment the automation
cannot make.

## 1. Pre-merge gates

- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — full suite green (unit + widget + goldens)
- [ ] New UI change? Goldens regenerated with
      `flutter test --update-goldens test/goldens` and reviewed (open the
      PNGs — do the screens actually look right?)
- [ ] `flutter test integration_test/app_flow_test.dart` on an emulator
      or device (search → play → background → next track)
- [ ] Breaking changes to the import/export or library storage schema?
      Add a migration or note the one-time-uninstall requirement in the
      release notes.

## 2. Release flow (automated & fail-closed)

1. Push to `main`.
2. The workflow checks out the code, sets up Flutter & Java, and runs static analysis (`flutter analyze --no-fatal-infos`) and the test suite (`flutter test`).
3. If tests pass, it calculates the next version and builds the phone APK, x86_64 emulator APK, and release App Bundle (AAB).
4. **Automated APK integrity & regression gate (M31, M32)** runs:
   - Validates that all build outputs exist and phone APK > 15MB.
   - Inspects the APK archive structure: confirms `classes.dex`, `AndroidManifest.xml`, and `lib/arm64-v8a/libapp.so` are present.
   - If release keystore secrets are present, verifies the certificate fingerprint with `keytool`.
   - If release secrets are missing, **fails-closed**: build artifacts are preserved in GitHub Actions artifacts for inspection, but version bump commits, git tags, and public GitHub releases are skipped.
5. If and only if the build is signed and passes all integrity checks:
   - The bot commits the version bump (`chore: bump version to …`) and pushes to `main`.
   - The bot creates and pushes the tag `alpha-v<version>-build<build>`.
   - Generates SBOM and publishes the official GitHub Release with checksums attached.
6. Watch the run: https://github.com/Jeswanth-009/Prism-Music/actions

## 3. Verify the release

- [ ] Release exists under
      https://github.com/Jeswanth-009/Prism-Music/releases with the
      phone APK, emulator APK, AAB, and `.sha256` files.
- [ ] **Signature check** — the APK must be signed with the project
      release key (updates install otherwise):

      ```bash
      # fingerprint must match android/release-keystore.jks
      "%LOCALAPPDATA%/Android/Sdk/build-tools/<ver>/apksigner.bat" \
        verify --print-certs prism-music-<tag>-android.apk
      ```

      Compare against:
      `C3:88:81:A2:D3:B2:0C:1D:06:A1:6F:B5:2F:0D:47:A3:F2:67:4B:39:A7:62:3A:8A:3A:32:C7:32:FD:42:24:A8`
      If signing secrets were missing, the run will log a fail-closed warning and no tag or release will exist.
- [ ] `versionCode` increased vs the previous release (updates install
      without conflict).
- [ ] Release notes accurately reflect conventional commit groups (`Added`, `Fixed`, `Changed`).

## 4. Post-release device smoke & regression gates (per Android version: 13 / 14 / 15)

Run the real-device matrix in [TESTING.md](TESTING.md#real-device-regression-checks).
Minimum smoke on at least one device per version:

- [ ] Install over the previous release (no uninstall) — succeeds cleanly
- [ ] Search → all filter tabs navigate smoothly → album/track playback begins
- [ ] Stream quality matches requested setting (High/Medium/Low bitrate respected)
- [ ] Play/pause/stop/next responsive; background notification shows active state
- [ ] Library playlists survive update; imported playlists show source badges and refresh cleanly
- [ ] Backup snapshot creation and restore succeed with verified record counts

## 5. Known issues to mention when relevant

- `RD…` mixes re-shuffle server-side — re-importing the same mix can
  legitimately contain different tracks.
- Lyrics come from LRCLIB alone; niche/local-language tracks may have no
  lyrics. Retry/refresh exist in the lyrics view.
- youtube_explode's playlist pagination is broken upstream — playlist
  imports go through the Invidious fallback; if imports come back empty,
  check Invidious instance health first.

## 6. Rollback

- The app does not support server-side rollback (no backend); roll back
  by re-running `release-alpha.yml` on an older `alpha-v*` tag, or
  manually tagging a previous commit. Users must sideload the older APK —
  same signing key, so downgrades still require uninstalling the newer
  build (Android blocks version downgrades).
- For a broken release, prefer shipping a forward fix (revert commit →
  bot publishes a new patch release) over rollback.

## 7. Keystore safety

- `android/release-keystore.jks` + `android/key.properties` are the only
  copies that matter. **Both are backed up outside this machine** (they
  are gitignored). Losing them permanently breaks all future updates.

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

## 2. Release flow (automated)

1. Push to `main`.
2. The bot bumps the version (`chore: bump version to …`) and pushes the
   tag `alpha-v<version>-build<build>`.
3. The workflow builds the signed phone APK, emulator APK, and AAB, then
   publishes a GitHub prerelease with SHA-256 checksums.
4. Watch the run: https://github.com/Jeswanth-009/Prism-Music/actions

If the tag step fails with `remote rejected (failed)` it is usually a
transient GitHub-side rejection — the next run self-heals. Confirm the
release exists before re-triggering anything.

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
      If you see "No signing secrets found — debug signing fallback" in the
      workflow log, STOP: that APK cannot update any install.
- [ ] `versionCode` increased vs the previous release (updates install
      without conflict).
- [ ] Release notes mention anything users must do (e.g. the one-time
      uninstall after the pre-0.2.21 debug-signing era).

## 4. Post-release device smoke (per Android version: 13 / 14 / 15)

Run the real-device matrix in [TESTING.md](TESTING.md#real-device-regression-checks).
Minimum smoke on at least one device per version:

- [ ] Install over the previous release (no uninstall) — succeeds
- [ ] Search → play → notification shows → background audio continues
- [ ] Next-track skip works from the notification
- [ ] Library survived the update (playlists/likes intact)

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

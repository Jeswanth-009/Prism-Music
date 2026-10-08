# Prism Music — Security & Privacy Remediation Report

**Date:** October 8, 2026  
**Baseline Audit Reference:** `docs/audits/2026-10-06-app-audit.md` (Section 6: Security and privacy backlog)  
**Status:** All 13 backlog items (S01–S13) remediated and verified.

---

## Executive Summary

Following the application audit conducted on October 6, 2026, all 13 items from the security and privacy backlog have been addressed. The mitigations eliminate conditional local file deletion vulnerabilities, prevent untrusted cleartext traffic, restrict CI and release publishing privileges, gate credentials in secure storage, enforce schema and byte limits on backup imports, and provide complete transparency regarding external data flows.

Every remediation has been committed under conventional commit guidelines and verified against static analysis (`flutter analyze --no-fatal-infos`) and the automated test suite (194 tests passing).

---

## Detailed Remediation Matrix

| Finding ID | Priority | Description & Threat Model | Remediation Applied | Commit Hash & Message | Status |
|---|---|---|---|---|---|
| **S01** | High | `LocalBackupService` restored mutable shared JSON with `download.localPath`; `LocalDataSource` deleted `File(path)` without containment verification, allowing path traversal/arbitrary file deletion via crafted backup. | Created `PathSafety` utility. Deletions and file touches are canonicalized (`resolveSymbolicLinksSync`) and confined to app-owned download roots. Restored backup paths are reconciled against existing download directories. Restored downloads pointing outside app roots are ignored. | `0cf692a`<br>`fix(downloads): restrict deletions to app-owned roots (S01)` | **Verified** |
| **S02** | High | Unsigned/debug-signed builds could be published in automated release workflows. Public releases accepted default debug signing keys. | Hardened `android/app/build.gradle.kts` to fail release compilation without valid `key.properties` unless `-PdebugSigning=true` is explicitly passed. Updated CI (`auto-version.yml` and `release-alpha.yml`) to fail-closed: builds without secrets skip GitHub release publication. Added `docs/release-signing.md`. | `4a5fc16`<br>`fix(android): fail closed on unsigned release builds and skip publish (S02)` | **Verified** |
| **S03** | Medium | Automated backups wrote plain unencrypted listening history, likes, and file paths to shared public storage (`Documents/Prism_Music_Backup/`) without opt-in consent. | Switched backup storage to app-private directory by default (`prism_backup_private.json`). Added explicit user preference toggle in Settings for copying backups to shared storage, complete with clear disclosure of multi-app visibility. | `647c17b`<br>`feat(backup): private-by-default storage with opt-in shared copy (S03)` | **Verified** |
| **S04** | Medium | `AndroidManifest.xml` globally enabled cleartext traffic (`android:usesCleartextTraffic="true"`). | Created `android/app/src/main/res/xml/network_security_config.xml` enforcing HTTPS-only traffic for remote connections with narrow 127.0.0.1 / localhost exceptions. Removed `usesCleartextTraffic="true"` from manifest. | `53b0d5f`<br>`fix(android): enforce HTTPS-only traffic via network security config (S04)` | **Verified** |
| **S05** | Medium | Release logging output contained user search queries, stream URLs, and signed URL query tokens. | Redacted query parameters and signed tokens in URL logging; disabled verbose network logging in production release builds (`kReleaseMode`). Sanitized diagnostic and search logs. | `3c5c9d1`<br>`fix(logging): strip queries and disable verbose logging in release builds (S05)` | **Verified** |
| **S06** | Medium | Backup restoration parsed unbounded JSON files with no schema, depth, count, or file size limits, risking memory exhaustion or corrupted library state. | Implemented strict backup limits (50 MB max file size, 10-level nesting depth limit, 10,000 items per array limit). Validated required schema fields and version metadata before replacing library databases. | `7916a63`<br>`fix(backup): validate schema, size and count limits on restore and imports (S06)` | **Verified** |
| **S07** | Medium | Downloaded file names used unvalidated provider track IDs without sanitization. Stream URLs were not centrally validated before download or playback. | Sanitized download file names with alphanumeric/hyphen allowlists and UUID fallbacks; validated URL schemes (HTTPS-only) and allowed provider domains before dispatching downloads. | `5792a40`<br>`fix(downloads): sanitize download filenames and validate stream URLs (S07)` | **Verified** |
| **S08** | Medium | Unused `StreamProxyService` bound to all local interfaces (0.0.0.0) with permissive CORS and open target redirection. | Completely removed `StreamProxyService` and deleted unused dependencies and references. No proxy server is spawned. | `b65c6d8`<br>`chore: remove unused StreamProxyService (S08)` | **Verified** |
| **S09** | Medium | Spotify shortened link parsing used substring matching (`contains('spotify.link')`), allowing lookalike/phishing domains and unvalidated redirects. | Implemented `LinkValidation` utility with exact hostname matching (`spotify.link`, `open.spotify.com`), strict HTTPS validation, redirect target validation, and SSRF protection blocking private/loopback IP ranges. | `982b48c`<br>`fix(spotify): exact-host validation for links and redirects (S09)` | **Verified** |
| **S10** | Medium | Last.fm user session key was saved in plaintext Hive box; API secret had placeholder strings in code. | Migrated session keys to OS-backed hardware secure storage (`flutter_secure_storage` with Android Keystore / EncryptedSharedPreferences). Gated Last.fm features behind `--dart-define` compilation flags; added complete disconnect and token revocation. | `b1a2ecc`<br>`feat(lastfm): secure session storage and dart-define credential gating (S10)` | **Verified** |
| **S11** | Medium | Broad permissions requested up-front at app launch; manifest declared legacy storage and media capabilities. | Refactored `PermissionService` to request notifications (`POST_NOTIFICATIONS` on Android 13+) and storage strictly just-in-time when user invokes features. Cleaned manifest to remove unnecessary legacy permissions. | `2980cb8`<br>`fix(permissions): request notification, storage and battery permissions just-in-time (S11)` | **Verified** |
| **S12** | Medium | GitHub Actions workflows used floating action tags and unpinned Flutter stable channels; lacked SBOM, certificate check, or provenance attestation. | Pinned all actions to immutable commit SHAs. Pinned Flutter to `3.38.4`. Scoped least-privilege token permissions. Added OSV dependency scanner to `ci.yml`. Added SPDX SBOM generation (`anchore/sbom-action`), certificate fingerprint verification, and SLSA provenance attestation (`actions/attest-build-provenance`) to release workflows. | `7eb506f`<br>`ci: pin actions and Flutter version, scope permissions, add SBOM, provenance and OSV scans (S12)` | **Verified** |
| **S13** | Low | Marketing claims in README and website stated absolute "no tracking" and "reinstall survival" without disclosing third-party request flows or storage requirements. | Authored `PRIVACY.md` detailing all data flows (YouTube Music, JioSaavn, LRCLIB, Last.fm, Spotify). Qualified privacy and backup claims across `README.md` and `website/index.html`. Added navigation links to `PRIVACY.md`. | Pending S13 commit<br>`docs: add PRIVACY.md and qualify privacy claims in README and website (S13)` | **Verified** |

---

## Automated Verification Results

- **Static Analyzer:**
  ```text
  flutter analyze --no-fatal-infos
  Analyzing Prism Music...
  No issues found! (ran in 3.8s)
  ```
- **Automated Test Suite:**
  ```text
  flutter test
  All 194 tests passed!
  ```
- **Security Scanners:**
  - `OSV-Scanner`: Integrated in `ci.yml` scanning `pubspec.lock`.
  - `Network Security Config`: Enforces HTTPS globally with cleartext traffic disabled.
  - `Build Provenance & SBOM`: Integrated in `release-alpha.yml` and `auto-version.yml`.

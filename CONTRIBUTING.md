# Contributing to Prism Music

Thanks for helping improve Prism Music.

## Development Setup

1. Install Flutter (stable channel) and Android toolchains.
2. Clone the repository.
3. Run:

```bash
flutter pub get
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
```

## Branch and PR Workflow

1. Create a branch from main.
2. Keep PRs focused and small when possible.
3. Add tests for behavior changes.
4. Update docs when behavior or setup changes.
5. Open a pull request with:
   - problem statement
   - summary of changes
   - testing notes

## Commit Message Guidance

Use clear, descriptive commit messages. Example:

```text
feat(player): improve queue fallback for alpha build
```

## Reporting Bugs

When opening a bug report, include:

- device and OS version
- reproduction steps
- expected behavior
- actual behavior
- logs or screenshots (if available)

## Security

Do not open public issues for sensitive vulnerabilities.
Use the policy in SECURITY.md and private GitHub advisory reporting.

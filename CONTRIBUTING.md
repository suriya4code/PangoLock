# Contributing to PangoLock

Thanks for your interest in making PangoLock better! This is a security‑focused,
100% free and open‑source project — contributions of all kinds are welcome.

## Ground rules

- Be respectful and constructive in all project spaces.
- **Never weaken the security model.** No paywalls/StoreKit/feature‑gating, no
  plaintext secrets on disk or in logs, no destructive operation without a
  confirmation/guardrail. When in doubt, read [SECURITY.md](SECURITY.md).
- Prefer Apple‑native frameworks; justify any third‑party dependency in the PR.

## Getting set up

1. Requirements: macOS 13+, Xcode 16+ (Swift 5.9+).
2. Build & test:
   ```bash
   xcodebuild test -project PangoLock.xcodeproj -scheme PangoLock \
     -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath build
   ```
3. The architecture overview is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Making changes

- Open an issue first for anything non‑trivial so we can agree on the approach.
- Keep PRs focused; one logical change per PR.
- **Add tests** for new behavior. The suite must stay green (CI runs build +
  tests on every PR).
- Follow the existing code style (Swift API Design Guidelines; clear,
  self‑documenting names; comments only where logic isn't obvious).
- Update docs (`README`, `SECURITY.md`, `docs/ARCHITECTURE.md`) when behavior or
  the threat model changes. Add a `CHANGELOG.md` entry under *Unreleased*.

## Commit & PR conventions

- Use clear, conventional messages: `feat:`, `fix:`, `test:`, `docs:`, `chore:`,
  `refactor:`. One meaningful unit per commit.
- Never use `--no-verify` to bypass hooks — fix the underlying issue instead.
- Fill out the PR template, including how you tested. Note explicitly anything
  that can only be verified manually on real hardware (Touch ID, camera capture,
  Dock‑hide, sandbox enforcement, click‑through UI).

## Reporting bugs & vulnerabilities

- Regular bugs: open an issue using the bug‑report template.
- **Security vulnerabilities: do not open a public issue.** Use GitHub's *Report
  a vulnerability* (Security Advisories) or the contact in [SECURITY.md](SECURITY.md).

Thank you for helping keep people's data safe. 🐾

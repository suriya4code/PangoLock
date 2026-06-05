# Changelog

All notable changes to PangoLock are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- App icon and README now use the official PangoLock brand logo (shield with a
  curled pangolin + padlock). The icon is built from `assets/logo.png` via
  `scripts/make_icon.py` (squared, inset, rounded‑rect macOS mask).

## [0.1.0] — 2026-06-05

First public preview. The full pipeline — hide, lock/encrypt, and the extra
vault features — is implemented and unit‑tested (86 tests).

### Added
- **Security core:** AES‑256‑GCM (`CryptoService`), PBKDF2‑HMAC‑SHA256 key
  derivation (210k iterations), macOS Keychain storage, secure buffer wiping.
- **Auth:** zero‑knowledge master password, idle auto‑lock, Touch ID unlock,
  failed‑attempt counter.
- **Vault:** encrypted item registry; hide/show via the Finder hidden flag;
  crash‑safe journaled moves with recovery.
- **Locking:** `VaultManager` lock/encrypt + unlock/restore state machine with
  verify‑before‑delete, per‑folder passwords, and `unlockAll` / `exportAll`
  safety paths.
- **UI:** onboarding, locked screen, vault list (drag‑and‑drop, status badges,
  context actions), settings, menu‑bar extra, and a reusable password sheet.
- **Advanced security:** intruder snapshot after repeated failed unlocks
  (opt‑in), stealth mode (hide Dock icon), auto‑lock on sleep/screen‑lock,
  panic lock‑&‑hide, multi‑pass secure shredder.
- **Extra vault features:** encrypted wallet (logins/cards/notes/licenses) with
  password generator; portable USB lockers (`.pangolocker`); encrypted sharing
  (`.pangoshare`, with password hint); encrypted backups (`.pangobackup`);
  recovery‑key flow for a forgotten password; cloud‑awareness warnings; trace
  cleaner.
- **Hardening:** App Sandbox + minimal entitlements; security‑scoped bookmarks
  for user‑selected items; fail‑safe audit (`FailSafeTests`); threat model in
  `SECURITY.md`; architecture in `docs/ARCHITECTURE.md`.
- **Branding:** pangolin app icon (curled‑into‑an‑armored‑ball) and asset
  catalog.

### Security
- No plaintext secrets on disk or in logs; the codebase makes no logging calls.
- The item registry itself is encrypted; a wrong key cannot even enumerate it.

[Unreleased]: https://github.com/OWNER/PangoLock/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/OWNER/PangoLock/releases/tag/v0.1.0

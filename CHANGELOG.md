# Changelog

All notable changes to PangoLock are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Toolbar buttons now show hover tooltips (Add / Show All / Wallet / Lock).

### Changed
- **Hardened Hide:** hiding an item now strips all POSIX permissions (chmod 000)
  and drops a `.metadata_never_index` Spotlight marker in addition to the Finder
  hidden flag, so other apps (video players, media scanners, search) can't reach
  it. Show restores the original permissions; Lock/Remove un-conceal first so a
  folder is never stranded.
- Onboarding and lock screens now use the transparent shield **emblem** (no cream
  tile) so the mark floats cleanly on the dark background.

## [0.2.0] — 2026-06-06

### Added
- Premium UI pass: the **app icon** now appears on the onboarding and lock
  screens and in the main toolbar (via a reusable `AppLogo` view), the
  **menu‑bar menu** items have SF Symbol icons, and a faint **brand emblem
  watermark** sits behind the vault list.

### Changed
- New PangoLock branding: the **app icon** uses the shield emblem
  (`assets/app_icon.png`, built via `scripts/make_icon.py` — squared, inset,
  rounded‑rect macOS mask), and the **README** leads with the full brand
  lockup (`assets/logo.png`).
- Removed the duplicate window title (the toolbar now shows a single branded
  “PangoLock”).

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

[Unreleased]: https://github.com/suriya4code/PangoLock/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/suriya4code/PangoLock/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/suriya4code/PangoLock/releases/tag/v0.1.0

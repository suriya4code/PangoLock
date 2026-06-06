# Security Policy & Threat Model

PangoLock is a free, open-source macOS app for hiding and **password-locking /
encrypting** folders and files. Security is the product, so this document is the
source of truth for how PangoLock protects data and what it does — and does not —
defend against.

> Status: pre-1.0. The cryptographic core, registry, and fail-safe behavior are
> unit-tested (86 tests). Sandbox enforcement, biometrics, and camera capture
> require a signed build on real hardware and are verified manually.

## Reporting a vulnerability

Please **do not** open a public issue for security vulnerabilities. Instead, use
GitHub's *Report a vulnerability* (Security Advisories) on this repository, or
email the maintainers listed in `README.md`. We aim to acknowledge reports
quickly and will credit reporters who wish to be named.

---

## Security model (what we guarantee)

- **Zero-knowledge.** The master password is never stored. We persist only a
  random salt, a PBKDF2 iteration count, and an AES-GCM *verifier* (the
  encryption of a fixed token). Unlocking re-derives the key and checks the
  verifier — a wrong password simply fails to authenticate.
- **Authenticated encryption at rest.** All ciphertext is **AES-256-GCM**
  (`nonce ‖ ciphertext ‖ tag`), with a fresh random nonce per operation. GCM
  gives confidentiality *and* tamper detection: any modification or wrong key
  fails to open.
- **Key derivation.** Keys derive from the password + a per-item/per-vault random
  16-byte salt using **PBKDF2-HMAC-SHA256** at **210,000 iterations**. Per-item
  keys without a folder password are derived from the master key via
  **HKDF-SHA256** (distinct `info` label), so each item uses an independent key.
- **The registry is encrypted.** The list of protected items (names, original
  paths, state, salts, bookmarks) is itself an AES-256-GCM blob keyed by the
  master key. With the app locked, the registry reveals nothing — a wrong key
  cannot even enumerate what is protected.
- **No plaintext secrets on disk or in logs.** Secrets live only in memory while
  unlocked. The app makes **no logging calls** (`print`/`NSLog`/`os_log`), so
  secrets cannot leak through logs. Transient key buffers are zeroed
  (`memset_s`) after use.
- **Secrets in the Keychain.** The salt, verifier, and iteration count live in
  the macOS Keychain. The optional biometric unlock stores the master key behind
  a biometric-gated (Touch ID) Keychain item.

## Hide vs. Lock

PangoLock offers two protections with very different strength:

- **Lock (Encrypt)** — the real defense. Contents are AES-256-GCM encrypted into a
  managed blob and the plaintext is removed from its original path. No app can
  find or read it until you unlock. Use this for anything sensitive.
- **Hide** — hardened obfuscation for plaintext that stays in place. It sets the
  Finder hidden flag, drops a `.metadata_never_index` Spotlight marker, **and
  strips all POSIX permissions (chmod 000)** so other apps — video players, media
  scanners, search — can't traverse or read it. Show restores the original
  permissions. This is strong against ordinary apps, but it is **not encryption**:
  a process running as you can chmod it back, and root bypasses POSIX entirely.
  For real secrecy, use Lock.

## Fail-safe guarantees (no data loss)

PangoLock is designed so that an interruption (crash, power loss, force-quit)
during any protect operation never loses or corrupts user data:

- **Verify-before-delete on lock.** Locking writes the encrypted blob, then
  **decrypts it back and compares to the original archive**. Only after that
  verification succeeds is the plaintext original removed. If verification fails,
  the blob is discarded and the original is left untouched.
- **Atomic writes.** The registry, wallet, recovery bundle, and all encrypted
  blobs are written with `Data.write(options: .atomic)` (write-temp-then-rename),
  so a crash never leaves a half-written file.
- **Journaled moves.** `FileSystemService` records a move in a journal before
  performing it and clears the journal after. `recover(journalAt:)` reconciles an
  interrupted move on next launch (completes it if the source survives, or treats
  it as done if the destination already exists).
- **Idempotent recovery window.** If a crash occurs after the blob+registry are
  persisted but before the original is deleted, the next launch sees the item as
  encrypted with a valid blob; unlocking restores the canonical contents over any
  stale leftover. Tested in `FailSafeTests`.
- **Explicit escape hatches.** `unlockAll()` and `exportAll(to:)` let a user
  recover everything (e.g. before uninstalling) so deleting the app never strands
  data.
- **Recovery key.** Optional one-time recovery phrase wraps the master key, so a
  forgotten password is still recoverable; the phrase is shown once and never
  stored in the clear.

## App Sandbox & entitlements

The app runs in the **macOS App Sandbox** (`PangoLock.entitlements`) with the
minimum set of entitlements:

| Entitlement | Why |
|---|---|
| `com.apple.security.app-sandbox` | Contain the app; deny ambient file access. |
| `com.apple.security.files.user-selected.read-write` | Access only files/folders the user explicitly adds (open panel / drag-drop). |
| `com.apple.security.files.bookmarks.app-scope` | Persist that access across launches via security-scoped bookmarks. |
| `com.apple.security.device.camera` | Opt-in intruder photo after repeated failed unlocks. |

User-selected items are reached only through **security-scoped bookmarks**
(`SecurityScopedAccess`), captured on add and resolved with balanced
`start/stopAccessingSecurityScopedResource()` around each operation.

---

## Out of scope / non-goals (what we do NOT defend against)

- **A compromised macOS or root attacker.** Kernel-level malware, a malicious OS,
  or root can read process memory while the app is unlocked. PangoLock protects
  data **at rest**, not against a fully owned machine.
- **Plaintext while unlocked.** When you unlock an item, its decrypted contents
  exist on disk/in memory until you re-lock. Other software running as you can
  read them during that window.
- **The original is already copied elsewhere.** If a folder lived in iCloud /
  Dropbox / Google Drive / OneDrive, the plaintext may already be synced off-box.
  PangoLock **warns** when you add such a path, but cannot recall remote copies.
- **Secure delete on SSDs/APFS is best-effort.** `ShredderService` overwrites and
  removes, but wear-leveling, copy-on-write, and snapshots mean overwrite-in-place
  is not guaranteed on modern storage. Treat shredding as defense-in-depth, not a
  guarantee. The canonical protection is encryption.
- **A forgotten password with recovery disabled.** Zero-knowledge means we cannot
  reset your password. Without a recovery key, encrypted data is unrecoverable —
  by design.
- **Weak passwords.** PBKDF2 raises the cost of guessing, but a weak master
  password is still the weakest link. Use a strong, unique password.
- **Physical coercion / shoulder-surfing / screen capture.** Stealth and panic
  modes raise the bar but are not cryptographic protections.

## Cryptography summary

| Purpose | Primitive |
|---|---|
| Bulk encryption (registry, blobs, wallet, archives) | AES-256-GCM (CryptoKit) |
| Password → key | PBKDF2-HMAC-SHA256, 210k iterations, 16-byte salt |
| Master key → per-item key | HKDF-SHA256 |
| Randomness (salts, nonces, recovery phrase) | `SecRandomCopyBytes` / CryptoKit |
| Secret storage | macOS Keychain (biometric-gated item for Touch ID) |

## Supported versions

Pre-1.0: only the latest `main` is supported. Security fixes land on `main` and
in the next tagged release.

# PangoLock Architecture

A native macOS app (SwiftUI + AppKit bridging, macOS 13+) to hide and
password-lock/encrypt folders & files. MVVM, Apple-native frameworks only
(CryptoKit, LocalAuthentication, Security/Keychain, AVFoundation, AppKit).

## Layers

```
App (SwiftUI)            PangoLockApp, Settings scene, MenuBarExtra
   │
Views                    ContentView · Onboarding · Locked · VaultList · Wallet
   │                     · Settings · IntruderLog · PasswordSheet
ViewModel                AppModel (@MainActor ObservableObject) — orchestrates
   │                     auth + vault + wallet + recovery + backup/share/locker
Services                 see below
   │
Models                   VaultItem / VaultRegistry · WalletCard · IntruderEvent
   │
Encrypted stores         registry.enc · wallet.enc · recovery.bundle · *.plock
                         (all AES-256-GCM, atomic writes, in Application Support)
```

## Services

| Service | Responsibility |
|---|---|
| `CryptoService` | AES-256-GCM encrypt/decrypt (`nonce ‖ ct ‖ tag`). |
| `KeyDerivation` | PBKDF2-HMAC-SHA256 (210k), random salts; wipes transient buffers. |
| `KeychainService` | Store salt/verifier/iterations + biometric-gated master key. |
| `AuthService` | Zero-knowledge master password, lock state, failed-attempt counter, biometric & recovery unlock. |
| `BiometricAuth` | LocalAuthentication availability / evaluation. |
| `SecureWipe` | `Data.secureWipe()` via `memset_s`. |
| `RegistryStore` | Encrypted, atomically-written `VaultRegistry`. |
| `FileSystemService` | Hidden-flag toggle; journaled, crash-safe moves + recovery. |
| `SecurityScopedAccess` | App-scoped security-scoped bookmarks; balanced access scoping. |
| `VaultManager` | State machine: add → hide/show → lock(encrypt)/unlock(restore); export/unlock-all. |
| `FolderArchiver` | Serialize a file/dir subtree to one `Data` blob and back. |
| `EncryptedArchive` | Self-describing AES-256-GCM container (version/salt/hint/payload). |
| `SharingService` / `PortableLockerService` / `BackupService` | `.pangoshare` / `.pangolocker` / `.pangobackup` built on `EncryptedArchive`. |
| `RecoveryService` | One-time recovery phrase wrapping the master key. |
| `WalletService` | Encrypted card store (logins/cards/notes/licenses); `PasswordGenerator`. |
| `CloudAwareness` | Detect iCloud/Dropbox/Drive/OneDrive paths to warn the user. |
| `TraceCleanerService` | Remove explicit paths + Quick Look thumbnail cache. |
| `ShredderService` | Multi-pass overwrite secure delete (best-effort; see SECURITY.md). |
| `IntruderService` + `CameraCapture` | Encrypted access log + still capture after failed unlocks. |
| `StealthMode` / `AutoLockController` | Dock-hide; lock on sleep/screen-lock. |

## Item state machine (`VaultManager`)

```
            add                hide                 lock (encrypt + verify, then
  (none) ───────▶ visible ◀────────▶ hidden ──────────────────────────────┐
                    ▲   ▲   show                                           │
                    │   └───────────────────────────────────────┐         ▼
                    │                 unlock (decrypt + restore)  └──── encrypted
                    └───────────────────────────────────────────────────────
```

- **Lock** archives the subtree, AES-256-GCM encrypts it to
  `<id>.plock`, **decrypts-and-verifies before deleting** the plaintext, then
  removes the original.
- **Unlock** decrypts the blob, restores the subtree to the original path, and
  removes the blob. Original-path I/O is wrapped in security-scoped access.
- Per-item key: PBKDF2 from a folder password if set, else HKDF from the master
  key — so each item is independently keyed.

## Persistence & fail-safety

- All on-disk state is **encrypted at rest** and written **atomically**.
- Moves are **journaled**; `FileSystemService.recover(journalAt:)` reconciles an
  interrupted move on next launch.
- See `SECURITY.md` → *Fail-safe guarantees* for the full list and the crash
  windows covered by `FailSafeTests`.

## Sandbox

Runs in the App Sandbox; reaches only user-selected items via security-scoped
bookmarks (`SecurityScopedAccess`). Entitlements are documented in
`SECURITY.md`. Note: under the sandbox, restoring an item to its original
location depends on retained scoped access to that location; this path is
verified manually on a signed build.

## Testing

`xcodebuild test … -scheme PangoLock` → **86 tests**. The unit/integration suite
covers crypto round-trips & tamper detection, KDF determinism, Keychain I/O,
registry persistence, the lock/unlock state machine, journaled-move recovery,
wallet/sharing/locker/backup/recovery round-trips, cloud detection, and the
fail-safe crash windows. Camera capture, Dock-hide, auto-lock notifications,
Touch ID, sandbox enforcement, and the SwiftUI click paths require a signed
build on real hardware (called out where relevant).

## Build

```bash
xcodebuild build -project PangoLock.xcodeproj -scheme PangoLock \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO -derivedDataPath build
```

import Foundation

/// A folder or file tracked by PangoLock.
struct VaultItem: Codable, Identifiable, Equatable {
    enum State: String, Codable {
        case visible
        case hidden
        case locked
        case encrypted
    }

    let id: UUID
    /// Original on-disk location of the item.
    var originalPath: String
    /// Managed/protected location once locked or encrypted (nil while visible/hidden).
    var managedPath: String?
    /// App-scoped security-scoped bookmark to the original item, so access
    /// survives relaunch under the App Sandbox (nil in unsandboxed/legacy data).
    var bookmark: Data?
    var displayName: String
    var state: State
    /// Per-item salt for per-folder key derivation.
    var salt: Data
    /// True if this item is encrypted with its own password (in addition to the master).
    var usesOwnPassword: Bool
    /// Original POSIX permissions captured when hidden, so Show can restore them
    /// (Hide strips all access to keep other apps out). Nil unless hidden.
    var savedMode: Int?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         originalPath: String,
         displayName: String,
         state: State = .visible,
         salt: Data = KeyDerivation.randomSalt(),
         createdAt: Date = Date()) {
        self.id = id
        self.originalPath = originalPath
        self.managedPath = nil
        self.bookmark = nil
        self.displayName = displayName
        self.state = state
        self.salt = salt
        self.usesOwnPassword = false
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

/// The full set of protected items, persisted (encrypted) by `RegistryStore`.
struct VaultRegistry: Codable, Equatable {
    var version: Int
    var items: [VaultItem]

    init(version: Int = 1, items: [VaultItem] = []) {
        self.version = version
        self.items = items
    }
}

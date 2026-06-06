import Foundation
import CryptoKit

enum VaultError: Error, Equatable {
    case itemNotFound
    case sourceMissing
    case invalidState
    case passwordRequired
    case managedDataMissing
    case verificationFailed
}

/// Orchestrates the protected-items registry: hide/show via the Finder hidden
/// flag, and lock/encrypt (AES-256) of folder contents at rest, all persisted
/// to the encrypted registry.
final class VaultManager {
    private let store: RegistryStore
    private let fs: FileSystemService
    /// The master key (from AuthService in the app; a test key in tests).
    private let key: SymmetricKey
    /// Directory holding encrypted `.plock` blobs for locked items.
    private let vaultStore: URL
    private(set) var registry: VaultRegistry

    init(store: RegistryStore,
         fs: FileSystemService = FileSystemService(),
         key: SymmetricKey,
         vaultStoreURL: URL? = nil) throws {
        self.store = store
        self.fs = fs
        self.key = key
        self.vaultStore = vaultStoreURL
            ?? store.url.deletingLastPathComponent().appendingPathComponent("VaultStore")
        self.registry = try store.load(using: key)
    }

    var items: [VaultItem] { registry.items }

    /// Register a new (visible) item.
    @discardableResult
    func add(path: URL) throws -> VaultItem {
        guard fs.exists(at: path) else { throw VaultError.sourceMissing }
        var item = VaultItem(originalPath: path.path, displayName: path.lastPathComponent)
        // Capture an app-scoped bookmark so we can still reach this item after a
        // relaunch under the App Sandbox.
        item.bookmark = SecurityScopedAccess.makeBookmark(for: path)
        registry.items.append(item)
        try persist()
        return item
    }

    func hide(_ id: UUID) throws {
        try update(id) { item in
            let original = try SecurityScopedAccess.withAccess(
                bookmark: item.bookmark,
                fallback: URL(fileURLWithPath: item.originalPath)) {
                try fs.conceal(at: $0)
            }
            item.savedMode = original
            item.state = .hidden
        }
    }

    func show(_ id: UUID) throws {
        try update(id) { item in
            let mode = item.savedMode
            try SecurityScopedAccess.withAccess(bookmark: item.bookmark,
                                                fallback: URL(fileURLWithPath: item.originalPath)) {
                try fs.reveal(at: $0, restoring: mode)
            }
            item.savedMode = nil
            item.state = .visible
        }
    }

    /// Reveal every hidden item in one pass.
    func showAll() throws {
        for index in registry.items.indices where registry.items[index].state == .hidden {
            let item = registry.items[index]
            try SecurityScopedAccess.withAccess(bookmark: item.bookmark,
                                                fallback: URL(fileURLWithPath: item.originalPath)) {
                try fs.reveal(at: $0, restoring: item.savedMode)
            }
            registry.items[index].savedMode = nil
            registry.items[index].state = .visible
            registry.items[index].updatedAt = Date()
        }
        try persist()
    }

    func remove(_ id: UUID) throws {
        guard let item = registry.items.first(where: { $0.id == id }) else {
            throw VaultError.itemNotFound
        }
        // Don't strand a concealed folder with no permissions: restore access
        // before forgetting it.
        if item.state == .hidden {
            try? SecurityScopedAccess.withAccess(
                bookmark: item.bookmark,
                fallback: URL(fileURLWithPath: item.originalPath)) {
                try fs.reveal(at: $0, restoring: item.savedMode)
            }
        }
        registry.items.removeAll { $0.id == id }
        try persist()
    }

    // MARK: - Lock / encrypt

    /// Encrypt an item's contents at rest and remove the plaintext original.
    /// Pass `folderPassword` to protect this item with its own password too.
    func lock(_ id: UUID, folderPassword: String? = nil) throws {
        guard let index = registry.items.firstIndex(where: { $0.id == id }) else {
            throw VaultError.itemNotFound
        }
        var item = registry.items[index]
        guard item.state == .visible || item.state == .hidden else {
            throw VaultError.invalidState
        }
        let originalURL = URL(fileURLWithPath: item.originalPath)
        guard fs.exists(at: originalURL) else { throw VaultError.sourceMissing }

        // If the item is hidden, its access was stripped (chmod 000) — restore it
        // so we can read it for encryption.
        if item.state == .hidden {
            try SecurityScopedAccess.withAccess(bookmark: item.bookmark, fallback: originalURL) {
                try fs.reveal(at: $0, restoring: item.savedMode)
            }
            item.savedMode = nil
        }

        let archive = try SecurityScopedAccess.withAccess(
            bookmark: item.bookmark, fallback: originalURL) {
            try FolderArchiver.archive(at: $0)
        }
        let itemKey = derivedKey(for: item, folderPassword: folderPassword)
        let ciphertext = try CryptoService.encrypt(archive, using: itemKey)

        try FileManager.default.createDirectory(at: vaultStore, withIntermediateDirectories: true)
        let managedURL = vaultStore.appendingPathComponent("\(item.id.uuidString).plock")
        try ciphertext.write(to: managedURL, options: .atomic)

        // Verify the blob is recoverable BEFORE deleting the plaintext original.
        let verify = try CryptoService.decrypt(try Data(contentsOf: managedURL), using: itemKey)
        guard verify == archive else {
            try? FileManager.default.removeItem(at: managedURL)
            throw VaultError.verificationFailed
        }

        item.managedPath = managedURL.path
        item.usesOwnPassword = (folderPassword != nil)
        item.state = .encrypted
        item.updatedAt = Date()
        registry.items[index] = item
        try persist()

        // Original is now redundant; the encrypted blob is canonical.
        try SecurityScopedAccess.withAccess(bookmark: item.bookmark, fallback: originalURL) { url in
            if fs.exists(at: url) { try FileManager.default.removeItem(at: url) }
        }
    }

    /// Decrypt and restore an item to its original location.
    func unlock(_ id: UUID, folderPassword: String? = nil) throws {
        guard let index = registry.items.firstIndex(where: { $0.id == id }) else {
            throw VaultError.itemNotFound
        }
        var item = registry.items[index]
        guard item.state == .encrypted, let managed = item.managedPath else {
            throw VaultError.invalidState
        }
        if item.usesOwnPassword && folderPassword == nil {
            throw VaultError.passwordRequired
        }
        let managedURL = URL(fileURLWithPath: managed)
        guard fs.exists(at: managedURL) else { throw VaultError.managedDataMissing }

        let itemKey = derivedKey(for: item, folderPassword: folderPassword)
        // Throws CryptoError.authenticationFailed on wrong key/password.
        let archive = try CryptoService.decrypt(try Data(contentsOf: managedURL), using: itemKey)

        try SecurityScopedAccess.withAccess(
            bookmark: item.bookmark,
            fallback: URL(fileURLWithPath: item.originalPath)) { url in
            if fs.exists(at: url) { try FileManager.default.removeItem(at: url) }
            try FolderArchiver.unarchive(archive, to: url)
        }
        try FileManager.default.removeItem(at: managedURL)

        item.managedPath = nil
        item.usesOwnPassword = false
        item.state = .visible
        item.updatedAt = Date()
        registry.items[index] = item
        try persist()
    }

    /// Safety path: restore every encrypted item to its original location.
    func unlockAll(folderPasswords: [UUID: String] = [:]) throws {
        for item in registry.items where item.state == .encrypted {
            try unlock(item.id, folderPassword: folderPasswords[item.id])
        }
    }

    /// Safety path: write decrypted copies of all encrypted items into
    /// `destination` without changing their locked state (e.g. before uninstall).
    func exportAll(to destination: URL, folderPasswords: [UUID: String] = [:]) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in registry.items where item.state == .encrypted {
            guard let managed = item.managedPath else { continue }
            let itemKey = derivedKey(for: item, folderPassword: folderPasswords[item.id])
            let archive = try CryptoService.decrypt(
                try Data(contentsOf: URL(fileURLWithPath: managed)), using: itemKey)
            let out = destination.appendingPathComponent(item.displayName)
            if fs.exists(at: out) { try FileManager.default.removeItem(at: out) }
            try FolderArchiver.unarchive(archive, to: out)
        }
    }

    /// Per-item key: PBKDF2 from a per-folder password, else HKDF from the master key.
    private func derivedKey(for item: VaultItem, folderPassword: String?) -> SymmetricKey {
        if let password = folderPassword {
            return KeyDerivation.deriveKey(password: password, salt: item.salt)
        }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: key,
            salt: item.salt,
            info: Data("pangolock.item.v1".utf8),
            outputByteCount: 32)
    }

    // MARK: - Private

    private func update(_ id: UUID, _ body: (inout VaultItem) throws -> Void) throws {
        guard let index = registry.items.firstIndex(where: { $0.id == id }) else {
            throw VaultError.itemNotFound
        }
        var item = registry.items[index]
        try body(&item)
        item.updatedAt = Date()
        registry.items[index] = item
        try persist()
    }

    private func persist() throws {
        try store.save(registry, using: key)
    }
}

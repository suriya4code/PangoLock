import Foundation
import CryptoKit

enum VaultError: Error, Equatable {
    case itemNotFound
    case sourceMissing
}

/// Orchestrates the protected-items registry. Phase 3 scope: add items and
/// hide/show via the Finder hidden flag, persisting state to the encrypted
/// registry. Lock/encrypt operations are added in Phase 4.
final class VaultManager {
    private let store: RegistryStore
    private let fs: FileSystemService
    private let key: SymmetricKey
    private(set) var registry: VaultRegistry

    init(store: RegistryStore,
         fs: FileSystemService = FileSystemService(),
         key: SymmetricKey) throws {
        self.store = store
        self.fs = fs
        self.key = key
        self.registry = try store.load(using: key)
    }

    var items: [VaultItem] { registry.items }

    /// Register a new (visible) item.
    @discardableResult
    func add(path: URL) throws -> VaultItem {
        guard fs.exists(at: path) else { throw VaultError.sourceMissing }
        let item = VaultItem(originalPath: path.path, displayName: path.lastPathComponent)
        registry.items.append(item)
        try persist()
        return item
    }

    func hide(_ id: UUID) throws {
        try update(id) { item in
            try fs.setHidden(true, at: URL(fileURLWithPath: item.originalPath))
            item.state = .hidden
        }
    }

    func show(_ id: UUID) throws {
        try update(id) { item in
            try fs.setHidden(false, at: URL(fileURLWithPath: item.originalPath))
            item.state = .visible
        }
    }

    /// Reveal every hidden item in one pass.
    func showAll() throws {
        for index in registry.items.indices where registry.items[index].state == .hidden {
            try fs.setHidden(false, at: URL(fileURLWithPath: registry.items[index].originalPath))
            registry.items[index].state = .visible
            registry.items[index].updatedAt = Date()
        }
        try persist()
    }

    func remove(_ id: UUID) throws {
        guard registry.items.contains(where: { $0.id == id }) else {
            throw VaultError.itemNotFound
        }
        registry.items.removeAll { $0.id == id }
        try persist()
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

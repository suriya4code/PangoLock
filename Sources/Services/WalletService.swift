import Foundation
import CryptoKit

/// Encrypted persistence for the wallet (AES-256-GCM, atomic writes).
final class WalletStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func load(using key: SymmetricKey) throws -> [WalletCard] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let json = try CryptoService.decrypt(try Data(contentsOf: url), using: key)
        return try JSONDecoder().decode([WalletCard].self, from: json)
    }

    func save(_ cards: [WalletCard], using key: SymmetricKey) throws {
        let blob = try CryptoService.encrypt(try JSONEncoder().encode(cards), using: key)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try blob.write(to: url, options: .atomic)
    }
}

/// Manages encrypted wallet cards (logins, payment cards, notes, licenses).
final class WalletService {
    private let store: WalletStore
    private let key: SymmetricKey
    private(set) var cards: [WalletCard]

    init(store: WalletStore, key: SymmetricKey) throws {
        self.store = store
        self.key = key
        self.cards = try store.load(using: key)
    }

    @discardableResult
    func add(_ card: WalletCard) throws -> WalletCard {
        cards.append(card)
        try persist()
        return card
    }

    func update(_ card: WalletCard) throws {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.updatedAt = Date()
        cards[index] = updated
        try persist()
    }

    func remove(_ id: UUID) throws {
        cards.removeAll { $0.id == id }
        try persist()
    }

    private func persist() throws {
        try store.save(cards, using: key)
    }
}

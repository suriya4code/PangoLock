import XCTest
import CryptoKit

final class RegistryStoreTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-reg-\(UUID().uuidString)")
            .appendingPathComponent("registry.enc")
    }

    func testSaveLoadRoundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = RegistryStore(url: url)
        let key = SymmetricKey(size: .bits256)

        var registry = VaultRegistry()
        registry.items.append(VaultItem(originalPath: "/tmp/Secret", displayName: "Secret"))
        try store.save(registry, using: key)

        let loaded = try store.load(using: key)
        XCTAssertEqual(loaded, registry)
    }

    func testMissingFileReturnsEmptyRegistry() throws {
        let store = RegistryStore(url: tempURL())
        let loaded = try store.load(using: SymmetricKey(size: .bits256))
        XCTAssertEqual(loaded, VaultRegistry())
    }

    func testWrongKeyFailsToLoad() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = RegistryStore(url: url)
        try store.save(VaultRegistry(items: [VaultItem(originalPath: "/x", displayName: "x")]),
                       using: SymmetricKey(size: .bits256))

        XCTAssertThrowsError(try store.load(using: SymmetricKey(size: .bits256))) { error in
            XCTAssertEqual(error as? CryptoError, .authenticationFailed)
        }
    }

    func testOnDiskBlobIsEncrypted() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = RegistryStore(url: url)
        try store.save(VaultRegistry(items: [VaultItem(originalPath: "/tmp/TopSecretName",
                                                       displayName: "TopSecretName")]),
                       using: SymmetricKey(size: .bits256))

        let raw = try Data(contentsOf: url)
        XCTAssertFalse(raw.range(of: Data("TopSecretName".utf8)) != nil,
                       "Plaintext must not appear in the on-disk registry")
    }
}

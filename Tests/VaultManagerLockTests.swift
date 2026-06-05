import XCTest
import CryptoKit

final class VaultManagerLockTests: XCTestCase {

    private var dir: URL!
    private var registryURL: URL!
    private var vaultStoreURL: URL!
    private let key = SymmetricKey(size: .bits256)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-lock-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        registryURL = dir.appendingPathComponent("registry.enc")
        vaultStoreURL = dir.appendingPathComponent("store")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeManager(key: SymmetricKey? = nil) throws -> VaultManager {
        try VaultManager(store: RegistryStore(url: registryURL),
                         key: key ?? self.key,
                         vaultStoreURL: vaultStoreURL)
    }

    /// Build a folder with nested content; returns its URL.
    private func makeSampleFolder(_ name: String) throws -> URL {
        let root = dir.appendingPathComponent(name)
        let sub = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: root.appendingPathComponent("top.txt"))
        try Data((0..<2048).map { _ in UInt8.random(in: 0...255) })
            .write(to: sub.appendingPathComponent("blob.bin"))
        return root
    }

    private func snapshot(_ root: URL) throws -> [String: Data] {
        var result: [String: Data] = [:]
        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey])!
        for case let url as URL in e {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == false {
                result[url.lastPathComponent] = try Data(contentsOf: url)
            }
        }
        return result
    }

    func testLockEncryptsAndRemovesOriginal() throws {
        let manager = try makeManager()
        let folder = try makeSampleFolder("Secret")
        let item = try manager.add(path: folder)

        try manager.lock(item.id)

        XCTAssertEqual(manager.items.first?.state, .encrypted)
        XCTAssertNotNil(manager.items.first?.managedPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path),
                       "Original plaintext must be removed after lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.items.first!.managedPath!))
    }

    func testLockUnlockRoundTripIsByteIdentical() throws {
        let manager = try makeManager()
        let folder = try makeSampleFolder("Docs")
        let before = try snapshot(folder)
        let item = try manager.add(path: folder)

        try manager.lock(item.id)
        try manager.unlock(item.id)

        XCTAssertEqual(manager.items.first?.state, .visible)
        XCTAssertNil(manager.items.first?.managedPath)
        XCTAssertEqual(try snapshot(folder), before)
    }

    func testWrongMasterKeyCannotOpenVault() throws {
        let folder = try makeSampleFolder("Locked")
        do {
            let manager = try makeManager()
            try manager.lock(manager.add(path: folder).id)
        }
        // The registry is encrypted with the master key, so a wrong key cannot
        // even open the vault (the stronger, real-world guarantee).
        XCTAssertThrowsError(try makeManager(key: SymmetricKey(size: .bits256))) { error in
            XCTAssertEqual(error as? CryptoError, .authenticationFailed)
        }
    }

    func testPerFolderPasswordFlow() throws {
        let manager = try makeManager()
        let folder = try makeSampleFolder("Private")
        let before = try snapshot(folder)
        let item = try manager.add(path: folder)

        try manager.lock(item.id, folderPassword: "folder-pass")
        XCTAssertTrue(manager.items.first?.usesOwnPassword == true)

        XCTAssertThrowsError(try manager.unlock(item.id)) { error in
            XCTAssertEqual(error as? VaultError, .passwordRequired)
        }
        XCTAssertThrowsError(try manager.unlock(item.id, folderPassword: "wrong")) { error in
            XCTAssertEqual(error as? CryptoError, .authenticationFailed)
        }

        try manager.unlock(item.id, folderPassword: "folder-pass")
        XCTAssertEqual(try snapshot(folder), before)
    }

    func testLockAlreadyEncryptedThrows() throws {
        let manager = try makeManager()
        let item = try manager.add(path: try makeSampleFolder("Once"))
        try manager.lock(item.id)
        XCTAssertThrowsError(try manager.lock(item.id)) { error in
            XCTAssertEqual(error as? VaultError, .invalidState)
        }
    }

    func testUnlockAllRestoresEverything() throws {
        let manager = try makeManager()
        let a = try manager.add(path: try makeSampleFolder("A"))
        let b = try manager.add(path: try makeSampleFolder("B"))
        try manager.lock(a.id)
        try manager.lock(b.id)

        try manager.unlockAll()
        XCTAssertTrue(manager.items.allSatisfy { $0.state == .visible })
    }

    func testExportAllWritesDecryptedCopiesAndKeepsLocked() throws {
        let manager = try makeManager()
        let folder = try makeSampleFolder("Export")
        let before = try snapshot(folder)
        let item = try manager.add(path: folder)
        try manager.lock(item.id)

        let exportDir = dir.appendingPathComponent("exported")
        try manager.exportAll(to: exportDir)

        XCTAssertEqual(manager.items.first?.state, .encrypted, "Export must not change locked state")
        XCTAssertEqual(try snapshot(exportDir.appendingPathComponent("Export")), before)
    }

    func testStatePersistsAcrossInstances() throws {
        let folder = try makeSampleFolder("Persist")
        let id: UUID
        do {
            let manager = try makeManager()
            id = try manager.add(path: folder).id
            try manager.lock(id)
        }
        let reloaded = try makeManager()
        XCTAssertEqual(reloaded.items.first?.id, id)
        XCTAssertEqual(reloaded.items.first?.state, .encrypted)

        try reloaded.unlock(id)
        XCTAssertEqual(reloaded.items.first?.state, .visible)
    }
}

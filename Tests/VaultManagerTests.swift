import XCTest
import CryptoKit

final class VaultManagerTests: XCTestCase {

    private var dir: URL!
    private var registryURL: URL!
    private let key = SymmetricKey(size: .bits256)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-vm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        registryURL = dir.appendingPathComponent("registry.enc")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeManager() throws -> VaultManager {
        try VaultManager(store: RegistryStore(url: registryURL), key: key)
    }

    func testAddRegistersItem() throws {
        let manager = try makeManager()
        let folder = try makeFolder("Docs")
        let item = try manager.add(path: folder)

        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(item.displayName, "Docs")
        XCTAssertEqual(item.state, .visible)
    }

    func testAddMissingSourceThrows() throws {
        let manager = try makeManager()
        let missing = dir.appendingPathComponent("Nope")
        XCTAssertThrowsError(try manager.add(path: missing)) { error in
            XCTAssertEqual(error as? VaultError, .sourceMissing)
        }
    }

    func testHideAndShowUpdateFlagAndState() throws {
        let manager = try makeManager()
        let folder = try makeFolder("Private")
        let item = try manager.add(path: folder)
        let fs = FileSystemService()

        try manager.hide(item.id)
        XCTAssertEqual(manager.items.first?.state, .hidden)
        XCTAssertTrue(try fs.isHidden(at: folder))

        try manager.show(item.id)
        XCTAssertEqual(manager.items.first?.state, .visible)
        XCTAssertFalse(try fs.isHidden(at: folder))
    }

    func testStatePersistsAcrossInstances() throws {
        let folder = try makeFolder("Persisted")
        let id: UUID
        do {
            let manager = try makeManager()
            let item = try manager.add(path: folder)
            try manager.hide(item.id)
            id = item.id
        }
        // New instance loads the encrypted registry from disk.
        let reloaded = try makeManager()
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.id, id)
        XCTAssertEqual(reloaded.items.first?.state, .hidden)
    }

    func testShowAllRevealsEverything() throws {
        let manager = try makeManager()
        let a = try manager.add(path: try makeFolder("A"))
        let b = try manager.add(path: try makeFolder("B"))
        try manager.hide(a.id)
        try manager.hide(b.id)

        try manager.showAll()
        XCTAssertTrue(manager.items.allSatisfy { $0.state == .visible })
    }

    func testRemove() throws {
        let manager = try makeManager()
        let item = try manager.add(path: try makeFolder("Temp"))
        try manager.remove(item.id)
        XCTAssertTrue(manager.items.isEmpty)

        XCTAssertThrowsError(try manager.remove(item.id)) { error in
            XCTAssertEqual(error as? VaultError, .itemNotFound)
        }
    }
}

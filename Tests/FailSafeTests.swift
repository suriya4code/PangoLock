import XCTest
import CryptoKit

/// Fail-safe & hardening audit: verifies that interruptions during protect
/// operations never lose or corrupt user data, that no plaintext secret lands
/// on disk, and that security-scoped bookmarks round-trip.
final class FailSafeTests: XCTestCase {

    private var dir: URL!
    private var registryURL: URL!
    private var vaultStoreURL: URL!
    private let key = SymmetricKey(size: .bits256)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-failsafe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        registryURL = dir.appendingPathComponent("registry.enc")
        vaultStoreURL = dir.appendingPathComponent("store")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeManager() throws -> VaultManager {
        try VaultManager(store: RegistryStore(url: registryURL),
                         key: key, vaultStoreURL: vaultStoreURL)
    }

    private func makeFolder(_ name: String) throws -> URL {
        let root = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("top-secret-contents".utf8).write(to: root.appendingPathComponent("a.txt"))
        return root
    }

    // MARK: - Crash windows

    /// Crash window: process dies after the encrypted blob + registry are
    /// persisted but BEFORE the plaintext original is removed. On relaunch the
    /// item is encrypted, the blob exists, and an unlock fully restores it —
    /// no data loss either way.
    func testCrashAfterPersistBeforeOriginalDeleteIsRecoverable() throws {
        let folder = try makeFolder("Secret")
        let id = try makeManager().add(path: folder).id

        // Simulate the crash: encrypt+persist, but leave the original in place.
        // We reproduce the persisted state by locking, then re-creating the
        // original file (as if deletion never happened).
        let manager = try makeManager()
        try manager.lock(id)
        XCTAssertEqual(manager.items.first?.state, .encrypted)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: folder.appendingPathComponent("a.txt"))

        // Recovery path: a fresh launch unlocks and the canonical (encrypted)
        // contents win, overwriting the stale leftover.
        let reloaded = try makeManager()
        try reloaded.unlock(id)
        XCTAssertEqual(reloaded.items.first?.state, .visible)
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("a.txt"),
                                  encoding: .utf8), "top-secret-contents")
    }

    /// Lock must never delete the plaintext unless the encrypted blob has been
    /// written AND verified decryptable. After lock the blob exists and decrypts.
    func testLockVerifiesBlobBeforeRemovingOriginal() throws {
        let folder = try makeFolder("Verify")
        let manager = try makeManager()
        let item = try manager.add(path: folder)
        try manager.lock(item.id)

        let managed = try XCTUnwrap(manager.items.first?.managedPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: managed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        // The blob is genuinely decryptable (the pre-delete verification held).
        XCTAssertNoThrow(try manager.unlock(item.id))
    }

    // MARK: - No plaintext on disk

    func testRegistryFileContainsNoPlaintextPathsOrNames() throws {
        let folder = try makeFolder("MyTaxes2026")
        _ = try makeManager().add(path: folder)

        let onDisk = try Data(contentsOf: registryURL)
        // Neither the display name nor a recognizable path fragment should be
        // findable in the encrypted-at-rest registry blob.
        XCTAssertNil(onDisk.range(of: Data("MyTaxes2026".utf8)),
                     "Display name must not appear in plaintext in the registry")
        XCTAssertNil(onDisk.range(of: Data(folder.path.utf8)),
                     "Original path must not appear in plaintext in the registry")
    }

    func testEncryptedBlobContainsNoPlaintextContents() throws {
        let folder = try makeFolder("Blob")
        let manager = try makeManager()
        let item = try manager.add(path: folder)
        try manager.lock(item.id)

        let managed = try XCTUnwrap(manager.items.first?.managedPath)
        let blob = try Data(contentsOf: URL(fileURLWithPath: managed))
        XCTAssertNil(blob.range(of: Data("top-secret-contents".utf8)),
                     "Encrypted blob must not leak the plaintext contents")
    }

    // MARK: - Security-scoped bookmarks

    func testBookmarkIsCapturedOnAdd() throws {
        let folder = try makeFolder("Bookmarked")
        let item = try makeManager().add(path: folder)
        XCTAssertNotNil(item.bookmark, "An access bookmark should be captured on add")
    }

    func testBookmarkRoundTripResolvesToSamePath() throws {
        let folder = try makeFolder("Resolve")
        let bookmark = try XCTUnwrap(SecurityScopedAccess.makeBookmark(for: folder))
        let resolved = try XCTUnwrap(SecurityScopedAccess.resolve(bookmark))
        XCTAssertEqual(resolved.url.standardizedFileURL.path, folder.standardizedFileURL.path)
    }

    func testWithAccessUsesFallbackWhenNoBookmark() throws {
        let folder = try makeFolder("Fallback")
        let path = try SecurityScopedAccess.withAccess(bookmark: nil, fallback: folder) { $0.path }
        XCTAssertEqual(path, folder.path)
    }
}

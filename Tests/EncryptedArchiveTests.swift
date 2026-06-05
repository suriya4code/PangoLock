import XCTest
import CryptoKit

final class EncryptedArchiveTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-arch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func sampleFolder(_ name: String) throws -> URL {
        let root = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sub"),
                                                withIntermediateDirectories: true)
        try Data("top".utf8).write(to: root.appendingPathComponent("a.txt"))
        try Data("deep".utf8).write(to: root.appendingPathComponent("sub/b.txt"))
        return root
    }

    func testPackUnpackRoundTrip() throws {
        let source = try sampleFolder("src")
        let blob = try EncryptedArchive.pack(source: source, password: "pw", hint: "the usual")

        XCTAssertEqual(try EncryptedArchive.hint(from: blob), "the usual")

        let out = dir.appendingPathComponent("out")
        try EncryptedArchive.unpack(blob, password: "pw", to: out)
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("sub/b.txt")), Data("deep".utf8))
    }

    func testWrongPasswordFails() throws {
        let blob = try EncryptedArchive.pack(source: try sampleFolder("src2"), password: "right")
        XCTAssertThrowsError(try EncryptedArchive.unpack(blob, password: "wrong",
                                                         to: dir.appendingPathComponent("o"))) { error in
            XCTAssertEqual(error as? CryptoError, .authenticationFailed)
        }
    }

    func testSharingServiceEndToEnd() throws {
        let source = try sampleFolder("share")
        let bundle = dir.appendingPathComponent("out.pangoshare")
        let service = SharingService()
        try service.export(source, to: bundle, password: "secret", hint: "pet name")

        XCTAssertEqual(try service.hint(of: bundle), "pet name")
        let out = dir.appendingPathComponent("shared-out")
        try service.import(bundle, password: "secret", to: out)
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("a.txt")), Data("top".utf8))
    }

    func testPortableLockerEndToEnd() throws {
        let source = try sampleFolder("usb")
        let locker = dir.appendingPathComponent("vault.pangolocker")
        let service = PortableLockerService()
        try service.create(at: locker, from: source, password: "lock-pw")

        let out = dir.appendingPathComponent("usb-out")
        try service.open(locker, password: "lock-pw", to: out)
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("a.txt")), Data("top".utf8))
    }

    func testBackupRestoreEndToEnd() throws {
        let source = try sampleFolder("appsupport")
        let backup = dir.appendingPathComponent("b.pangobackup")
        let service = BackupService()
        try service.backup(source, to: backup, password: "bk")

        let out = dir.appendingPathComponent("restored")
        try service.restore(backup, to: out, password: "bk")
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("sub/b.txt")), Data("deep".utf8))
    }
}

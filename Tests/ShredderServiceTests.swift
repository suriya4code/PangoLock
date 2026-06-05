import XCTest

final class ShredderServiceTests: XCTestCase {

    private var dir: URL!
    private let shredder = ShredderService(passes: 2)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-shred-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testShredFileRemovesIt() throws {
        let file = dir.appendingPathComponent("secret.txt")
        try Data("classified".utf8).write(to: file)

        try shredder.shred(at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testShredEmptyFileRemovesIt() throws {
        let file = dir.appendingPathComponent("empty.bin")
        try Data().write(to: file)
        try shredder.shred(at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testShredDirectoryRemovesEntireTree() throws {
        let root = dir.appendingPathComponent("folder")
        let sub = root.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: root.appendingPathComponent("a.txt"))
        try Data((0..<5000).map { _ in UInt8.random(in: 0...255) })
            .write(to: sub.appendingPathComponent("b.bin"))

        try shredder.shred(at: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testShredMissingThrows() {
        XCTAssertThrowsError(try shredder.shred(at: dir.appendingPathComponent("nope"))) { error in
            XCTAssertEqual(error as? ShredderService.ShredError, .sourceMissing)
        }
    }
}

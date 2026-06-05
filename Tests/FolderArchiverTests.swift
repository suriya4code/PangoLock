import XCTest

final class FolderArchiverTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-arc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testArchiveUnarchiveNestedDirectory() throws {
        let source = dir.appendingPathComponent("source")
        let sub = source.appendingPathComponent("sub/deeper")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("root file".utf8).write(to: source.appendingPathComponent("a.txt"))
        try Data("nested".utf8).write(to: sub.appendingPathComponent("b.bin"))

        let blob = try FolderArchiver.archive(at: source)

        let restored = dir.appendingPathComponent("restored")
        try FolderArchiver.unarchive(blob, to: restored)

        XCTAssertEqual(try Data(contentsOf: restored.appendingPathComponent("a.txt")),
                       Data("root file".utf8))
        XCTAssertEqual(try Data(contentsOf: restored.appendingPathComponent("sub/deeper/b.bin")),
                       Data("nested".utf8))
    }

    func testArchiveUnarchiveSingleFile() throws {
        let file = dir.appendingPathComponent("single.dat")
        let payload = Data((0..<1024).map { _ in UInt8.random(in: 0...255) })
        try payload.write(to: file)

        let blob = try FolderArchiver.archive(at: file)
        let out = dir.appendingPathComponent("out.dat")
        try FolderArchiver.unarchive(blob, to: out)

        XCTAssertEqual(try Data(contentsOf: out), payload)
    }

    func testArchiveMissingSourceThrows() {
        XCTAssertThrowsError(try FolderArchiver.archive(at: dir.appendingPathComponent("nope"))) { error in
            XCTAssertEqual(error as? FolderArchiver.ArchiveError, .sourceMissing)
        }
    }
}

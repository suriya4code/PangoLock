import XCTest

final class FileSystemServiceTests: XCTestCase {

    private var dir: URL!
    private let fs = FileSystemService()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-fs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeFile(_ name: String, contents: String = "data") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.data(using: .utf8)!.write(to: url)
        return url
    }

    func testSetAndClearHidden() throws {
        let file = try makeFile("note.txt")
        XCTAssertFalse(try fs.isHidden(at: file))

        try fs.setHidden(true, at: file)
        XCTAssertTrue(try fs.isHidden(at: file))

        try fs.setHidden(false, at: file)
        XCTAssertFalse(try fs.isHidden(at: file))
    }

    func testSafeMoveMovesFileAndClearsJournal() throws {
        let src = try makeFile("src.txt", contents: "payload")
        let dst = dir.appendingPathComponent("moved/dst.txt")
        let journal = dir.appendingPathComponent("journal.json")

        try fs.safeMove(from: src, to: dst, journalAt: journal)

        XCTAssertFalse(fs.exists(at: src))
        XCTAssertTrue(fs.exists(at: dst))
        XCTAssertEqual(try String(contentsOf: dst, encoding: .utf8), "payload")
        XCTAssertFalse(fs.exists(at: journal), "Journal should be cleared after a successful move")
    }

    func testRecoverCompletesInterruptedMove() throws {
        // Simulate a crash *before* the move: journal exists, source present, dest absent.
        let src = try makeFile("orphan.txt", contents: "recover-me")
        let dst = dir.appendingPathComponent("dest/orphan.txt")
        let journal = dir.appendingPathComponent("journal.json")
        let op = MoveOperation(source: src.path, destination: dst.path)
        try JSONEncoder().encode([op]).write(to: journal)

        let recovered = try fs.recover(journalAt: journal)

        XCTAssertEqual(recovered.count, 1)
        XCTAssertTrue(fs.exists(at: dst))
        XCTAssertFalse(fs.exists(at: src))
        XCTAssertEqual(try String(contentsOf: dst, encoding: .utf8), "recover-me")
        XCTAssertFalse(fs.exists(at: journal))
    }

    func testRecoverIsNoopWhenMoveAlreadyCompleted() throws {
        // Simulate a crash *after* the move: dest exists, source gone.
        let dst = try makeFile("already.txt", contents: "done")
        let src = dir.appendingPathComponent("gone/already.txt")
        let journal = dir.appendingPathComponent("journal.json")
        try JSONEncoder().encode([MoveOperation(source: src.path, destination: dst.path)])
            .write(to: journal)

        let recovered = try fs.recover(journalAt: journal)

        XCTAssertEqual(recovered.count, 1)
        XCTAssertTrue(fs.exists(at: dst))
        XCTAssertEqual(try String(contentsOf: dst, encoding: .utf8), "done")
        XCTAssertFalse(fs.exists(at: journal))
    }

    func testRecoverWithNoJournalReturnsEmpty() throws {
        let recovered = try fs.recover(journalAt: dir.appendingPathComponent("none.json"))
        XCTAssertTrue(recovered.isEmpty)
    }
}

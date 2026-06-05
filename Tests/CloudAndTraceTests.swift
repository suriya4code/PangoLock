import XCTest

final class CloudAndTraceTests: XCTestCase {

    func testICloudDetection() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Secret")
        XCTAssertEqual(CloudAwareness.provider(for: url), .iCloud)
    }

    func testDropboxDetection() {
        XCTAssertEqual(CloudAwareness.provider(for: URL(fileURLWithPath: "/Users/me/Dropbox/Work")), .dropbox)
    }

    func testGoogleDriveDetection() {
        let url = URL(fileURLWithPath: "/Users/me/Library/CloudStorage/GoogleDrive-x/My Drive/Docs")
        XCTAssertEqual(CloudAwareness.provider(for: url), .googleDrive)
    }

    func testLocalPathHasNoProvider() {
        XCTAssertNil(CloudAwareness.provider(for: URL(fileURLWithPath: "/Users/me/Documents/Local")))
    }

    func testTraceCleanerRemovesGivenPaths() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-trace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = dir.appendingPathComponent("a.tmp")
        let b = dir.appendingPathComponent("b.tmp")
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)
        let missing = dir.appendingPathComponent("missing.tmp")

        let removed = TraceCleanerService().clear([a, b, missing])
        XCTAssertEqual(removed, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: b.path))
    }
}

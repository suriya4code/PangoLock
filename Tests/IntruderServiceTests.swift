import XCTest
import CryptoKit

final class IntruderServiceTests: XCTestCase {

    private var dir: URL!
    private let key = SymmetricKey(size: .bits256)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-intr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeService(threshold: Int = 3) throws -> IntruderService {
        try IntruderService(store: IntruderLogStore(url: dir.appendingPathComponent("log.enc")),
                            key: key,
                            imageDirectory: dir.appendingPathComponent("images"),
                            threshold: threshold)
    }

    func testFailureThresholdAndReset() throws {
        let service = try makeService(threshold: 3)
        XCTAssertFalse(service.registerFailure())
        XCTAssertFalse(service.registerFailure())
        XCTAssertTrue(service.registerFailure(), "Should signal at threshold")

        service.registerSuccess()
        XCTAssertFalse(service.registerFailure(), "Counter resets after success")
    }

    func testRecordIntruderWithImageEncryptsAndRoundTrips() throws {
        let service = try makeService()
        let jpeg = Data((0..<3000).map { _ in UInt8.random(in: 0...255) })

        try service.recordIntruder(imageData: jpeg)
        XCTAssertEqual(service.events.count, 1)
        let event = try XCTUnwrap(service.events.first)
        XCTAssertFalse(event.wasSuccessful)
        let name = try XCTUnwrap(event.imageFilename)

        // Stored snapshot must be encrypted on disk...
        let onDisk = try Data(contentsOf: dir.appendingPathComponent("images").appendingPathComponent(name))
        XCTAssertNotEqual(onDisk, jpeg)
        // ...but decrypt back to the original.
        XCTAssertEqual(try service.image(for: event), jpeg)
    }

    func testRecordIntruderWithoutImage() throws {
        let service = try makeService()
        try service.recordIntruder()
        XCTAssertEqual(service.events.count, 1)
        XCTAssertNil(service.events.first?.imageFilename)
    }

    func testEventsPersistAcrossInstances() throws {
        do {
            let service = try makeService()
            try service.recordIntruder()
            try service.recordSuccess()
        }
        let reloaded = try makeService()
        XCTAssertEqual(reloaded.events.count, 2)
    }

    func testClearRemovesEventsAndImages() throws {
        let service = try makeService()
        try service.recordIntruder(imageData: Data("img".utf8))
        let name = try XCTUnwrap(service.events.first?.imageFilename)

        try service.clear()
        XCTAssertTrue(service.events.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("images").appendingPathComponent(name).path))
    }
}

import XCTest
import CryptoKit

final class RecoveryServiceTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-rec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testEnableThenRecoverReturnsSameKey() throws {
        let service = RecoveryService(url: dir.appendingPathComponent("recovery.bundle"))
        let master = SymmetricKey(size: .bits256)

        XCTAssertFalse(service.isEnabled)
        let phrase = try service.enable(masterKey: master)
        XCTAssertTrue(service.isEnabled)
        XCTAssertFalse(phrase.isEmpty)

        let recovered = try service.recover(phrase: phrase)
        XCTAssertEqual(recovered, master)
    }

    func testRecoverIgnoresFormattingOfPhrase() throws {
        let service = RecoveryService(url: dir.appendingPathComponent("recovery.bundle"))
        let master = SymmetricKey(size: .bits256)
        let phrase = try service.enable(masterKey: master)

        // Lowercased and stripped of separators/spaces should still work.
        let messy = phrase.lowercased().replacingOccurrences(of: "-", with: " ")
        XCTAssertEqual(try service.recover(phrase: messy), master)
    }

    func testWrongPhraseFails() throws {
        let service = RecoveryService(url: dir.appendingPathComponent("recovery.bundle"))
        try service.enable(masterKey: SymmetricKey(size: .bits256))

        XCTAssertThrowsError(try service.recover(phrase: "WRONG-PHRASE-AAAA-BBBB")) { error in
            XCTAssertEqual(error as? CryptoError, .authenticationFailed)
        }
    }

    func testDisableRemovesBundle() throws {
        let service = RecoveryService(url: dir.appendingPathComponent("recovery.bundle"))
        try service.enable(masterKey: SymmetricKey(size: .bits256))
        try service.disable()
        XCTAssertFalse(service.isEnabled)
    }
}

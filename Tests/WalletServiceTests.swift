import XCTest
import CryptoKit

final class WalletServiceTests: XCTestCase {

    private var url: URL!
    private let key = SymmetricKey(size: .bits256)

    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-wallet-\(UUID().uuidString)")
            .appendingPathComponent("wallet.enc")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func makeService() throws -> WalletService {
        try WalletService(store: WalletStore(url: url), key: key)
    }

    func testAddUpdateRemove() throws {
        let service = try makeService()
        let card = try service.add(WalletCard(title: "Email",
                                              kind: .login,
                                              fields: ["username": "me", "password": "p"]))
        XCTAssertEqual(service.cards.count, 1)

        var edited = card
        edited.title = "Work Email"
        try service.update(edited)
        XCTAssertEqual(service.cards.first?.title, "Work Email")

        try service.remove(card.id)
        XCTAssertTrue(service.cards.isEmpty)
    }

    func testPersistsEncryptedAcrossInstances() throws {
        do {
            let service = try makeService()
            try service.add(WalletCard(title: "Bank", kind: .card,
                                       fields: ["number": "4111-secret"]))
        }
        let reloaded = try makeService()
        XCTAssertEqual(reloaded.cards.count, 1)
        XCTAssertEqual(reloaded.cards.first?.title, "Bank")

        // On-disk must not contain plaintext field values.
        let raw = try Data(contentsOf: url)
        XCTAssertNil(raw.range(of: Data("4111-secret".utf8)))
    }

    func testWrongKeyCannotDecrypt() throws {
        do { let s = try makeService(); try s.add(WalletCard(title: "x")) }
        XCTAssertThrowsError(try WalletService(store: WalletStore(url: url),
                                               key: SymmetricKey(size: .bits256)))
    }

    func testPasswordGenerator() {
        let pw = PasswordGenerator.generate(length: 24)
        XCTAssertEqual(pw.count, 24)

        let digitsOnly = PasswordGenerator.generate(length: 100, useUppercase: false,
                                                    useDigits: true, useSymbols: false)
        XCTAssertTrue(digitsOnly.allSatisfy { $0.isLowercase || $0.isNumber })

        XCTAssertNotEqual(PasswordGenerator.generate(), PasswordGenerator.generate())
    }
}

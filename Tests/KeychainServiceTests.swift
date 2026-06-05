import XCTest

final class KeychainServiceTests: XCTestCase {

    /// Statuses that indicate the *environment* can't exercise the keychain
    /// (unsigned/headless test runner), as opposed to a logic bug.
    private static let environmentSkipStatuses: Set<OSStatus> = [
        errSecMissingEntitlement, // -34018
        errSecInteractionNotAllowed, // -25308
        errSecAuthFailed, // -25293
        -25291, // errSecNotAvailable (no keychain available)
    ]

    private func skipIfEnvironment(_ error: Error) throws {
        if case let KeychainError.unexpectedStatus(status) = error,
           Self.environmentSkipStatuses.contains(status) {
            throw XCTSkip("Keychain not available in this environment (status \(status)); logic validated under a signed host in Phase 8.")
        }
    }

    func testSetGetDeleteRoundTrip() throws {
        let keychain = KeychainService(service: "com.pangolock.tests")
        let account = "unit-test-\(UUID().uuidString)"
        let secret = Data("super-secret-salt".utf8)

        do {
            try keychain.set(secret, for: account)
        } catch {
            try skipIfEnvironment(error)
            throw error
        }
        defer { try? keychain.delete(account) }

        let fetched = try keychain.get(account)
        XCTAssertEqual(fetched, secret)

        try keychain.delete(account)
        let afterDelete = try keychain.get(account)
        XCTAssertNil(afterDelete)
    }

    func testGetMissingReturnsNil() throws {
        let keychain = KeychainService(service: "com.pangolock.tests")
        let missing = try keychain.get("does-not-exist-\(UUID().uuidString)")
        XCTAssertNil(missing)
    }
}

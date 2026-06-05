import XCTest

final class AuthServiceTests: XCTestCase {

    private static let environmentSkipStatuses: Set<OSStatus> = [
        errSecMissingEntitlement, errSecInteractionNotAllowed, errSecAuthFailed, -25291,
    ]

    /// Build an AuthService backed by a unique keychain service, or skip if the
    /// keychain is unavailable in this environment.
    private func makeService() throws -> AuthService {
        let keychain = KeychainService(service: "com.pangolock.tests.auth.\(UUID().uuidString)")
        // Fewer iterations keep tests fast; correctness is unchanged.
        let service = AuthService(keychain: keychain, iterations: 5_000)
        do {
            try service.setMasterPassword("hunter2-correct")
        } catch let KeychainError.unexpectedStatus(status)
                    where Self.environmentSkipStatuses.contains(status) {
            throw XCTSkip("Keychain unavailable (status \(status)); validated under signed host in Phase 8.")
        }
        addTeardownBlock { try? service.reset() }
        return service
    }

    func testInitialStateUnconfigured() {
        let keychain = KeychainService(service: "com.pangolock.tests.auth.\(UUID().uuidString)")
        let service = AuthService(keychain: keychain, iterations: 5_000)
        XCTAssertEqual(service.state, .unconfigured)
        XCTAssertFalse(service.isConfigured)
        XCTAssertNil(service.masterKey)
    }

    func testSetMasterPasswordUnlocksAndSetsKey() throws {
        let service = try makeService()
        XCTAssertTrue(service.isConfigured)
        XCTAssertEqual(service.state, .unlocked)
        XCTAssertNotNil(service.masterKey)
    }

    func testSetTwiceThrowsAlreadyConfigured() throws {
        let service = try makeService()
        XCTAssertThrowsError(try service.setMasterPassword("again")) { error in
            XCTAssertEqual(error as? AuthError, .alreadyConfigured)
        }
    }

    func testVerifyCorrectAndIncorrect() throws {
        let service = try makeService()
        XCTAssertTrue(service.verify(password: "hunter2-correct"))
        XCTAssertFalse(service.verify(password: "wrong"))
    }

    func testLockThenUnlock() throws {
        let service = try makeService()
        service.lock()
        XCTAssertEqual(service.state, .locked)
        XCTAssertNil(service.masterKey)

        try service.unlock(password: "hunter2-correct")
        XCTAssertEqual(service.state, .unlocked)
        XCTAssertNotNil(service.masterKey)
    }

    func testWrongUnlockIncrementsFailuresAndFiresLockout() throws {
        let service = try makeService()
        service.lock()
        service.lockoutThreshold = 3
        var lockoutFired = false
        service.onLockout = { lockoutFired = true }

        for i in 1...3 {
            XCTAssertThrowsError(try service.unlock(password: "nope")) { error in
                XCTAssertEqual(error as? AuthError, .incorrectPassword)
            }
            XCTAssertEqual(service.failedAttempts, i)
        }
        XCTAssertTrue(lockoutFired)
        XCTAssertEqual(service.state, .locked, "Failed unlock must not unlock")
    }

    func testSuccessfulUnlockResetsFailures() throws {
        let service = try makeService()
        service.lock()
        XCTAssertThrowsError(try service.unlock(password: "nope"))
        XCTAssertEqual(service.failedAttempts, 1)

        try service.unlock(password: "hunter2-correct")
        XCTAssertEqual(service.failedAttempts, 0)
    }

    func testResetClearsConfiguration() throws {
        let service = try makeService()
        try service.reset()
        XCTAssertFalse(service.isConfigured)
        XCTAssertEqual(service.state, .unconfigured)
        XCTAssertNil(service.masterKey)
    }

    // MARK: - Idle lock policy

    func testIdleLockPolicyExpires() {
        let policy = IdleLockPolicy(timeout: 60)
        let last = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(policy.shouldLock(lastActivity: last, now: last.addingTimeInterval(59)))
        XCTAssertTrue(policy.shouldLock(lastActivity: last, now: last.addingTimeInterval(60)))
        XCTAssertTrue(policy.shouldLock(lastActivity: last, now: last.addingTimeInterval(120)))
    }

    func testIdleLockDisabledWhenTimeoutZero() {
        let policy = IdleLockPolicy(timeout: 0)
        let last = Date()
        XCTAssertFalse(policy.shouldLock(lastActivity: last, now: last.addingTimeInterval(10_000)))
    }
}

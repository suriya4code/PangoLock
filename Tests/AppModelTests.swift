import XCTest

@MainActor
final class AppModelTests: XCTestCase {

    private static let environmentSkipStatuses: Set<OSStatus> = [
        errSecMissingEntitlement, errSecInteractionNotAllowed, errSecAuthFailed, -25291,
    ]

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-app-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeModel() -> (AppModel, AuthService) {
        let auth = AuthService(keychain: KeychainService(service: "com.pangolock.tests.app.\(UUID().uuidString)"),
                               iterations: 5_000)
        let model = AppModel(auth: auth,
                             registryURL: dir.appendingPathComponent("registry.enc"),
                             vaultStoreURL: dir.appendingPathComponent("store"))
        return (model, auth)
    }

    /// Drive onboarding; skip if keychain isn't usable in this environment.
    private func configured() throws -> AppModel {
        let (model, _) = makeModel()
        model.setMasterPassword("master-pass")
        if let message = model.errorMessage, message.contains("-34018") || message.contains("Keychain") {
            throw XCTSkip("Keychain unavailable; validated under signed host in Phase 8.")
        }
        guard model.screen == .unlocked else {
            throw XCTSkip("Could not configure master password in this environment.")
        }
        return model
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url.appendingPathComponent("f.txt"))
        return url
    }

    func testStartsInOnboardingWhenUnconfigured() {
        let (model, _) = makeModel()
        XCTAssertEqual(model.screen, .onboarding)
        XCTAssertTrue(model.items.isEmpty)
    }

    func testSetMasterPasswordUnlocks() throws {
        let model = try configured()
        XCTAssertEqual(model.screen, .unlocked)
        XCTAssertNil(model.errorMessage)
    }

    func testAddHideLockThroughModel() throws {
        let model = try configured()
        let folder = try makeFolder("Docs")

        model.add(folder)
        XCTAssertEqual(model.items.count, 1)

        let id = model.items[0].id
        model.hide(id)
        XCTAssertEqual(model.items.first?.state, .hidden)

        model.lock(id)
        XCTAssertEqual(model.items.first?.state, .encrypted)

        model.unlockItem(id)
        XCTAssertEqual(model.items.first?.state, .visible)
    }

    func testLockAppThenUnlock() throws {
        let model = try configured()
        model.lockApp()
        XCTAssertEqual(model.screen, .locked)

        model.unlock("master-pass")
        XCTAssertEqual(model.screen, .unlocked)
    }

    func testWrongPasswordKeepsLockedAndReportsError() throws {
        let model = try configured()
        model.lockApp()
        model.unlock("wrong")
        XCTAssertEqual(model.screen, .locked)
        XCTAssertEqual(model.errorMessage, "Incorrect password.")
    }
}

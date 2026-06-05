import Foundation
import SwiftUI
import CryptoKit

/// Root view model. Wires AuthService (app access) and VaultManager (folder
/// protection) into observable state for the SwiftUI layer.
@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case onboarding   // no master password yet
        case locked       // configured but locked
        case unlocked     // vault open
    }

    @Published private(set) var screen: Screen
    @Published private(set) var items: [VaultItem] = []
    @Published var errorMessage: String?

    private let auth: AuthService
    private let registryURL: URL
    private let vaultStoreURL: URL
    private var vault: VaultManager?

    init(auth: AuthService, registryURL: URL, vaultStoreURL: URL) {
        self.auth = auth
        self.registryURL = registryURL
        self.vaultStoreURL = vaultStoreURL
        self.screen = auth.isConfigured ? .locked : .onboarding
    }

    convenience init() {
        let support = AppModel.appSupportDirectory()
        self.init(auth: AuthService(),
                  registryURL: support.appendingPathComponent("registry.enc"),
                  vaultStoreURL: support.appendingPathComponent("VaultStore"))
    }

    static func appSupportDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PangoLock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var isBiometricAvailable: Bool { BiometricAuth().isAvailable() }

    // MARK: - Auth flows

    func setMasterPassword(_ password: String) {
        run {
            try auth.setMasterPassword(password)
            try openVault()
        }
    }

    func unlock(_ password: String) {
        run {
            try auth.unlock(password: password)
            try openVault()
        }
    }

    func unlockWithBiometrics() {
        run {
            try auth.unlockWithBiometrics()
            try openVault()
        }
    }

    func lockApp() {
        auth.lock()
        vault = nil
        items = []
        screen = .locked
    }

    func enableBiometrics() { run { try auth.enableBiometricUnlock() } }
    func disableBiometrics() { run { try auth.disableBiometricUnlock() } }

    private func openVault() throws {
        guard let key = auth.masterKey else { throw AuthError.notConfigured }
        let manager = try VaultManager(store: RegistryStore(url: registryURL),
                                       key: key,
                                       vaultStoreURL: vaultStoreURL)
        vault = manager
        items = manager.items
        screen = .unlocked
    }

    // MARK: - Vault actions

    func add(_ url: URL) { run { try vault?.add(path: url); reload() } }
    func hide(_ id: UUID) { run { try vault?.hide(id); reload() } }
    func show(_ id: UUID) { run { try vault?.show(id); reload() } }
    func showAll() { run { try vault?.showAll(); reload() } }
    func lock(_ id: UUID) { run { try vault?.lock(id); reload() } }
    func unlockItem(_ id: UUID) { run { try vault?.unlock(id); reload() } }
    func remove(_ id: UUID) { run { try vault?.remove(id); reload() } }

    // MARK: - Helpers

    private func reload() { items = vault?.items ?? [] }

    private func run(_ body: () throws -> Void) {
        do { try body() } catch { errorMessage = Self.friendly(error) }
    }

    private static func friendly(_ error: Error) -> String {
        switch error {
        case AuthError.incorrectPassword: return "Incorrect password."
        case AuthError.alreadyConfigured: return "A master password is already set."
        case AuthError.notConfigured: return "No master password is set."
        case VaultError.passwordRequired: return "This item needs its folder password."
        case VaultError.sourceMissing: return "The selected item no longer exists on disk."
        case VaultError.invalidState: return "That action isn't available for this item."
        case CryptoError.authenticationFailed: return "Wrong password or corrupted data."
        default: return (error as NSError).localizedDescription
        }
    }
}

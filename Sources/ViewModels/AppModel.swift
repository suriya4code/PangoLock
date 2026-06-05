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
    @Published private(set) var cards: [WalletCard] = []
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    /// Shown once after enabling recovery (the phrase is never stored in clear).
    @Published var recoveryPhrase: String?

    private let auth: AuthService
    private let registryURL: URL
    private let vaultStoreURL: URL
    private var vault: VaultManager?
    private var wallet: WalletService?
    private let recovery: RecoveryService
    private let walletURL: URL
    private let shredder = ShredderService()
    private let intruder: IntruderService?

    init(auth: AuthService, registryURL: URL, vaultStoreURL: URL) {
        self.auth = auth
        self.registryURL = registryURL
        self.vaultStoreURL = vaultStoreURL
        let support = registryURL.deletingLastPathComponent()
        self.walletURL = support.appendingPathComponent("wallet.enc")
        self.recovery = RecoveryService(url: support.appendingPathComponent("recovery.bundle"))
        self.intruder = AppModel.makeIntruderService(in: support)
        self.screen = auth.isConfigured ? .locked : .onboarding
    }

    /// Build the intruder log with a dedicated Keychain key (independent of the
    /// master password, so failures can be logged while locked). Resilient: nil
    /// if the Keychain is unavailable.
    private static func makeIntruderService(in support: URL) -> IntruderService? {
        guard let key = try? IntruderService.loadOrCreateKey(keychain: KeychainService()) else {
            return nil
        }
        return try? IntruderService(
            store: IntruderLogStore(url: support.appendingPathComponent("intruder.log")),
            key: key,
            imageDirectory: support.appendingPathComponent("Intruders"))
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
        do {
            try auth.unlock(password: password)
            intruder?.registerSuccess()
            try openVault()
        } catch {
            if case AuthError.incorrectPassword = error,
               let intruder, intruder.registerFailure() {
                if UserDefaults.standard.bool(forKey: "intruderDetection") {
                    captureIntruder()
                } else {
                    try? intruder.recordIntruder()
                }
            }
            errorMessage = Self.friendly(error)
        }
    }

    private func captureIntruder() {
        guard let intruder else { return }
        Task { @MainActor in
            let data = try? await CameraCapture().captureStill()
            try? intruder.recordIntruder(imageData: data)
            objectWillChange.send()
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
        wallet = nil
        items = []
        cards = []
        screen = .locked
    }

    // MARK: - Recovery

    var isRecoveryEnabled: Bool { recovery.isEnabled }

    func enableRecovery() {
        run {
            guard let key = auth.masterKey else { throw AuthError.notConfigured }
            recoveryPhrase = try recovery.enable(masterKey: key)
        }
    }

    func recoverWithPhrase(_ phrase: String) {
        do {
            auth.unlockWithRecoveredKey(try recovery.recover(phrase: phrase))
            try openVault()
        } catch {
            errorMessage = Self.friendly(error)
        }
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
        let walletService = try WalletService(store: WalletStore(url: walletURL), key: key)
        wallet = walletService
        cards = walletService.cards
        screen = .unlocked
    }

    // MARK: - Vault actions

    func add(_ url: URL) {
        run {
            if let provider = CloudAwareness.provider(for: url) {
                infoMessage = "Heads up: this item is inside \(provider.rawValue). "
                    + "Its plaintext may already be synced to the cloud."
            }
            try vault?.add(path: url)
            reload()
        }
    }
    func hide(_ id: UUID) { run { try vault?.hide(id); reload() } }
    func show(_ id: UUID) { run { try vault?.show(id); reload() } }
    func showAll() { run { try vault?.showAll(); reload() } }
    func lock(_ id: UUID) { run { try vault?.lock(id); reload() } }
    func unlockItem(_ id: UUID) { run { try vault?.unlock(id); reload() } }
    func remove(_ id: UUID) { run { try vault?.remove(id); reload() } }

    /// Securely shred an item's data (the encrypted blob if locked, else the
    /// original) and remove it from PangoLock.
    func shred(_ id: UUID) {
        run {
            guard let item = vault?.items.first(where: { $0.id == id }) else {
                throw VaultError.itemNotFound
            }
            let target: URL
            if item.state == .encrypted, let managed = item.managedPath {
                target = URL(fileURLWithPath: managed)
            } else {
                target = URL(fileURLWithPath: item.originalPath)
            }
            try shredder.shred(at: target)
            try vault?.remove(id)
            reload()
        }
    }

    // MARK: - Intruder log

    var intruderEvents: [IntruderEvent] { intruder?.events ?? [] }
    func intruderImage(for event: IntruderEvent) -> Data? { try? intruder?.image(for: event) }
    func clearIntruderLog() { run { try intruder?.clear() } }

    // MARK: - Wallet

    func addCard(_ card: WalletCard) { run { try wallet?.add(card); cards = wallet?.cards ?? [] } }
    func removeCard(_ id: UUID) { run { try wallet?.remove(id); cards = wallet?.cards ?? [] } }
    func generatePassword() -> String { PasswordGenerator.generate() }

    // MARK: - Backup / share / portable locker

    func backup(to destination: URL, password: String) {
        run {
            try BackupService().backup(AppModel.appSupportDirectory(), to: destination, password: password)
            infoMessage = "Encrypted backup created."
        }
    }

    /// Export a (visible/hidden) item as an encrypted, shareable file.
    func shareItem(_ id: UUID, to destination: URL, password: String, hint: String?) {
        run {
            guard let item = vault?.items.first(where: { $0.id == id }) else {
                throw VaultError.itemNotFound
            }
            guard item.state != .encrypted else { throw VaultError.invalidState }
            try SharingService().export(URL(fileURLWithPath: item.originalPath),
                                        to: destination, password: password, hint: hint)
            infoMessage = "Encrypted copy exported."
        }
    }

    /// Save a (visible/hidden) item to a portable encrypted USB locker.
    func createLocker(_ id: UUID, to destination: URL, password: String) {
        run {
            guard let item = vault?.items.first(where: { $0.id == id }) else {
                throw VaultError.itemNotFound
            }
            guard item.state != .encrypted else { throw VaultError.invalidState }
            try PortableLockerService().create(at: destination,
                                               from: URL(fileURLWithPath: item.originalPath),
                                               password: password)
            infoMessage = "Portable locker created."
        }
    }

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

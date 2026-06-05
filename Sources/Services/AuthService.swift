import Foundation
import CryptoKit

enum AuthState: Equatable {
    case unconfigured
    case locked
    case unlocked
}

enum AuthError: Error, Equatable {
    case alreadyConfigured
    case notConfigured
    case incorrectPassword
}

/// App-access protection: master-password setup/verification, lock state, and a
/// failed-attempt counter. Verification is zero-knowledge — only a salt and an
/// AES-GCM "verifier" (encryption of a known token) are stored; the password is
/// never persisted. A successful unlock yields the derived master key in memory.
final class AuthService {
    private let keychain: KeychainService
    private let iterations: Int

    private let saltAccount = "master.salt"
    private let verifierAccount = "master.verifier"
    private let iterationsAccount = "master.iterations"
    private let biometricKeyAccount = "master.biokey"
    private static let magic = Data("PangoLock.master.v1".utf8)

    private(set) var state: AuthState
    private(set) var failedAttempts: Int = 0

    /// Number of consecutive failures after which `onLockout` fires.
    var lockoutThreshold: Int = 5
    /// Hook invoked when `failedAttempts` reaches `lockoutThreshold`
    /// (feeds intruder detection in a later phase).
    var onLockout: (() -> Void)?

    /// The derived 256-bit master key. Present only while `state == .unlocked`.
    private(set) var masterKey: SymmetricKey?

    init(keychain: KeychainService = KeychainService(),
         iterations: Int = KeyDerivation.defaultIterations) {
        self.keychain = keychain
        self.iterations = iterations
        self.state = Self.isConfigured(keychain: keychain, saltAccount: "master.salt")
            ? .locked : .unconfigured
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        Self.isConfigured(keychain: keychain, saltAccount: saltAccount)
    }

    private static func isConfigured(keychain: KeychainService, saltAccount: String) -> Bool {
        ((try? keychain.get(saltAccount)) ?? nil) != nil
    }

    /// First-run setup. Generates a salt, derives the master key, stores the
    /// salt + verifier, and leaves the service unlocked.
    func setMasterPassword(_ password: String) throws {
        guard !isConfigured else { throw AuthError.alreadyConfigured }
        let salt = KeyDerivation.randomSalt()
        let key = KeyDerivation.deriveKey(password: password, salt: salt, iterations: iterations)
        let verifier = try CryptoService.encrypt(Self.magic, using: key)

        try keychain.set(salt, for: saltAccount)
        try keychain.set(verifier, for: verifierAccount)
        try keychain.set(Data(String(iterations).utf8), for: iterationsAccount)

        masterKey = key
        state = .unlocked
        failedAttempts = 0
    }

    // MARK: - Verify / unlock / lock

    /// Check a password without changing state. Returns false on mismatch.
    func verify(password: String) -> Bool {
        (try? deriveAndCheck(password).ok) ?? false
    }

    /// Attempt to unlock. On success, stores the master key and resets the
    /// failure counter. On failure, increments the counter and (at threshold)
    /// fires `onLockout`, then throws `.incorrectPassword`.
    func unlock(password: String) throws {
        guard isConfigured else { throw AuthError.notConfigured }
        let (key, ok) = try deriveAndCheck(password)
        if ok {
            masterKey = key
            state = .unlocked
            failedAttempts = 0
        } else {
            failedAttempts += 1
            if failedAttempts >= lockoutThreshold { onLockout?() }
            throw AuthError.incorrectPassword
        }
    }

    // MARK: - Biometric unlock

    /// Store the current master key behind a biometric-gated Keychain item so it
    /// can be released after a Touch ID prompt. Requires being unlocked.
    /// Not unit-tested (needs biometric hardware + signing); manual.
    func enableBiometricUnlock() throws {
        guard let key = masterKey else { throw AuthError.notConfigured }
        let raw = key.withUnsafeBytes { Data($0) }
        try keychain.setBiometric(raw, for: biometricKeyAccount)
    }

    func disableBiometricUnlock() throws {
        try keychain.delete(biometricKeyAccount)
    }

    /// Unlock using the biometric-protected master key (prompts Touch ID).
    func unlockWithBiometrics() throws {
        guard isConfigured else { throw AuthError.notConfigured }
        guard let raw = try keychain.get(biometricKeyAccount) else {
            throw AuthError.incorrectPassword
        }
        masterKey = SymmetricKey(data: raw)
        state = .unlocked
        failedAttempts = 0
    }

    /// Unlock with a master key recovered out-of-band (e.g. via RecoveryService).
    func unlockWithRecoveredKey(_ key: SymmetricKey) {
        masterKey = key
        state = .unlocked
        failedAttempts = 0
    }

    /// Lock the app: forget the in-memory master key.
    func lock() {
        masterKey = nil
        state = isConfigured ? .locked : .unconfigured
    }

    /// Remove all master-password material (used for full reset / tests).
    func reset() throws {
        try keychain.delete(saltAccount)
        try keychain.delete(verifierAccount)
        try keychain.delete(iterationsAccount)
        try keychain.delete(biometricKeyAccount)
        masterKey = nil
        failedAttempts = 0
        state = .unconfigured
    }

    // MARK: - Private

    private func deriveAndCheck(_ password: String) throws -> (key: SymmetricKey, ok: Bool) {
        guard let salt = try keychain.get(saltAccount),
              let verifier = try keychain.get(verifierAccount) else {
            throw AuthError.notConfigured
        }
        let key = KeyDerivation.deriveKey(password: password, salt: salt, iterations: storedIterations())
        do {
            let opened = try CryptoService.decrypt(verifier, using: key)
            return (key, opened == Self.magic)
        } catch {
            return (key, false)
        }
    }

    private func storedIterations() -> Int {
        guard let data = ((try? keychain.get(iterationsAccount)) ?? nil),
              let str = String(data: data, encoding: .utf8),
              let value = Int(str) else { return iterations }
        return value
    }
}

/// Pure, testable idle auto-lock rule. The actual timer is wired in the UI layer.
struct IdleLockPolicy {
    /// Inactivity duration before locking. `<= 0` disables auto-lock.
    var timeout: TimeInterval

    func shouldLock(lastActivity: Date, now: Date) -> Bool {
        timeout > 0 && now.timeIntervalSince(lastActivity) >= timeout
    }
}

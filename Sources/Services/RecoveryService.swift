import Foundation
import CryptoKit

/// Recovery-key flow for a forgotten master password (zero-knowledge friendly).
///
/// When enabled (while unlocked), generates a random recovery phrase and stores
/// the master key wrapped under a key derived from that phrase. If the password
/// is later forgotten, the phrase unwraps the master key and restores access.
final class RecoveryService {
    struct Bundle: Codable, Equatable {
        let version: Int
        let salt: Data
        let wrappedKey: Data
    }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Enable recovery for `masterKey`; returns the human-readable phrase to
    /// show the user once (never stored in the clear).
    @discardableResult
    func enable(masterKey: SymmetricKey) throws -> String {
        let phrase = Self.generatePhrase()
        let salt = KeyDerivation.randomSalt()
        let recoveryKey = KeyDerivation.deriveKey(password: Self.normalize(phrase), salt: salt)
        var rawMaster = masterKey.withUnsafeBytes { Data($0) }
        defer { rawMaster.secureWipe() }
        let wrapped = try CryptoService.encrypt(rawMaster, using: recoveryKey)

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(Bundle(version: 1, salt: salt, wrappedKey: wrapped))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return phrase
    }

    func disable() throws {
        if isEnabled { try FileManager.default.removeItem(at: url) }
    }

    /// Recover the master key from a phrase. Throws on a wrong phrase.
    func recover(phrase: String) throws -> SymmetricKey {
        let bundle = try PropertyListDecoder().decode(Bundle.self, from: Data(contentsOf: url))
        let recoveryKey = KeyDerivation.deriveKey(password: Self.normalize(phrase), salt: bundle.salt)
        var rawMaster = try CryptoService.decrypt(bundle.wrappedKey, using: recoveryKey)
        defer { rawMaster.secureWipe() }
        return SymmetricKey(data: rawMaster)
    }

    // MARK: - Phrase

    /// e.g. "K7QF-2MZP-9XR4-..." — 6 groups of 4 base32 chars.
    static func generatePhrase(groups: Int = 6) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // no I,O,0,1
        var bytes = [UInt8](repeating: 0, count: groups * 4)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let chars = bytes.map { alphabet[Int($0) % alphabet.count] }
        return stride(from: 0, to: chars.count, by: 4)
            .map { String(chars[$0..<min($0 + 4, chars.count)]) }
            .joined(separator: "-")
    }

    static func normalize(_ phrase: String) -> String {
        phrase.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}

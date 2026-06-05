import Foundation
import CryptoKit

enum CryptoError: Error, Equatable {
    /// The input could not be parsed as a valid AES-GCM sealed box.
    case malformedCiphertext
    /// Authentication failed (wrong key or tampered ciphertext).
    case authenticationFailed
}

/// Authenticated encryption using AES-256-GCM (CryptoKit).
///
/// The combined output is `nonce || ciphertext || tag`. GCM provides
/// confidentiality and integrity: decryption fails if the key is wrong or the
/// ciphertext has been tampered with.
enum CryptoService {
    /// Encrypt `plaintext` with a 256-bit key. A fresh random nonce is used per call.
    static func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw CryptoError.malformedCiphertext
        }
        return combined
    }

    /// Decrypt a combined AES-GCM payload produced by `encrypt`.
    static func decrypt(_ combined: Data, using key: SymmetricKey) throws -> Data {
        let box: AES.GCM.SealedBox
        do {
            box = try AES.GCM.SealedBox(combined: combined)
        } catch {
            throw CryptoError.malformedCiphertext
        }
        do {
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CryptoError.authenticationFailed
        }
    }

    // MARK: - File convenience

    /// Encrypt a file's contents to `destination` (atomic write).
    /// NOTE: whole-file in memory for now; chunked streaming can replace this later.
    static func encryptFile(at source: URL, to destination: URL, using key: SymmetricKey) throws {
        let data = try Data(contentsOf: source)
        let encrypted = try encrypt(data, using: key)
        try encrypted.write(to: destination, options: .atomic)
    }

    /// Decrypt an encrypted file to `destination` (atomic write).
    static func decryptFile(at source: URL, to destination: URL, using key: SymmetricKey) throws {
        let data = try Data(contentsOf: source)
        let decrypted = try decrypt(data, using: key)
        try decrypted.write(to: destination, options: .atomic)
    }
}

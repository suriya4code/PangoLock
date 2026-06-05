import Foundation
import CryptoKit
import CommonCrypto

/// Password-based key derivation (PBKDF2-HMAC-SHA256) and salt generation.
///
/// Keys are derived from the user's password plus a per-vault random salt.
/// The derived 256-bit key feeds `CryptoService` (AES-256-GCM). The password
/// itself is never stored; only the salt (and, in later phases, a verifier).
enum KeyDerivation {
    /// PBKDF2 iteration count. Tuned for a strong work factor; can be raised over time.
    static let defaultIterations = 210_000
    /// AES-256 key length in bytes.
    static let keyByteCount = 32
    /// Recommended salt length in bytes.
    static let saltByteCount = 16

    /// Cryptographically secure random salt.
    static func randomSalt(byteCount: Int = saltByteCount) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return Data(bytes)
    }

    /// Derive a 256-bit symmetric key from a password + salt using PBKDF2-HMAC-SHA256.
    static func deriveKey(password: String,
                          salt: Data,
                          iterations: Int = defaultIterations) -> SymmetricKey {
        var pw = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: keyByteCount)

        let result = derived.withUnsafeMutableBytes { derivedBuf -> Int32 in
            salt.withUnsafeBytes { saltBuf -> Int32 in
                pw.withUnsafeBytes { pwBuf -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwBuf.bindMemory(to: CChar.self).baseAddress, pw.count,
                        saltBuf.bindMemory(to: UInt8.self).baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedBuf.bindMemory(to: UInt8.self).baseAddress, keyByteCount
                    )
                }
            }
        }
        precondition(result == kCCSuccess, "PBKDF2 derivation failed: \(result)")

        let key = SymmetricKey(data: Data(derived))
        // Wipe transient buffers.
        for i in derived.indices { derived[i] = 0 }
        for i in pw.indices { pw[i] = 0 }
        return key
    }
}

import Foundation

/// A self-describing, password-protected encrypted archive of a file/folder.
/// Shared by encrypted sharing, portable USB lockers, and backups.
///
/// Container layout (binary plist): { version, salt, hint?, payload } where
/// `payload` is AES-256-GCM of the archived subtree, keyed by PBKDF2(password, salt).
enum EncryptedArchive {
    struct Container: Codable, Equatable {
        let version: Int
        let salt: Data
        let hint: String?
        let payload: Data
    }

    /// Encrypt a file/folder at `source` into a container blob.
    static func pack(source: URL, password: String, hint: String? = nil) throws -> Data {
        let archive = try FolderArchiver.archive(at: source)
        let salt = KeyDerivation.randomSalt()
        let key = KeyDerivation.deriveKey(password: password, salt: salt)
        let payload = try CryptoService.encrypt(archive, using: key)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(Container(version: 1, salt: salt, hint: hint, payload: payload))
    }

    /// Read the (unencrypted) password hint without decrypting the contents.
    static func hint(from data: Data) throws -> String? {
        try PropertyListDecoder().decode(Container.self, from: data).hint
    }

    /// Decrypt a container blob and restore its contents to `destination`.
    /// Throws `CryptoError.authenticationFailed` on a wrong password.
    static func unpack(_ data: Data, password: String, to destination: URL) throws {
        let container = try PropertyListDecoder().decode(Container.self, from: data)
        let key = KeyDerivation.deriveKey(password: password, salt: container.salt)
        let archive = try CryptoService.decrypt(container.payload, using: key)
        try FolderArchiver.unarchive(archive, to: destination)
    }
}

import Foundation

/// Export a folder/file as a single encrypted, password-protected file that a
/// recipient can decrypt on any Mac running PangoLock. Includes an optional
/// password hint (stored in the clear) instead of sending the password.
struct SharingService {
    static let fileExtension = "pangoshare"

    /// Write an encrypted bundle of `source` to `destination`.
    func export(_ source: URL, to destination: URL, password: String, hint: String? = nil) throws {
        let blob = try EncryptedArchive.pack(source: source, password: password, hint: hint)
        try blob.write(to: destination, options: .atomic)
    }

    /// Read the password hint from a bundle without decrypting it.
    func hint(of bundle: URL) throws -> String? {
        try EncryptedArchive.hint(from: try Data(contentsOf: bundle))
    }

    /// Decrypt a bundle to `destination`.
    func `import`(_ bundle: URL, password: String, to destination: URL) throws {
        try EncryptedArchive.unpack(try Data(contentsOf: bundle), password: password, to: destination)
    }
}

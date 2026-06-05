import Foundation
import CryptoKit

/// Persists the `VaultRegistry` as an AES-256-GCM encrypted blob on disk.
/// Writes are atomic (write-temp-then-rename) so a crash never leaves a
/// half-written registry.
final class RegistryStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    /// Load and decrypt the registry. Returns an empty registry if no file exists.
    func load(using key: SymmetricKey) throws -> VaultRegistry {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return VaultRegistry()
        }
        let blob = try Data(contentsOf: url)
        let json = try CryptoService.decrypt(blob, using: key)
        return try JSONDecoder().decode(VaultRegistry.self, from: json)
    }

    /// Encrypt and atomically write the registry.
    func save(_ registry: VaultRegistry, using key: SymmetricKey) throws {
        let json = try JSONEncoder().encode(registry)
        let blob = try CryptoService.encrypt(json, using: key)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try blob.write(to: url, options: .atomic)
    }
}

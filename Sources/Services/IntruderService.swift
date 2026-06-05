import Foundation
import CryptoKit

/// Encrypted persistence for the intruder/access log.
final class IntruderLogStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func load(using key: SymmetricKey) throws -> [IntruderEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let json = try CryptoService.decrypt(try Data(contentsOf: url), using: key)
        return try JSONDecoder().decode([IntruderEvent].self, from: json)
    }

    func save(_ events: [IntruderEvent], using key: SymmetricKey) throws {
        let blob = try CryptoService.encrypt(try JSONEncoder().encode(events), using: key)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try blob.write(to: url, options: .atomic)
    }
}

/// Tracks failed-unlock attempts and records intruder events (with optional
/// encrypted camera snapshots). Uses a dedicated key stored in the Keychain so
/// events can be logged even while the app is locked (no master password yet).
final class IntruderService {
    static let keyAccount = "intruder.logkey"

    private let store: IntruderLogStore
    private let key: SymmetricKey
    let imageDirectory: URL
    var threshold: Int

    private(set) var events: [IntruderEvent]
    private var consecutiveFailures = 0

    init(store: IntruderLogStore,
         key: SymmetricKey,
         imageDirectory: URL,
         threshold: Int = 3) throws {
        self.store = store
        self.key = key
        self.imageDirectory = imageDirectory
        self.threshold = threshold
        self.events = try store.load(using: key)
    }

    /// Load (or create + persist) the dedicated intruder-log key from Keychain.
    static func loadOrCreateKey(keychain: KeychainService) throws -> SymmetricKey {
        if let data = try keychain.get(keyAccount) {
            return SymmetricKey(data: data)
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        let data = Data(bytes)
        try keychain.set(data, for: keyAccount)
        return SymmetricKey(data: data)
    }

    /// Returns true when the consecutive-failure count reaches the threshold.
    func registerFailure() -> Bool {
        consecutiveFailures += 1
        return consecutiveFailures >= threshold
    }

    func registerSuccess() {
        consecutiveFailures = 0
    }

    /// Append an intruder record, optionally storing an encrypted snapshot.
    func recordIntruder(imageData: Data? = nil, at date: Date = Date()) throws {
        var filename: String?
        if let data = imageData {
            try FileManager.default.createDirectory(
                at: imageDirectory, withIntermediateDirectories: true)
            let name = "intruder-\(UUID().uuidString).jpg.enc"
            let encrypted = try CryptoService.encrypt(data, using: key)
            try encrypted.write(to: imageDirectory.appendingPathComponent(name), options: .atomic)
            filename = name
        }
        events.append(IntruderEvent(timestamp: date, wasSuccessful: false, imageFilename: filename))
        try persist()
    }

    func recordSuccess(at date: Date = Date()) throws {
        events.append(IntruderEvent(timestamp: date, wasSuccessful: true))
        try persist()
    }

    /// Decrypt a stored snapshot for display.
    func image(for event: IntruderEvent) throws -> Data? {
        guard let name = event.imageFilename else { return nil }
        let encrypted = try Data(contentsOf: imageDirectory.appendingPathComponent(name))
        return try CryptoService.decrypt(encrypted, using: key)
    }

    func clear() throws {
        for event in events {
            if let name = event.imageFilename {
                try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(name))
            }
        }
        events = []
        try persist()
    }

    private func persist() throws {
        try store.save(events, using: key)
    }
}

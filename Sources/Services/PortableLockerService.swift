import Foundation

/// Create and open self-contained, AES-256 encrypted lockers on external/USB
/// drives. A locker is a single `.pangolocker` file unlockable on any Mac
/// running PangoLock with the locker password.
struct PortableLockerService {
    static let fileExtension = "pangolocker"

    /// Create a locker file at `lockerURL` from `source`.
    func create(at lockerURL: URL, from source: URL, password: String) throws {
        let blob = try EncryptedArchive.pack(source: source, password: password)
        try blob.write(to: lockerURL, options: .atomic)
    }

    /// Open a locker, restoring its contents to `destination`.
    func open(_ lockerURL: URL, password: String, to destination: URL) throws {
        try EncryptedArchive.unpack(try Data(contentsOf: lockerURL), password: password, to: destination)
    }
}

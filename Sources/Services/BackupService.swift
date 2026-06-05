import Foundation

/// Password-protected encrypted backup of a directory (e.g. the PangoLock
/// application-support folder: registry, recovery bundle, encrypted blobs).
struct BackupService {
    static let fileExtension = "pangobackup"

    func backup(_ directory: URL, to destination: URL, password: String) throws {
        let blob = try EncryptedArchive.pack(source: directory, password: password,
                                             hint: "PangoLock backup")
        try blob.write(to: destination, options: .atomic)
    }

    func restore(_ backup: URL, to directory: URL, password: String) throws {
        try EncryptedArchive.unpack(try Data(contentsOf: backup), password: password, to: directory)
    }
}

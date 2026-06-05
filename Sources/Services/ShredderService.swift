import Foundation

/// Securely deletes files/folders by overwriting their contents with random
/// data across multiple passes before removal.
///
/// NOTE: On modern SSDs/APFS (copy-on-write, wear-leveling), in-place overwrite
/// does not guarantee the original blocks are physically erased. This raises the
/// bar against casual recovery; full-disk encryption (FileVault) remains the
/// real protection. Documented as a known limitation.
struct ShredderService {
    enum ShredError: Error, Equatable {
        case sourceMissing
    }

    let passes: Int
    let fileManager: FileManager

    init(passes: Int = 3, fileManager: FileManager = .default) {
        self.passes = max(1, passes)
        self.fileManager = fileManager
    }

    /// Shred a file, or every file within a directory then remove the tree.
    func shred(at url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ShredError.sourceMissing
        }
        if isDirectory.boolValue {
            if let enumerator = fileManager.enumerator(
                at: url, includingPropertiesForKeys: [.isRegularFileKey]) {
                for case let fileURL as URL in enumerator {
                    let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if values.isRegularFile == true {
                        try overwriteAndRemove(fileURL)
                    }
                }
            }
            try fileManager.removeItem(at: url)
        } else {
            try overwriteAndRemove(url)
        }
    }

    private func overwriteAndRemove(_ url: URL) throws {
        let size = (try fileManager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if size > 0 {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            let chunkSize = 64 * 1024
            for _ in 0..<passes {
                try handle.seek(toOffset: 0)
                var remaining = size
                while remaining > 0 {
                    let count = min(chunkSize, remaining)
                    var bytes = [UInt8](repeating: 0, count: count)
                    _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
                    try handle.write(contentsOf: Data(bytes))
                    remaining -= count
                }
                try handle.synchronize()
            }
            try handle.truncate(atOffset: 0)
        }
        try fileManager.removeItem(at: url)
    }
}

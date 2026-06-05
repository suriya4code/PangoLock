import Foundation

/// Serializes a file or directory subtree into a single `Data` blob (and back),
/// so it can be encrypted as one unit. Uses a binary property list internally.
enum FolderArchiver {
    enum ArchiveError: Error, Equatable {
        case sourceMissing
    }

    struct Entry: Codable, Equatable {
        /// Path relative to the archive root ("" == the root itself).
        let path: String
        let isDirectory: Bool
        let data: Data?
    }

    struct Archive: Codable, Equatable {
        var entries: [Entry]
    }

    /// Capture the subtree rooted at `root` (a file or directory).
    static func archive(at root: URL) throws -> Data {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else {
            throw ArchiveError.sourceMissing
        }

        var entries: [Entry] = []
        if isDir.boolValue {
            entries.append(Entry(path: "", isDirectory: true, data: nil))
            if let enumerator = fm.enumerator(at: root,
                                              includingPropertiesForKeys: [.isDirectoryKey],
                                              options: []) {
                for case let url as URL in enumerator {
                    let relative = Self.relativePath(of: url, from: root)
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                    if values.isDirectory == true {
                        entries.append(Entry(path: relative, isDirectory: true, data: nil))
                    } else {
                        entries.append(Entry(path: relative, isDirectory: false,
                                             data: try Data(contentsOf: url)))
                    }
                }
            }
        } else {
            entries.append(Entry(path: "", isDirectory: false, data: try Data(contentsOf: root)))
        }

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(Archive(entries: entries))
    }

    /// Recreate an archived subtree at `root`.
    static func unarchive(_ data: Data, to root: URL) throws {
        let archive = try PropertyListDecoder().decode(Archive.self, from: data)
        let fm = FileManager.default
        for entry in archive.entries {
            let target = entry.path.isEmpty ? root : root.appendingPathComponent(entry.path)
            if entry.isDirectory {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: target.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try (entry.data ?? Data()).write(to: target)
            }
        }
    }

    private static func relativePath(of url: URL, from root: URL) -> String {
        let full = url.standardizedFileURL.path
        let base = root.standardizedFileURL.path
        if full == base { return "" }
        let prefix = base.hasSuffix("/") ? base : base + "/"
        return full.hasPrefix(prefix) ? String(full.dropFirst(prefix.count)) : url.lastPathComponent
    }
}

import Foundation

/// A pending move recorded in the journal so an interrupted operation can be
/// reconciled on next launch.
struct MoveOperation: Codable, Equatable {
    let id: UUID
    let source: String
    let destination: String

    init(id: UUID = UUID(), source: String, destination: String) {
        self.id = id
        self.source = source
        self.destination = destination
    }
}

/// Filesystem primitives: hidden-flag toggling and crash-safe, journaled moves.
struct FileSystemService {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func exists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Hidden flag

    /// Set/clear the Finder "hidden" flag (UF_HIDDEN) on an item.
    func setHidden(_ hidden: Bool, at url: URL) throws {
        var values = URLResourceValues()
        values.isHidden = hidden
        var target = url
        try target.setResourceValues(values)
    }

    // MARK: - Hardened hide (Finder + Spotlight + access lockdown)

    /// Spotlight exclusion marker dropped inside concealed folders.
    static let noIndexMarker = ".metadata_never_index"

    /// Strongly conceal an item so other apps (video players, media scanners,
    /// Spotlight) can't reach it while it stays in place:
    ///   1. drop a `.metadata_never_index` marker (Spotlight skip),
    ///   2. set the Finder hidden flag,
    ///   3. strip ALL POSIX permissions so nothing can read/traverse it.
    /// Returns the original permissions so `reveal` can restore them.
    @discardableResult
    func conceal(at url: URL) throws -> Int {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDir {
            let marker = url.appendingPathComponent(Self.noIndexMarker)
            if !fileManager.fileExists(atPath: marker.path) {
                try? Data().write(to: marker)
            }
        }
        try setHidden(true, at: url)
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        let original = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? (isDir ? 0o755 : 0o644)
        try fileManager.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        return original
    }

    /// Reverse `conceal`: restore permissions, clear the hidden flag, and remove
    /// the Spotlight marker. `mode` is the value returned by `conceal`.
    func reveal(at url: URL, restoring mode: Int?) throws {
        try fileManager.setAttributes([.posixPermissions: mode ?? 0o755],
                                      ofItemAtPath: url.path)
        try setHidden(false, at: url)
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDir {
            let marker = url.appendingPathComponent(Self.noIndexMarker)
            try? fileManager.removeItem(at: marker)
        }
    }

    func isHidden(at url: URL) throws -> Bool {
        // Build a fresh URL and drop cached values so we read the live flag
        // (Foundation caches resource values on the URL's backing store).
        var fresh = URL(fileURLWithPath: url.path)
        fresh.removeAllCachedResourceValues()
        return try fresh.resourceValues(forKeys: [.isHiddenKey]).isHidden ?? false
    }

    // MARK: - Journaled, crash-safe move

    /// Record intent, move, then clear the journal. If the process dies between
    /// steps, `recover(journalAt:)` can complete or discard the operation.
    func safeMove(from source: URL, to destination: URL, journalAt journalURL: URL) throws {
        let op = MoveOperation(source: source.path, destination: destination.path)
        try writeJournal([op], to: journalURL)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try fileManager.moveItem(at: source, to: destination)
        try clearJournal(at: journalURL)
    }

    /// Reconcile any pending move. Idempotent; returns the operations found.
    /// - If the destination already exists and the source is gone, the move
    ///   completed before the crash — nothing to do.
    /// - If the source still exists and the destination doesn't, the move never
    ///   happened — complete it now.
    @discardableResult
    func recover(journalAt journalURL: URL) throws -> [MoveOperation] {
        guard exists(at: journalURL) else { return [] }
        let ops = try readJournal(at: journalURL)
        for op in ops {
            let src = URL(fileURLWithPath: op.source)
            let dst = URL(fileURLWithPath: op.destination)
            if exists(at: dst), !exists(at: src) {
                continue // completed
            }
            if exists(at: src), !exists(at: dst) {
                try fileManager.createDirectory(
                    at: dst.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try fileManager.moveItem(at: src, to: dst)
            }
            // If both exist (rare), leave untouched for manual resolution.
        }
        try clearJournal(at: journalURL)
        return ops
    }

    // MARK: - Journal I/O

    private func writeJournal(_ ops: [MoveOperation], to url: URL) throws {
        let data = try JSONEncoder().encode(ops)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func readJournal(at url: URL) throws -> [MoveOperation] {
        try JSONDecoder().decode([MoveOperation].self, from: Data(contentsOf: url))
    }

    private func clearJournal(at url: URL) throws {
        if exists(at: url) { try fileManager.removeItem(at: url) }
    }
}

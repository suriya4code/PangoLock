import Foundation

/// Removes leftover traces that could leak the existence/contents of protected
/// items. Conservative by design: it only deletes paths it is explicitly given,
/// plus a small set of known-safe per-user caches.
struct TraceCleanerService {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Remove the given paths (e.g. app-managed temp/export folders).
    /// Returns the number of items removed.
    @discardableResult
    func clear(_ urls: [URL]) -> Int {
        var removed = 0
        for url in urls where fileManager.fileExists(atPath: url.path) {
            if (try? fileManager.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }

    /// Best-effort: clear the Quick Look thumbnail cache so protected files
    /// don't leave preview thumbnails behind. Safe (the OS rebuilds it).
    func clearQuickLookCache() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        for base in caches {
            let ql = base.appendingPathComponent("com.apple.QuickLook.thumbnailcache")
            try? fileManager.removeItem(at: ql)
        }
    }
}

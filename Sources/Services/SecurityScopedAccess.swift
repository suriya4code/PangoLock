import Foundation

/// App Sandbox helper: create and resolve **security-scoped bookmarks** so the
/// app can keep accessing user-selected files/folders across launches, and wrap
/// filesystem work in the required start/stop access calls.
///
/// Outside the sandbox (e.g. unit tests, an unsigned dev build) the
/// security-scope options aren't honored; the helper degrades gracefully to a
/// plain bookmark / direct path so behavior is identical there.
enum SecurityScopedAccess {

    /// Create a bookmark for a user-selected URL. Tries an app-scoped
    /// security-scoped bookmark first; falls back to a minimal bookmark when
    /// the sandbox isn't active. Returns nil only if both fail.
    static func makeBookmark(for url: URL) -> Data? {
        if let scoped = try? url.bookmarkData(options: [.withSecurityScope],
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil) {
            return scoped
        }
        return try? url.bookmarkData(options: [],
                                     includingResourceValuesForKeys: nil,
                                     relativeTo: nil)
    }

    /// Resolve a bookmark back to a URL, tolerating both scoped and plain
    /// bookmarks. Returns the URL and whether it is stale (should be re-saved).
    static func resolve(_ bookmark: Data) -> (url: URL, isStale: Bool)? {
        var stale = false
        if let url = try? URL(resolvingBookmarkData: bookmark,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale) {
            return (url, stale)
        }
        stale = false
        if let url = try? URL(resolvingBookmarkData: bookmark,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale) {
            return (url, stale)
        }
        return nil
    }

    /// Run `body` with security-scoped access to a user-selected item.
    ///
    /// If `bookmark` resolves, access is started before and stopped after
    /// `body` (balanced even on throw). If there is no bookmark, falls back to
    /// `fallback` (the recorded original path) so unsandboxed/test runs work.
    static func withAccess<T>(bookmark: Data?,
                              fallback: URL,
                              _ body: (URL) throws -> T) throws -> T {
        guard let bookmark, let resolved = resolve(bookmark) else {
            return try body(fallback)
        }
        let didStart = resolved.url.startAccessingSecurityScopedResource()
        defer { if didStart { resolved.url.stopAccessingSecurityScopedResource() } }
        return try body(resolved.url)
    }
}

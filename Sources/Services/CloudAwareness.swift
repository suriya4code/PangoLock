import Foundation

/// Detects whether a path lives inside a cloud-synced folder, so we can warn the
/// user before protecting it (the plaintext may already be synced elsewhere).
enum CloudAwareness {
    enum Provider: String {
        case iCloud = "iCloud Drive"
        case dropbox = "Dropbox"
        case googleDrive = "Google Drive"
        case oneDrive = "OneDrive"
    }

    static func provider(for url: URL) -> Provider? {
        let path = url.path
        if path.contains("/Library/Mobile Documents/") || path.contains("com~apple~CloudDocs") {
            return .iCloud
        }
        if path.contains("/Dropbox/") || path.hasSuffix("/Dropbox") {
            return .dropbox
        }
        if path.contains("Google Drive") || path.contains("GoogleDrive")
            || path.contains("CloudStorage/GoogleDrive") {
            return .googleDrive
        }
        if path.contains("OneDrive") {
            return .oneDrive
        }
        return nil
    }
}

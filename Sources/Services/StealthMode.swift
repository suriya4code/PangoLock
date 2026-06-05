import AppKit

/// Toggles the app's Dock presence. When hidden, PangoLock runs as an
/// accessory (no Dock icon, no app menu) — a basic stealth disguise.
enum StealthMode {
    static func setHidden(_ hidden: Bool) {
        DispatchQueue.main.async {
            NSApp?.setActivationPolicy(hidden ? .accessory : .regular)
        }
    }
}

import AppKit

/// Locks the app automatically on system sleep or screen-lock (gated by the
/// "autoLockEnabled" preference). Wired in the UI layer; not unit-tested
/// (notification-driven).
final class AutoLockController {
    var onLock: () -> Void = {}

    private var started = false
    private var workspaceTokens: [NSObjectProtocol] = []
    private var distributedTokens: [NSObjectProtocol] = []

    func start() {
        guard !started else { return }
        started = true

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceTokens.append(
            workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.maybeLock()
            })

        let distributed = DistributedNotificationCenter.default()
        distributedTokens.append(
            distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"),
                                    object: nil, queue: .main) { [weak self] _ in
                self?.maybeLock()
            })
    }

    private func maybeLock() {
        let enabled = UserDefaults.standard.object(forKey: "autoLockEnabled") as? Bool ?? true
        if enabled { onLock() }
    }

    deinit {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceTokens.forEach { workspaceCenter.removeObserver($0) }
        distributedTokens.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }
}

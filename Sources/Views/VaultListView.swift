import SwiftUI
import AppKit

struct VaultListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: UUID?
    @State private var shredCandidate: VaultItem?
    @State private var shareCandidate: VaultItem?
    @State private var lockerCandidate: VaultItem?
    @State private var showWallet = false

    var body: some View {
        Group {
            if model.items.isEmpty {
                emptyState
            } else {
                List(selection: $selection) {
                    ForEach(model.items) { item in
                        VaultRow(item: item)
                            .tag(item.id)
                            .contextMenu { menu(for: item) }
                    }
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            urls.forEach { model.add($0) }
            return true
        }
        .toolbar {
            ToolbarItemGroup {
                Button { chooseItems() } label: { Label("Add", systemImage: "plus") }
                Button { model.showAll() } label: { Label("Show All", systemImage: "eye") }
                Button { showWallet = true } label: { Label("Wallet", systemImage: "creditcard") }
                Spacer()
                Button { model.lockApp() } label: { Label("Lock", systemImage: "lock") }
            }
        }
        .navigationTitle("PangoLock")
        .confirmationDialog("Permanently shred this item? This cannot be undone.",
                            isPresented: Binding(get: { shredCandidate != nil },
                                                 set: { if !$0 { shredCandidate = nil } }),
                            titleVisibility: .visible) {
            if let item = shredCandidate {
                Button("Shred \(item.displayName)", role: .destructive) { model.shred(item.id) }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showWallet) {
            NavigationStack { WalletView() }
                .frame(minWidth: 520, minHeight: 420)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showWallet = false }
                } }
        }
        .sheet(item: $shareCandidate) { item in
            PasswordSheet(title: "Share \(item.displayName)",
                          confirmLabel: "Export…", needsHint: true) { password, hint in
                if let dest = savePanel(suggested: item.displayName,
                                        ext: SharingService.fileExtension) {
                    model.shareItem(item.id, to: dest, password: password, hint: hint)
                }
            }
        }
        .sheet(item: $lockerCandidate) { item in
            PasswordSheet(title: "USB Locker for \(item.displayName)",
                          confirmLabel: "Create…") { password, _ in
                if let dest = savePanel(suggested: item.displayName,
                                        ext: PortableLockerService.fileExtension) {
                    model.createLocker(item.id, to: dest, password: password)
                }
            }
        }
    }

    private func savePanel(suggested: String, ext: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(suggested).\(ext)"
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No protected items yet")
                .font(.headline)
            Text("Drag a folder here, or click + to add one.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            urls.forEach { model.add($0) }
            return true
        }
    }

    @ViewBuilder
    private func menu(for item: VaultItem) -> some View {
        switch item.state {
        case .visible:
            Button("Hide") { model.hide(item.id) }
            Button("Lock (Encrypt)") { model.lock(item.id) }
        case .hidden:
            Button("Show") { model.show(item.id) }
            Button("Lock (Encrypt)") { model.lock(item.id) }
        case .encrypted, .locked:
            Button("Unlock (Decrypt)") { model.unlockItem(item.id) }
        }
        if item.state != .encrypted {
            Button("Reveal in Finder") { reveal(item) }
            Divider()
            Button("Share Encrypted Copy\u{2026}") { shareCandidate = item }
            Button("Save to USB Locker\u{2026}") { lockerCandidate = item }
        }
        Divider()
        Button("Remove from PangoLock", role: .destructive) { model.remove(item.id) }
        Button("Shred (Secure Delete)", role: .destructive) { shredCandidate = item }
    }

    private func chooseItems() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            panel.urls.forEach { model.add($0) }
        }
    }

    private func reveal(_ item: VaultItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.originalPath)])
    }
}

private struct VaultRow: View {
    let item: VaultItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                Text(item.originalPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            StatusBadge(state: item.state)
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch item.state {
        case .visible: return "folder"
        case .hidden: return "eye.slash"
        case .locked, .encrypted: return "lock.fill"
        }
    }
}

private struct StatusBadge: View {
    let state: VaultItem.State

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch state {
        case .visible: return "Visible"
        case .hidden: return "Hidden"
        case .locked: return "Locked"
        case .encrypted: return "Encrypted"
        }
    }

    private var color: Color {
        switch state {
        case .visible: return .secondary
        case .hidden: return .orange
        case .locked, .encrypted: return .green
        }
    }
}

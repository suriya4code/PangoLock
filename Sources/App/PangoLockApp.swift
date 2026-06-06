import SwiftUI

@main
struct PangoLockApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("theme") private var theme = "system"

    private var colorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup("PangoLock") {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(colorScheme)
        }
        .defaultSize(width: 760, height: 520)

        Settings {
            SettingsView()
                .environmentObject(model)
                .preferredColorScheme(colorScheme)
        }

        MenuBarExtra("PangoLock", systemImage: "lock.shield") {
            Button { model.showAll() } label: {
                Label("Show All Hidden", systemImage: "eye")
            }
            Button { model.lockApp() } label: {
                Label("Lock PangoLock", systemImage: "lock.fill")
            }
            Button {
                model.lockApp()
                StealthMode.setHidden(true)
            } label: {
                Label("Panic (Lock & Hide)", systemImage: "exclamationmark.shield.fill")
            }
            Divider()
            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit PangoLock", systemImage: "power")
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

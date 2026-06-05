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
            Button("Show All Hidden") { model.showAll() }
            Button("Lock PangoLock") { model.lockApp() }
            Divider()
            Button("Quit PangoLock") { NSApplication.shared.terminate(nil) }
        }
    }
}

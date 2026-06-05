import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            IntruderLogView()
                .tabItem { Label("Security Log", systemImage: "person.badge.shield.checkmark") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 340)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("idleTimeout") private var idleTimeout = 300
    @AppStorage("theme") private var theme = "system"
    @AppStorage("biometricsEnabled") private var biometricsEnabled = false
    @AppStorage("autoLockEnabled") private var autoLockEnabled = true
    @AppStorage("stealthMode") private var stealthMode = false
    @AppStorage("intruderDetection") private var intruderDetection = false

    var body: some View {
        Form {
            Picker("Appearance", selection: $theme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }

            Picker("Auto-lock after", selection: $idleTimeout) {
                Text("1 minute").tag(60)
                Text("5 minutes").tag(300)
                Text("15 minutes").tag(900)
                Text("Never").tag(0)
            }

            Toggle("Unlock with Touch ID", isOn: $biometricsEnabled)
                .disabled(!model.isBiometricAvailable)
                .onChange(of: biometricsEnabled) { enabled in
                    if enabled { model.enableBiometrics() } else { model.disableBiometrics() }
                }
            if !model.isBiometricAvailable {
                Text("Touch ID isn't available on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Auto-lock on sleep / screen lock", isOn: $autoLockEnabled)
            Toggle("Hide Dock icon (stealth)", isOn: $stealthMode)
                .onChange(of: stealthMode) { StealthMode.setHidden($0) }
            Toggle("Capture intruder photo after failed attempts", isOn: $intruderDetection)
            if intruderDetection {
                Text("Uses the camera after repeated failed unlocks. Requires camera permission.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private struct AboutSettings: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        return "Version \(v)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("PangoLock").font(.title2.bold())
            Text(version).font(.caption).foregroundStyle(.secondary)
            Text("100% free & open source. Every feature, no paywall.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("Sponsor on GitHub", destination: URL(string: "https://github.com/sponsors")!)
                .font(.callout)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

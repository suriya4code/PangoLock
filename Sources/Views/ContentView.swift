import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("stealthMode") private var stealthMode = false
    @State private var autoLock = AutoLockController()

    var body: some View {
        Group {
            switch model.screen {
            case .onboarding: OnboardingView()
            case .locked: LockedView()
            case .unlocked: VaultListView()
            }
        }
        .frame(minWidth: 660, minHeight: 440)
        .onAppear {
            StealthMode.setHidden(stealthMode)
            autoLock.onLock = { model.lockApp() }
            autoLock.start()
        }
        .onChange(of: stealthMode) { StealthMode.setHidden($0) }
        .alert("Something went wrong",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("Notice",
               isPresented: Binding(get: { model.infoMessage != nil },
                                    set: { if !$0 { model.infoMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.infoMessage ?? "")
        }
        .alert("Save Your Recovery Key",
               isPresented: Binding(get: { model.recoveryPhrase != nil },
                                    set: { if !$0 { model.recoveryPhrase = nil } })) {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.recoveryPhrase ?? "", forType: .string)
            }
            Button("Done", role: .cancel) { }
        } message: {
            Text("Write this down and keep it somewhere safe. It's shown only once and is the only way to recover access if you forget your password.\n\n\(model.recoveryPhrase ?? "")")
        }
    }
}

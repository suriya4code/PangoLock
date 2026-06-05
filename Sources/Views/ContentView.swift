import SwiftUI

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
    }
}

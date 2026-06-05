import SwiftUI

struct LockedView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("biometricsEnabled") private var biometricsEnabled = false
    @State private var password = ""

    private func submit() {
        model.unlock(password)
        password = ""
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("PangoLock is locked")
                .font(.title.bold())

            SecureField("Master password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .onSubmit(submit)

            Button("Unlock", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)

            if biometricsEnabled && model.isBiometricAvailable {
                Button { model.unlockWithBiometrics() } label: {
                    Label("Unlock with Touch ID", systemImage: "touchid")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }
}

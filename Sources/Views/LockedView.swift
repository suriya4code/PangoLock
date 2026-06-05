import SwiftUI

struct LockedView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("biometricsEnabled") private var biometricsEnabled = false
    @State private var password = ""
    @State private var showRecovery = false
    @State private var phrase = ""

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

            if model.isRecoveryEnabled {
                Divider().frame(maxWidth: 320)
                if showRecovery {
                    Text("Enter your recovery key")
                        .font(.callout).foregroundStyle(.secondary)
                    TextField("XXXX-XXXX-XXXX-…", text: $phrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                        .onSubmit { model.recoverWithPhrase(phrase) }
                    Button("Recover Access") { model.recoverWithPhrase(phrase) }
                        .buttonStyle(.bordered)
                        .disabled(phrase.isEmpty)
                } else {
                    Button("Forgot password?") { showRecovery = true }
                        .buttonStyle(.link)
                }
            }
        }
        .padding(40)
    }
}

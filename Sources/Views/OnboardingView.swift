import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var password = ""
    @State private var confirm = ""

    private var tooShort: Bool { !password.isEmpty && password.count < 6 }
    private var canSubmit: Bool { password.count >= 6 && password == confirm }

    var body: some View {
        VStack(spacing: 16) {
            BrandEmblem(size: 112)
            Text("Welcome to PangoLock")
                .font(.largeTitle.bold())
            Text("Create a master password to protect your folders.")
                .foregroundStyle(.secondary)

            SecureField("Master password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
            SecureField("Confirm password", text: $confirm)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .onSubmit { if canSubmit { model.setMasterPassword(password) } }

            if tooShort {
                Text("Use at least 6 characters.")
                    .font(.caption).foregroundStyle(.red)
            }

            Button("Create Master Password") { model.setMasterPassword(password) }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)

            Text("PangoLock is free & open source. There is no account and no "
                 + "password recovery — keep your master password safe.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(40)
    }
}

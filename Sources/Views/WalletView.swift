import SwiftUI
import AppKit

/// Encrypted wallet: logins, payment cards, secure notes, licenses.
struct WalletView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: WalletCard?
    @State private var showAdd = false

    var body: some View {
        Group {
            if model.cards.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(model.cards) { card in
                        DisclosureGroup {
                            CardFields(card: card)
                        } label: {
                            CardRow(card: card)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) { model.removeCard(card.id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Wallet")
        .toolbar {
            ToolbarItem {
                Button { showAdd = true } label: { Label("Add Card", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            CardEditor { model.addCard($0) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Your wallet is empty")
                .font(.headline)
            Text("Store logins, cards, notes, and licenses — encrypted with your master key.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Add Card") { showAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct CardRow: View {
    let card: WalletCard

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text(card.title)
            Spacer()
            Text(card.kind.rawValue.capitalized)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.tint.opacity(0.15), in: Capsule())
                .foregroundStyle(.tint)
        }
    }

    private var icon: String {
        switch card.kind {
        case .login: return "person.crop.circle"
        case .card: return "creditcard"
        case .note: return "note.text"
        case .license: return "key"
        }
    }
}

private struct CardFields: View {
    let card: WalletCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if card.fields.isEmpty {
                Text("No fields").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(card.fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack {
                    Text(key).foregroundStyle(.secondary)
                    Spacer()
                    Text(value).textSelection(.enabled)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Copy")
                }
                .font(.callout)
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 8)
    }
}

/// Create a new wallet card with dynamic key/value fields.
private struct CardEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onSave: (WalletCard) -> Void

    @State private var title = ""
    @State private var kind: WalletCard.Kind = .login
    @State private var fields: [Field] = [Field(key: "Username", value: ""),
                                          Field(key: "Password", value: "")]

    private struct Field: Identifiable { let id = UUID(); var key: String; var value: String }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Card").font(.title2.bold())

            Form {
                TextField("Title", text: $title)
                Picker("Type", selection: $kind) {
                    ForEach(WalletCard.Kind.allCases, id: \.self) { k in
                        Text(k.rawValue.capitalized).tag(k)
                    }
                }
            }

            Text("Fields").font(.headline)
            ForEach($fields) { $field in
                HStack {
                    TextField("Name", text: $field.key).frame(width: 120)
                    TextField("Value", text: $field.value)
                    Button { field.value = model.generatePassword() } label: {
                        Image(systemName: "dice")
                    }
                    .help("Generate strong value")
                    Button(role: .destructive) {
                        fields.removeAll { $0.id == field.id }
                    } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                }
            }
            Button { fields.append(Field(key: "", value: "")) } label: {
                Label("Add Field", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func save() {
        var dict: [String: String] = [:]
        for f in fields where !f.key.isEmpty { dict[f.key] = f.value }
        onSave(WalletCard(title: title, kind: kind, fields: dict))
        dismiss()
    }
}

/// Reusable password (+ optional hint) prompt with a strong-password generator.
struct PasswordSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let title: String
    var confirmLabel: String = "Continue"
    var needsHint: Bool = false
    let onConfirm: (_ password: String, _ hint: String?) -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var hint = ""

    private var mismatch: Bool { !confirmPassword.isEmpty && password != confirmPassword }
    private var valid: Bool { !password.isEmpty && password == confirmPassword }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.bold())

            HStack {
                SecureField("Password", text: $password)
                Button { password = model.generatePassword(); confirmPassword = password } label: {
                    Image(systemName: "dice")
                }
                .help("Generate strong password")
            }
            SecureField("Confirm password", text: $confirmPassword)
            if mismatch {
                Text("Passwords don't match.").font(.caption).foregroundStyle(.red)
            }
            if needsHint {
                TextField("Password hint (optional, stored unencrypted)", text: $hint)
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(confirmLabel) {
                    onConfirm(password, hint.isEmpty ? nil : hint)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!valid)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

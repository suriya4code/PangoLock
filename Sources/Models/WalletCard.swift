import Foundation

/// An encrypted wallet entry: login, payment card, secure note, or license.
struct WalletCard: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case login
        case card
        case note
        case license
    }

    let id: UUID
    var title: String
    var kind: Kind
    /// Free-form key/value fields (e.g. username, password, number, notes).
    var fields: [String: String]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String,
         kind: Kind = .login,
         fields: [String: String] = [:],
         createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.kind = kind
        self.fields = fields
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

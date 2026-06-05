import Foundation

/// A recorded access attempt (used for the intruder/access log).
struct IntruderEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let wasSuccessful: Bool
    /// Filename of the encrypted captured photo, if any.
    let imageFilename: String?

    init(id: UUID = UUID(),
         timestamp: Date,
         wasSuccessful: Bool,
         imageFilename: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.wasSuccessful = wasSuccessful
        self.imageFilename = imageFilename
    }
}

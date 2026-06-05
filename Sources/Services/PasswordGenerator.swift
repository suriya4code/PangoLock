import Foundation

/// Cryptographically-random password generator.
enum PasswordGenerator {
    static func generate(length: Int = 20,
                         useUppercase: Bool = true,
                         useDigits: Bool = true,
                         useSymbols: Bool = true) -> String {
        var alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        if useUppercase { alphabet += Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ") }
        if useDigits { alphabet += Array("0123456789") }
        if useSymbols { alphabet += Array("!@#$%^&*()-_=+[]{};:,.?") }

        let count = max(1, length)
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
}

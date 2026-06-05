import XCTest
import CryptoKit

final class CryptoServiceTests: XCTestCase {

    private func key(_ password: String, salt: Data) -> SymmetricKey {
        KeyDerivation.deriveKey(password: password, salt: salt, iterations: 10_000)
    }

    func testEncryptDecryptRoundTrip() throws {
        let salt = KeyDerivation.randomSalt()
        let k = key("correct horse battery staple", salt: salt)
        let plaintext = Data("Top secret folder contents 🐾".utf8)

        let ciphertext = try CryptoService.encrypt(plaintext, using: k)
        XCTAssertNotEqual(ciphertext, plaintext)

        let recovered = try CryptoService.decrypt(ciphertext, using: k)
        XCTAssertEqual(recovered, plaintext)
    }

    func testNonceIsRandomPerCall() throws {
        let k = key("pw", salt: KeyDerivation.randomSalt())
        let plaintext = Data("same input".utf8)
        let c1 = try CryptoService.encrypt(plaintext, using: k)
        let c2 = try CryptoService.encrypt(plaintext, using: k)
        XCTAssertNotEqual(c1, c2, "Ciphertexts must differ due to random nonce")
    }

    func testWrongKeyFails() throws {
        let salt = KeyDerivation.randomSalt()
        let good = key("right-password", salt: salt)
        let bad = key("wrong-password", salt: salt)
        let ciphertext = try CryptoService.encrypt(Data("secret".utf8), using: good)

        XCTAssertThrowsError(try CryptoService.decrypt(ciphertext, using: bad)) { error in
            XCTAssertEqual(error as? CryptoError, .authenticationFailed)
        }
    }

    func testTamperDetection() throws {
        let k = key("pw", salt: KeyDerivation.randomSalt())
        var ciphertext = try CryptoService.encrypt(Data("integrity matters".utf8), using: k)
        // Flip a byte in the tag/ciphertext region.
        let idx = ciphertext.count - 1
        ciphertext[idx] ^= 0xFF

        XCTAssertThrowsError(try CryptoService.decrypt(ciphertext, using: k)) { error in
            XCTAssertEqual(error as? CryptoError, .authenticationFailed)
        }
    }

    func testMalformedCiphertextThrows() {
        let k = key("pw", salt: KeyDerivation.randomSalt())
        let garbage = Data([0x00, 0x01, 0x02])
        XCTAssertThrowsError(try CryptoService.decrypt(garbage, using: k)) { error in
            XCTAssertEqual(error as? CryptoError, .malformedCiphertext)
        }
    }

    func testKDFDeterminismSameSalt() {
        let salt = KeyDerivation.randomSalt()
        let k1 = KeyDerivation.deriveKey(password: "pw", salt: salt, iterations: 10_000)
        let k2 = KeyDerivation.deriveKey(password: "pw", salt: salt, iterations: 10_000)
        XCTAssertEqual(k1, k2, "Same password+salt+iterations must derive the same key")
    }

    func testKDFDifferentSaltDiffers() {
        let k1 = KeyDerivation.deriveKey(password: "pw", salt: KeyDerivation.randomSalt(), iterations: 10_000)
        let k2 = KeyDerivation.deriveKey(password: "pw", salt: KeyDerivation.randomSalt(), iterations: 10_000)
        XCTAssertNotEqual(k1, k2, "Different salts must derive different keys")
    }

    func testFileRoundTrip() throws {
        let k = key("pw", salt: KeyDerivation.randomSalt())
        let dir = FileManager.default.temporaryDirectory
        let src = dir.appendingPathComponent("pl-src-\(UUID().uuidString).bin")
        let enc = dir.appendingPathComponent("pl-enc-\(UUID().uuidString).bin")
        let dec = dir.appendingPathComponent("pl-dec-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: src)
                try? FileManager.default.removeItem(at: enc)
                try? FileManager.default.removeItem(at: dec) }

        let original = Data((0..<4096).map { _ in UInt8.random(in: 0...255) })
        try original.write(to: src)

        try CryptoService.encryptFile(at: src, to: enc, using: k)
        try CryptoService.decryptFile(at: enc, to: dec, using: k)

        XCTAssertEqual(try Data(contentsOf: dec), original)
    }

    func testSecureWipeZeroesData() {
        var d = Data("sensitive".utf8)
        d.secureWipe()
        XCTAssertTrue(d.allSatisfy { $0 == 0 })
    }
}

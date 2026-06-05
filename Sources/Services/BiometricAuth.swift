import Foundation
import LocalAuthentication

/// Touch ID / Apple Watch unlock via LocalAuthentication.
///
/// Not unit-tested (requires hardware + user presence); exercised manually.
struct BiometricAuth {
    enum BiometricError: Error {
        case unavailable
    }

    /// Whether biometric authentication can be used right now.
    func isAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Prompt for biometric (with device-owner fallback). Returns true on success.
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication, error: &error) else {
            throw BiometricError.unavailable
        }
        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication, localizedReason: reason)
    }
}

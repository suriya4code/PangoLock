import Foundation

extension Data {
    /// Best-effort zeroing of the underlying bytes. Use after handling
    /// sensitive material (derived keys, plaintext) to limit exposure.
    mutating func secureWipe() {
        guard !isEmpty else { return }
        withUnsafeMutableBytes { raw in
            if let base = raw.baseAddress {
                memset_s(base, raw.count, 0, raw.count)
            }
        }
    }
}

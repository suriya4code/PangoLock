import Foundation
import AVFoundation

/// Captures a single still image from the Mac's camera (for intruder snapshots).
/// Requires camera permission (NSCameraUsageDescription). Not unit-tested
/// (needs hardware + user permission); exercised manually.
final class CameraCapture: NSObject, AVCapturePhotoCaptureDelegate {
    enum CaptureError: Error {
        case unavailable
        case failed
    }

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<Data, Error>?

    /// Returns JPEG/HEIC data for one captured frame.
    func captureStill() async throws -> Data {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output) else {
            throw CaptureError.unavailable
        }
        session.beginConfiguration()
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()
        defer { session.stopRunning() }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        defer { continuation = nil }
        if let error {
            continuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation?.resume(returning: data)
        } else {
            continuation?.resume(throwing: CaptureError.failed)
        }
    }
}

import RealityKit
import SwiftUI
import Combine

@MainActor
class CaptureManager: ObservableObject {
    @Published var session: ObjectCaptureSession?
    @Published var isUnsupported = false
    private(set) var capturedImagesDir: URL?

    func startNewSession() {
        guard ObjectCaptureSession.isSupported else {
            isUnsupported = true
            return
        }

        let captureID = UUID().uuidString
        Task.detached(priority: .userInitiated) {
            let imagesDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("Capture-\(captureID)/Images", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            } catch {
                print("CaptureManager: failed to create directory: \(error)")
                return
            }

            await MainActor.run {
                self.capturedImagesDir = imagesDir
                let newSession = ObjectCaptureSession()
                newSession.start(imagesDirectory: imagesDir,
                                 configuration: ObjectCaptureSession.Configuration())
                self.session = newSession
            }
        }
    }

    func reset() {
        session?.cancel()
        session = nil
        isUnsupported = false
        capturedImagesDir = nil
    }
}

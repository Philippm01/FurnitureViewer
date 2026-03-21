import RealityKit
import SwiftUI
import Combine

@MainActor
class CaptureManager: ObservableObject {
    @Published var session: ObjectCaptureSession?

    func startNewSession() {
        // Create a fresh unique capture directory each time
        let captureDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Capture-\(UUID().uuidString)", isDirectory: true)
        let imagesDir = captureDir.appendingPathComponent("Images", isDirectory: true)
        let checkpointDir = captureDir.appendingPathComponent("Checkpoints", isDirectory: true)

        // Create both directories upfront — ObjectCaptureSession requires them to exist
        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: checkpointDir, withIntermediateDirectories: true)
        } catch {
            print("CaptureManager: Failed to create directories: \(error)")
            return
        }

        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = checkpointDir
        configuration.isOverCaptureEnabled = true  // allows capturing extra angles for better quality

        let newSession = ObjectCaptureSession()
        newSession.start(imagesDirectory: imagesDir, configuration: configuration)
        self.session = newSession
    }

    func reset() {
        session?.cancel()
        session = nil
    }
}

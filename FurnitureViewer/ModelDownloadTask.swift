import Foundation
import Combine

class ModelDownloadTask: NSObject, ObservableObject, URLSessionDownloadDelegate {

    @Published var progress: Double = 0          
    @Published var downloadedURL: URL? = nil     
    @Published var error: Error? = nil

    var isComplete: Bool { downloadedURL != nil }

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    var currentModelId: String = ""

    init(modelId: String = "") {
        self.currentModelId = modelId
    }

    func start(modelId: String, downloadURL: URL) {
        self.currentModelId = modelId
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(modelId).usdz")
        print("ModelDownloadTask: Checking if file exists at \(destination.path)")
        if FileManager.default.fileExists(atPath: destination.path) {
            print("ModelDownloadTask: File already exists! Returning instantly.")
            DispatchQueue.main.async {
                self.progress = 1.0
                self.downloadedURL = destination
            }
            return
        }
        
        print("ModelDownloadTask: File does not exist. Starting download from \(downloadURL)")
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session?.downloadTask(with: downloadURL)
        task?.resume()
    }

    func cancel() {
        print("ModelDownloadTask: Cancelled download.")
        task?.cancel()
        task = nil
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let p = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.progress = p }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(currentModelId).usdz")
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            DispatchQueue.main.async {
                self.progress = 1.0
                self.downloadedURL = destination
            }
        } catch {
            DispatchQueue.main.async { self.error = error }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            DispatchQueue.main.async { self.error = error }
        }
    }
}

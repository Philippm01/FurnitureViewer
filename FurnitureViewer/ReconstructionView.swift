import SwiftUI
import RealityKit

struct ReconstructionView: View {
    let imagesDir: URL
    let onComplete: (URL) -> Void
    let onCancel: () -> Void

    @State private var progress: Double = 0
    @State private var statusMessage = "Preparing…"
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.6, saturation: 0.8, brightness: 0.25),
                         Color(hue: 0.62, saturation: 0.9, brightness: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: isProcessing ? "cube.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(errorMessage != nil ? .orange : .white)
                        .symbolEffect(.bounce, options: .repeating, isActive: isProcessing)
                }

                VStack(spacing: 8) {
                    Text(errorMessage != nil ? "Something Went Wrong" : "Building 3D Model")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text(errorMessage ?? statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if errorMessage == nil {
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .padding(.horizontal, 40)
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                if let _ = errorMessage {
                    VStack(spacing: 12) {
                        Button("Try Again") {
                            errorMessage = nil
                            Task { await runReconstruction() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)

                        Button("Cancel") { onCancel() }
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                } else {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 40)
                }
            }
        }
        .task {
            await runReconstruction()
        }
    }

    private func runReconstruction() async {
        isProcessing = true
        progress = 0
        statusMessage = "Analysing captured images…"

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-\(UUID().uuidString).usdz")

        var config = PhotogrammetrySession.Configuration()
        config.isObjectMaskingEnabled = true
        
        do {
            let session = try PhotogrammetrySession(
                input: imagesDir,
                configuration: config
            )

            let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)
            try session.process(requests: [request])

            for try await output in session.outputs {
                switch output {
                case .requestProgress(_, fractionComplete: let frac):
                    await MainActor.run {
                        progress = frac
                        statusMessage = "Reconstructing geometry… \(Int(frac * 100))%"
                    }
                case .requestProgressInfo(_, let info):
                    await MainActor.run {
                        statusMessage = info.processingStage.map { "\($0)" } ?? "Processing…"
                    }
                case .requestComplete(_, let result):
                    if case .modelFile(let url) = result {
                        await MainActor.run {
                            progress = 1.0
                            statusMessage = "Done!"
                            isProcessing = false
                        }
                        onComplete(url)
                    }
                case .processingComplete:
                    break
                case .requestError(_, let error):
                    throw error
                case .processingCancelled:
                    break
                case .invalidSample(let id, reason: let reason):
                    print("ReconstructionView: invalid sample \(id) — \(reason)")
                case .skippedSample(let id):
                    print("ReconstructionView: skipped sample \(id)")
                default:
                    break
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }
}

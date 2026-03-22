import SwiftUI
import RealityKit

struct CaptureView: View {
    var onComplete: ((URL) -> Void)? = nil

    @StateObject private var manager = CaptureManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if manager.isUnsupported {
                unsupportedView

            } else if let session = manager.session {
                ObjectCaptureView(session: session)
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    HStack {
                        Button("Cancel") {
                            session.cancel()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding()

                        Spacer().allowsHitTesting(false)

                        if session.state == .capturing {
                            Button("Done") {
                                session.finish()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding()
                        }
                    }
                    Spacer().allowsHitTesting(false)
                }

                VStack {
                    Spacer().allowsHitTesting(false)
                    bottomUI(for: session)
                        .padding(.bottom, 40)
                }

            } else {
                loadingView
            }
        }
        .onChange(of: manager.session?.state) { _, newState in
            guard let newState else { return }
            if case .completed = newState, let dir = manager.capturedImagesDir {
                onComplete?(dir)
                dismiss()
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                if manager.session == nil && !manager.isUnsupported {
                    manager.startNewSession()
                }
            }
        }
    }

    @ViewBuilder
    private func bottomUI(for session: ObjectCaptureSession) -> some View {
        switch session.state {

        case .ready:
            VStack(spacing: 12) {
                GuidanceCard(
                    icon: "arrow.down.to.line.compact",
                    title: "Step 1 — Scan the Floor",
                    subtitle: "Slowly sweep the camera over the floor around the furniture for 3-4 seconds. This lets ARKit detect the surface.\nThen aim at the furniture and tap it — or press Begin."
                )

                let hint = feedbackHint(from: session.feedback)
                if !hint.isEmpty {
                    GuidanceCard(icon: "exclamationmark.circle", title: "Heads Up", subtitle: hint)
                }

                Button {
                    _ = session.startDetecting()
                } label: {
                    Label("Begin Detection", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
            }

        case .initializing:
            GuidanceCard(icon: "arrow.triangle.2.circlepath.camera",
                         title: "Initializing…",
                         subtitle: "Setting up the scanning session.")

        case .detecting:
            VStack(spacing: 12) {
                GuidanceCard(
                    icon: "cube.transparent",
                    title: "Resize the Box, Then Confirm",
                    subtitle: "• DRAG the orange handles to resize the box around your furniture\n• DRAG the circle on top to rotate\n• When it fits — press the Start Capturing button below"
                )

                Button {
                    session.startCapturing()
                } label: {
                    Label("Start Capturing", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                        .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
            }

        case .capturing:
            GuidanceCard(
                icon: "camera.fill",
                title: "Scanning — walk slowly",
                subtitle: "Walk a full circle at eye level. Then crouch to capture the legs. Raise the phone for the top. Keep the chair in frame the whole time. Tap Done when every side is covered.")

        case .finishing:
            GuidanceCard(icon: "checkmark.circle.fill",
                         title: "Finishing Capture…",
                         subtitle: "Saving images. Please wait.")

        case .completed:
            GuidanceCard(icon: "checkmark.seal.fill",
                         title: "Capture Complete!",
                         subtitle: "Building your 3D model now…")

        case .failed(let error):
            GuidanceCard(icon: "exclamationmark.triangle.fill",
                         title: "Scan Failed",
                         subtitle: error.localizedDescription)

        @unknown default:
            EmptyView()
        }
    }

    private func feedbackHint(from feedback: Set<ObjectCaptureSession.Feedback>) -> String {
        if feedback.contains(.objectTooClose) { return "Too close — step back until the whole piece fits in frame." }
        if feedback.contains(.objectTooFar)   { return "Too far — move a little closer to the furniture." }
        if feedback.contains(.movingTooFast)  { return "Moving too fast — hold the phone steady." }
        if feedback.contains(.environmentLowLight) { return "Too dark — improve the lighting before scanning." }
        if feedback.contains(.outOfFieldOfView) { return "Object is out of frame — center it in the camera." }
        return ""
    }

    @ViewBuilder
    private var unsupportedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .font(.system(size: 64)).foregroundStyle(.orange)
            Text("LiDAR Scanner Required").font(.title2.bold())
            Text("3D object capture requires a device with a LiDAR scanner — iPhone 12 Pro or a later Pro model.")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 32)
            Button("Go Back") { dismiss() }.buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.4)
            Text("Starting camera…").foregroundStyle(.white).font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

private struct GuidanceCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28)).foregroundStyle(.white).frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}



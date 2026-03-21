import SwiftUI
import RealityKit

struct CaptureView: View {
    @ObservedObject var manager: CaptureManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if let session = manager.session {
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

                        Spacer()

                        if session.state == .capturing {
                            Button("Done") {
                                session.finish()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding()
                        }
                    }
                    Spacer()
                }
            } else {
                ContentUnavailableView("No Session Active", systemImage: "camera.fill")
            }
        }
        .onAppear {
            if manager.session == nil {
                manager.startNewSession()
            }
        }
    }
}

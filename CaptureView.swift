import SwiftUI
import RealityKit
import ARKit

struct CaptureView: View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView { ARView(frame: .zero) }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

import SwiftUI
import SceneKit

struct ModelPreviewView: View {
    let usdzURL: URL
    
    var body: some View {
        SceneView(
            scene: createScene(from: usdzURL),
            options: [.autoenablesDefaultLighting, .allowsCameraControl]
        )
        .background(Color.white)
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func createScene(from url: URL) -> SCNScene? {
        do {
            let scene = try SCNScene(url: url, options: nil)
            return scene
        } catch {
            print("Failed to load 3D model: \(error)")
            return nil
        }
    }
}

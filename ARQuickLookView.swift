import SwiftUI
import QuickLook

struct ARQuickLookView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> QLPreviewController {
        QLPreviewController()
    }
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
}

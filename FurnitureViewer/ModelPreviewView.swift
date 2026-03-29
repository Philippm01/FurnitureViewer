import SwiftUI
import QuickLook

struct ModelPreviewView: View {
    let usdzURL: URL
    
    var body: some View {
        ARQuickLookView(url: usdzURL)
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct ARQuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { 
            url as NSURL 
        }
    }
}

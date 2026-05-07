import SwiftUI
import QuickLook

struct ModelPreviewView: View {
    let usdzURL: URL
    let previewImageURL: URL?
    
    @State private var showPreviewImage = true
    
    var body: some View {
        VStack(spacing: 0) {
            if showPreviewImage, let imageURL = previewImageURL, let data = try? Data(contentsOf: imageURL), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .background(Color(UIColor.secondarySystemBackground))
            }
            
            ARQuickLookView(url: usdzURL)
                .edgesIgnoringSafeArea(showPreviewImage && previewImageURL != nil ? [] : .all)
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if previewImageURL != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showPreviewImage ? "Hide Image" : "Show Image") {
                        withAnimation {
                            showPreviewImage.toggle()
                        }
                    }
                }
            }
        }
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

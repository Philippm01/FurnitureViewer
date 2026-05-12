import SwiftUI

enum ModelSource {
    case local(FurnitureModel)
    case cloud(FurnitureAPIModel)
    
    var name: String {
        switch self {
        case .local(let m): return m.metadata.name
        case .cloud(let m): return m.name
        }
    }
    
    var creatorName: String {
        switch self {
        case .local(let m): return m.metadata.creator
        case .cloud(let m): return m.creatorName
        }
    }
    
    var category: String {
        switch self {
        case .local(let m): return m.metadata.categories ?? "Unknown"
        case .cloud(let m): return m.categories
        }
    }
    
    var id: String {
        switch self {
        case .local(let m): return m.id.uuidString
        case .cloud(let m): return m.id ?? ""
        }
    }
}

struct UnifiedModelDetailView: View {
    let source: ModelSource
    
    @StateObject private var downloadTask: ModelDownloadTask
    @State private var previewImage: UIImage? = nil
    @State private var isLoadingPreview = true
    @State private var showARPreview = false
    @State private var localFileURL: URL? = nil

    private let controller = ModelController()
    private let storage = ScanStorage()

    init(source: ModelSource) {
        self.source = source
        let modelId: String
        switch source {
        case .local(let m): modelId = m.id.uuidString
        case .cloud(let m): modelId = m.id ?? ""
        }
        _downloadTask = StateObject(wrappedValue: ModelDownloadTask(modelId: modelId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                headerPreviewSection

                VStack(alignment: .leading, spacing: 24) {
                    
                    // Title & Creator
                    VStack(alignment: .leading, spacing: 6) {
                        Text(source.name)
                            .font(.title2.bold())
                        Text("By \(source.creatorName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Metadata
                    metadataGrid

                    Divider()

                    // Actions
                    actionSection
                }
                .padding(20)
            }
        }
        .navigationTitle(source.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { 
            await loadInitialData()
        }
        .fullScreenCover(isPresented: $showARPreview) {
            if let url = arURL {
                NavigationStack {
                    ModelPreviewView(usdzURL: url, previewImageURL: nil)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showARPreview = false }
                            }
                        }
                }
            }
        }
    }

    private var arURL: URL? {
        if let local = localFileURL { return local }
        return downloadTask.downloadedURL
    }

    @ViewBuilder
    private var headerPreviewSection: some View {
        ZStack {
            Color(.secondarySystemBackground)
            
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 300)
                    .clipped()
            } else if isLoadingPreview {
                ProgressView()
            } else {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)
            }
        }
        .frame(height: 300)
        .cornerRadius(0)
    }

    private var metadataGrid: some View {
        VStack(spacing: 12) {
            metaRow(icon: "tag", label: "Category", value: source.category)
            
            if case .cloud(let m) = source, let size = m.size {
                metaRow(icon: "doc.fill", label: "File Size", value: String(format: "%.1f MB", size))
            } else if case .local(let m) = source {
                metaRow(icon: "doc.fill", label: "File Size", value: String(format: "%.1f MB", Double(m.metadata.size) / 1_000_000))
            }
            
            metaRow(icon: "number", label: "ID", value: String(source.id.prefix(8)) + "...")
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionSection: some View {
        VStack(spacing: 16) {
            if arURL != nil {
                Button {
                    showARPreview = true
                } label: {
                    Label("Place in Room", systemImage: "arkit")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    if downloadTask.progress > 0 && !downloadTask.isComplete {
                        ProgressView("Downloading...", value: downloadTask.progress)
                            .progressViewStyle(.linear)
                    } else {
                        Button {
                            startDownload()
                        } label: {
                            Label("Download Model", systemImage: "icloud.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    Text("Download is required to view in AR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .animation(.spring(), value: arURL)
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }

    private func loadInitialData() async {
        switch source {
        case .local(let m):
            localFileURL = storage.modelURL(for: m)
            if let data = try? Data(contentsOf: storage.previewImageURL(for: m) ?? URL(fileURLWithPath: "")) {
                previewImage = UIImage(data: data)
            }
            isLoadingPreview = false
        case .cloud(let m):
            if let id = m.id {
                if let data = try? await controller.downloadPreview(id: id) {
                    previewImage = UIImage(data: data)
                }
            }
            isLoadingPreview = false
        }
    }

    private func startDownload() {
        if case .cloud(let m) = source, let id = m.id {
            let url = URL(string: "\(APIConfig.modelsURL)/\(id)/download")!
            downloadTask.start(downloadURL: url)
        }
    }
}

import SwiftUI
import QuickLookThumbnailing

enum ActiveSheet: Identifiable {
    case capture
    case reconstruction(imagesDir: URL)
    case metadata(modelURL: URL)
    
    var id: String {
        switch self {
        case .capture: return "capture"
        case .reconstruction(let url): return "reconstruction-\(url.path)"
        case .metadata(let url): return "metadata-\(url.path)"
        }
    }
}

struct HomeView: View {
    @StateObject private var storage = ScanStorage()
    @StateObject private var session = Session.shared
    @State private var activeSheet: ActiveSheet?
    @State private var thumbnails: [UUID: UIImage] = [:]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if filteredModels.isEmpty {
                    ContentUnavailableView {
                        Label("No Scans", systemImage: "sofa.fill")
                    } description: {
                        Text("You haven't scanned any furniture yet.")
                    }
                } else {
                    List {
                        ForEach(filteredModels) { model in
                            ZStack {
                                FancyModelRow(
                                    title: model.metadata.name,
                                    image: thumbnails[model.id],
                                    systemIcon: "cube.fill"
                                )
                                .onAppear {
                                    if thumbnails[model.id] == nil {
                                        loadThumbnail(for: model)
                                    }
                                }
                                
                                NavigationLink(destination: ModelPreviewView(
                                    usdzURL: storage.modelURL(for: model),
                                    previewImageURL: storage.previewImageURL(for: model)
                                )) {
                                    EmptyView()
                                }
                                .opacity(0)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .contextMenu {
                                Button(role: .destructive) {
                                    storage.delete(model)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                Button { activeSheet = .capture } label: {
                    Label("New Scan", systemImage: "camera.viewfinder")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("My Scans")
            .fullScreenCover(item: $activeSheet) { sheet in
                switch sheet {
                case .capture:
                    CaptureView { imagesDir in
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            activeSheet = .reconstruction(imagesDir: imagesDir)
                        }
                    }

                case .reconstruction(let imagesDir):
                    ReconstructionView(
                        imagesDir: imagesDir,
                        onComplete: { usdzURL in
                            activeSheet = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                activeSheet = .metadata(modelURL: usdzURL)
                            }
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )

                case .metadata(let modelURL):
                    MetadataEntryView(
                        usdzURL: modelURL,
                        onSave: { id, name, _, categories, date, imageData in
                            saveModel(from: modelURL, id: id, name: name, categories: categories, date: date, imageData: imageData)
                            activeSheet = nil
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )
                }
            }
        }
    }

    private var filteredModels: [FurnitureModel] {
        storage.models.filter { $0.metadata.creatorId == session.currentUser.id ?? "" }
    }
    private func saveModel(from usdzURL: URL, id: UUID, name: String, categories: String, date: Date, imageData: Data?) {
        let modelID = id
        let fileName = "\(modelID).usdz"
        let creatorFullName = "\(session.currentUser.firstName) \(session.currentUser.lastName)"
        var previewImageFileName: String? = nil

        if let imageData = imageData {
            previewImageFileName = "\(modelID)_preview.jpg"
            let imageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Models")
                .appendingPathComponent(previewImageFileName!)
            try? imageData.write(to: imageURL)
        }

        let destURL = storage.modelURL(for: FurnitureModel(
            id: modelID,
            metadata: ModelMetadata(
                id: modelID,
                name: name,
                creator: creatorFullName,
                creatorId: session.currentUser.id ?? "",
                dateOfCreation: date,
                lastUpdated: .now,
                size: 0,
                modelReference: fileName,
                previewImageReference: previewImageFileName
            ),
            modelFileName: fileName
        ))

        do {
            try FileManager.default.copyItem(at: usdzURL, to: destURL)
            let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0

            let model = FurnitureModel(
                id: modelID,
                metadata: ModelMetadata(
                    id: modelID,
                    name: name,
                    creator: creatorFullName,
                    creatorId: session.currentUser.id ?? "",
                    dateOfCreation: date,
                    lastUpdated: .now,
                    size: size,
                    modelReference: fileName,
                    previewImageReference: previewImageFileName
                ),
                modelFileName: fileName
            )
            storage.save(model)

            uploadToAPI(
                modelID: modelID,
                name: name,
                categories: categories,
                size: Double(size) / 1_000_000,
                creatorFullName: creatorFullName,
                usdzURL: destURL,
                imageData: imageData
            )
        } catch {
            print("HomeView: failed to save model: \(error)")
        }
    }

    private func uploadToAPI(
        modelID: UUID,
        name: String,
        categories: String,
        size: Double,
        creatorFullName: String,
        usdzURL: URL,
        imageData: Data?
    ) {
        let controller = ModelController()
        let creatorId = session.currentUser.id ?? modelID.uuidString

        Task {
            do {
                let payload = CreateModelPayload(
                    creatorId: creatorId,
                    name: name,
                    creatorName: creatorFullName,
                    size: size,
                    categories: categories,
                    objectData: nil
                )
                let created = try await controller.create(payload: payload)

                guard let apiId = created.id else {
                    print("HomeView: API did not return a model ID")
                    return
                }

                try await controller.uploadUSDZ(id: apiId, fileURL: usdzURL)

                if let imageData = imageData {
                    try await controller.uploadPreviewImage(id: apiId, imageData: imageData, mimeType: "image/jpeg")
                }

                print("HomeView: model \(apiId) uploaded successfully")
            } catch {
                print("HomeView: API upload failed: \(error)")
            }
        }
    }

    private func loadThumbnail(for model: FurnitureModel) {
        let size = CGSize(width: 120, height: 120)
        let request = QLThumbnailGenerator.Request(
            fileAt: storage.modelURL(for: model),
            size: size,
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
            if let cgImage = thumbnail?.cgImage {
                DispatchQueue.main.async {
                    self.thumbnails[model.id] = UIImage(cgImage: cgImage)
                }
            }
        }
    }
}


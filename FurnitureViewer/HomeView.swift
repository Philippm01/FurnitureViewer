import SwiftUI

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
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if storage.models.isEmpty {
                        ContentUnavailableView {
                            Label("No Furniture Scanned", systemImage: "sofa.fill")
                        } description: {
                            Text("Tap the button below to scan your first 3D model.")
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(storage.models) { model in
                                    NavigationLink(destination: ModelPreviewView(usdzURL: storage.modelURL(for: model))) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "cube.transparent.fill")
                                                .font(.title)
                                                .foregroundStyle(.blue.gradient)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(model.metadata.creator)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text(model.metadata.dateOfCreation.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                                        )
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            storage.delete(model)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .navigationTitle("Furniture")


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
                        onSave: { creator in
                            saveModel(from: modelURL, creator: creator)
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


    private func saveModel(from usdzURL: URL, creator: String) {
        let modelID = UUID()
        let fileName = "\(modelID).usdz"
        let destURL = storage.modelURL(for: FurnitureModel(
            id: modelID,
            metadata: ModelMetadata(
                id: modelID,
                creator: creator,
                dateOfCreation: .now,
                lastUpdated: .now,
                size: 0,
                modelReference: fileName
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
                    creator: creator,
                    dateOfCreation: .now,
                    lastUpdated: .now,
                    size: size,
                    modelReference: fileName
                ),
                modelFileName: fileName
            )
            storage.save(model)
        } catch {
            print("HomeView: failed to save model: \(error)")
        }
    }

}

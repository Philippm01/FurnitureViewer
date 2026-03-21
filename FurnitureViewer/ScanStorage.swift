import Foundation
import Combine

struct ModelMetadata: Identifiable, Codable {
    var id: UUID
    var creator: String
    var dateOfCreation: Date
    var lastUpdated: Date
    var size: Int64
    var modelReference: String
}

struct FurnitureModel: Identifiable, Codable {
    var id: UUID
    var metadata: ModelMetadata
    var modelFileName: String
}

class ScanStorage: ObservableObject {
    @Published var models: [FurnitureModel] = []

    private let metadataDir: URL
    private let modelsDir: URL

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        metadataDir = base.appendingPathComponent("Metadata", isDirectory: true)
        modelsDir = base.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        load()
    }

    func save(_ model: FurnitureModel) {
        if let index = models.firstIndex(where: { $0.id == model.id }) {
            models[index] = model
        } else {
            models.append(model)
        }
        persist(model)
    }

    func delete(_ model: FurnitureModel) {
        models.removeAll { $0.id == model.id }
        let metaURL = metadataDir.appendingPathComponent("\(model.id).json")
        let modelURL = modelsDir.appendingPathComponent(model.modelFileName)
        try? FileManager.default.removeItem(at: metaURL)
        try? FileManager.default.removeItem(at: modelURL)
    }

    func modelURL(for model: FurnitureModel) -> URL {
        modelsDir.appendingPathComponent(model.modelFileName)
    }

    private func persist(_ model: FurnitureModel) {
        let url = metadataDir.appendingPathComponent("\(model.id).json")
        if let data = try? JSONEncoder().encode(model) {
            try? data.write(to: url)
        }
    }

    private func load() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: metadataDir, includingPropertiesForKeys: nil) else { return }
        models = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(FurnitureModel.self, from: data)
            }
            .sorted { $0.metadata.dateOfCreation > $1.metadata.dateOfCreation }
    }
}

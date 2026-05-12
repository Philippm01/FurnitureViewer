import Foundation

struct FurnitureAPIModel: Codable, Identifiable {
    var id: String?
    var name: String
    var creatorName: String
    var categories: String
    var size: Double?
    var previewImage: String?   
    var createdAt: String?
    var updatedAt: String?

    var creatorId: String?
    var reference: String?
    var objectData: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorName    = "creator_name"
        case categories
        case size
        case previewImage   = "preview_image"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
        case creatorId      = "creator_id"
        case reference
        case objectData     = "object_data"
    }
}

struct CreateModelPayload: Encodable {
    var creatorId: String
    var name: String
    var creatorName: String
    var size: Double
    var categories: String
    var objectData: [String: String]?

    enum CodingKeys: String, CodingKey {
        case creatorId   = "creator_id"
        case name
        case creatorName = "creator_name"
        case size
        case categories
        case objectData  = "object_data"
    }
}

struct UpdateModelPayload: Encodable {
    var name: String?
    var size: Double?
    var categories: String?
    var reference: String?
    var objectData: [String: String]?

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case categories
        case reference
        case objectData = "object_data"
    }
}

struct ShareRequest: Encodable {
    var senderId: String
    var receiverId: String
    var modelId: String

    enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case modelId = "model_id"
    }
}

class ModelController {
    private let baseURL = APIConfig.modelsURL

    func discover(page: Int = 1) async throws -> [FurnitureAPIModel] {
        var components = URLComponents(string: "\(baseURL)/discover")!
        components.queryItems = [URLQueryItem(name: "page", value: "\(page)")]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([FurnitureAPIModel].self, from: data)
    }

    func search(name: String, category: String) async throws -> [FurnitureAPIModel] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "category", value: category)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([FurnitureAPIModel].self, from: data)
    }

    func get(id: String) async throws -> FurnitureAPIModel {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(FurnitureAPIModel.self, from: data)
    }

    func create(payload: CreateModelPayload) async throws -> FurnitureAPIModel {
        guard let url = URL(string: "\(baseURL)/") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(FurnitureAPIModel.self, from: data)
    }

    func update(id: String, payload: UpdateModelPayload) async throws -> FurnitureAPIModel {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(FurnitureAPIModel.self, from: data)
    }

    func delete(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await URLSession.shared.data(for: request)
    }

    func uploadUSDZ(id: String, fileURL: URL) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)/upload") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try buildMultipart(boundary: boundary, fieldName: "file",
                                              fileName: fileURL.lastPathComponent,
                                              data: Data(contentsOf: fileURL),
                                              mimeType: "application/octet-stream")
        _ = try await URLSession.shared.data(for: request)
    }

    func downloadUSDZ(id: String) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/\(id)/download") else { throw URLError(.badURL) }
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).usdz")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    func upload(id: String, fileURL: URL) async throws { try await uploadUSDZ(id: id, fileURL: fileURL) }
    func download(id: String) async throws -> URL     { try await downloadUSDZ(id: id) }

    func uploadPreviewImage(id: String, imageData: Data, mimeType: String = "image/jpeg") async throws {
        guard let url = URL(string: "\(baseURL)/\(id)/upload_preview") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try buildMultipart(boundary: boundary, fieldName: "image",
                                              fileName: "preview.jpg",
                                              data: imageData,
                                              mimeType: mimeType)
        _ = try await URLSession.shared.data(for: request)
    }

    func downloadPreview(id: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/\(id)/preview") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    func shareModel(request: ShareRequest) async throws {
        guard let url = URL(string: APIConfig.shareURL) else { throw URLError(.badURL) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        _ = try await URLSession.shared.data(for: urlRequest)
    }

    func getReceivedModels(userId: String) async throws -> [FurnitureAPIModel] {
        guard let url = URL(string: "\(APIConfig.receivedURL)/\(userId)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([FurnitureAPIModel].self, from: data)
    }

    private func buildMultipart(boundary: String,
                                fieldName: String,
                                fileName: String,
                                data: Data,
                                mimeType: String) throws -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}

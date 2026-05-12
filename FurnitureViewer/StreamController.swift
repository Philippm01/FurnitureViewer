import Foundation
import Combine

struct StreamSessionResponse: Codable {
    var streamId: String
    var hostWs: String
    var viewerWs: String

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case hostWs = "host_ws"
        case viewerWs = "viewer_ws"
    }
}

struct StreamCallRequest: Encodable {
    var callerId: String
    var receiverId: String
    
    enum CodingKeys: String, CodingKey {
        case callerId = "caller_id"
        case receiverId = "receiver_id"
    }
}

struct IncomingCallResponse: Codable {
    var callId: String?
    var streamId: String?
    var callerId: String?
    var status: String?
    
    enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case streamId = "stream_id"
        case callerId = "caller_id"
        case status
    }
}

class StreamController: NSObject, ObservableObject {
    @Published var isStreaming = false
    @Published var session: StreamSessionResponse?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let sessionURL = APIConfig.streamSessionURL

    func createSession() async throws -> StreamSessionResponse {
        guard let url = URL(string: sessionURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StreamSessionResponse.self, from: data)
        return response
    }

    func initiateCall(callerId: String, receiverId: String) async throws -> IncomingCallResponse {
        guard let url = URL(string: APIConfig.streamCallURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = StreamCallRequest(callerId: callerId, receiverId: receiverId)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(IncomingCallResponse.self, from: data)
    }

    func checkIncomingCalls(userId: String) async throws -> [IncomingCallResponse] {
        var components = URLComponents(string: APIConfig.streamIncomingURL)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        guard let url = components.url else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([IncomingCallResponse].self, from: data)
    }

    func startHost(wsURL: String) {
        guard let url = URL(string: wsURL) else { return }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isStreaming = true
        print("Started hosting stream at \(wsURL)")
    }

    func startViewer(wsURL: String) {
        guard let url = URL(string: wsURL) else { return }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isStreaming = true
        receiveMessage()
        print("Started viewing stream at \(wsURL)")
    }

    func stop() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isStreaming = false
        print("Stream stopped")
    }

    func sendMessage(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received string: \(text)")
                    // In a real AR app, we would parse this to update the view
                case .data(let data):
                    print("Received data: \(data.count) bytes")
                @unknown default:
                    break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async { self?.isStreaming = false }
            }
        }
    }
}

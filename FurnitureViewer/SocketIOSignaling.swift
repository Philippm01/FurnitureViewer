import Foundation
import Combine
import SwiftUI

protocol SocketIOSignalingDelegate: AnyObject {
    func signalingDidReceiveCall(callerId: String, streamId: String, modelId: String)
    func signalingDidReceiveCallResponse(accepted: Bool)
    func signalingDidReceiveOffer(sdp: String)
    func signalingDidReceiveAnswer(sdp: String)
    func signalingDidReceiveIceCandidate(candidate: String)
}

class SocketIOSignaling: NSObject, ObservableObject {
    weak var delegate: SocketIOSignalingDelegate?
    private var webSocketTask: URLSessionWebSocketTask?
    private var currentUserId: String = ""
    private let urlString = APIConfig.host.replacingOccurrences(of: "http://", with: "ws://") + "/socket.io/?EIO=4&transport=websocket"
    
    func connect(userId: String) {
        self.currentUserId = userId
        guard let url = URL(string: urlString) else { return }
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
        
        // Wait briefly for Engine.IO handshake, then send Socket.IO connect (40)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendEngineIOPacket(type: "40", payload: nil)
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
    }
    
    // MARK: - Emitting Events
    
    func callUser(receiverId: String, callerId: String, streamId: String, modelId: String) {
        let payload: [String: Any] = [
            "receiver_id": receiverId,
            "caller_id": callerId,
            "stream_id": streamId,
            "model_id": modelId
        ]
        emit(event: "call_user", payload: payload)
    }
    
    func respondToCall(callerId: String, accepted: Bool) {
        let payload: [String: Any] = ["caller_id": callerId, "accepted": accepted]
        emit(event: "call_response", payload: payload)
    }
    
    func sendOffer(receiverId: String, sdp: String) {
        guard let myId = Session.shared.currentUser?.id else { return }
        let payload: [String: Any] = ["receiver_id": receiverId, "caller_id": myId, "sdp": sdp]
        emit(event: "webrtc_offer", payload: payload)
    }
    
    func sendAnswer(callerId: String, sdp: String) {
        guard let myId = Session.shared.currentUser?.id else { return }
        let payload: [String: Any] = ["caller_id": callerId, "receiver_id": myId, "sdp": sdp]
        emit(event: "webrtc_answer", payload: payload)
    }
    
    func sendIceCandidate(targetId: String, candidate: String) {
        guard let myId = Session.shared.currentUser?.id else { return }
        let payload: [String: Any] = ["target_id": targetId, "sender_id": myId, "candidate": candidate]
        emit(event: "webrtc_ice_candidate", payload: payload)
    }
    
    private func emit(event: String, payload: [String: Any]) {
        let data: [Any] = [event, payload]
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Emitting SocketIO packet: \(jsonString)")
            sendEngineIOPacket(type: "42", payload: jsonString)
        }
    }
    
    private func sendEngineIOPacket(type: String, payload: String?) {
        let messageString = type + (payload ?? "")
        let message = URLSessionWebSocketTask.Message.string(messageString)
        webSocketTask?.send(message) { error in
            if let error = error { print("WebSocket send error: \(error)") }
        }
    }
    
    // MARK: - Receiving Events
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleEngineIOPacket(text)
                case .data(_): break
                @unknown default: break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            }
        }
    }
    
    private func handleEngineIOPacket(_ packet: String) {
        print("EngineIO Packet: \(packet)")
        if packet.starts(with: "2") {
            sendEngineIOPacket(type: "3", payload: nil)
            return
        }
        
        if packet.starts(with: "40") {
            print("SocketIO Handshake confirmed. Emitting register...")
            let payload: [String: Any] = ["user_id": currentUserId]
            self.emit(event: "register", payload: payload)
            return
        }
        
        if packet.starts(with: "42") {
            let payloadString = String(packet.dropFirst(2))
            guard let data = payloadString.data(using: .utf8),
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  jsonArray.count >= 2,
                  let event = jsonArray[0] as? String else { return }
            
            let payload = (jsonArray[1] as? [String: Any]) ?? [:]
            print("SocketIO Event: \(event), Payload: \(payload)")
            
            DispatchQueue.main.async {
                self.routeEvent(event, payload: payload)
            }
        }
    }
    
    private func routeEvent(_ event: String, payload: [String: Any]) {
        switch event {
        case "incoming_call":
            let callerId = (payload["caller_id"] as? String) ?? (payload["callerId"] as? String) ?? ""
            let streamId = (payload["stream_id"] as? String) ?? (payload["streamId"] as? String) ?? ""
            let modelId = (payload["model_id"] as? String) ?? (payload["modelId"] as? String) ?? ""
            
            if !callerId.isEmpty {
                delegate?.signalingDidReceiveCall(callerId: callerId, streamId: streamId, modelId: modelId)
            }
        case "call_response":
            if let accepted = payload["accepted"] as? Bool {
                delegate?.signalingDidReceiveCallResponse(accepted: accepted)
            }
        case "webrtc_offer":
            if let sdp = payload["sdp"] as? String {
                delegate?.signalingDidReceiveOffer(sdp: sdp)
            }
        case "webrtc_answer":
            if let sdp = payload["sdp"] as? String {
                delegate?.signalingDidReceiveAnswer(sdp: sdp)
            }
        case "webrtc_ice_candidate":
            if let candidate = payload["candidate"] as? String {
                delegate?.signalingDidReceiveIceCandidate(candidate: candidate)
            }
        default:
            break
        }
    }
}

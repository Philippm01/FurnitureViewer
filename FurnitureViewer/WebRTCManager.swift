import Foundation
import WebRTC
import Combine

class WebRTCManager: NSObject, ObservableObject, SocketIOSignalingDelegate, WebRTCClientDelegate {
    @Published var remoteVideoTrack: RTCVideoTrack?
    @Published var isConnected = false
    @Published var incomingCallStreamId: String?
    @Published var incomingCallerId: String?
    
    let signaling = SocketIOSignaling()
    let webRTC = WebRTCClient()
    
    var currentUserId: String = ""
    var targetId: String = "" // The other peer
    var isHost: Bool = false
    
    override init() {
        super.init()
        signaling.delegate = self
        webRTC.delegate = self
    }
    
    deinit {
        disconnect()
    }
    
    func start(userId: String) {
        currentUserId = userId
        signaling.connect(userId: userId)
    }
    
    func disconnect() {
        endCall()
        signaling.disconnect()
    }
    
    func endCall() {
        webRTC.close()
        remoteVideoTrack = nil
        isConnected = false
        incomingCallStreamId = nil
        incomingCallerId = nil
        isHost = false
        targetId = ""
    }
    
    // MARK: - Hosting Call
    func callTarget(targetId: String, streamId: String, modelId: String) {
        self.isHost = true
        self.targetId = targetId
        webRTC.setupPeerConnectionIfNeeded()
        signaling.callUser(receiverId: targetId, callerId: currentUserId, streamId: streamId, modelId: modelId)
    }
    
    func respondToCall(accepted: Bool) {
        self.isHost = false
        if accepted {
            webRTC.setupPeerConnectionIfNeeded()
        }
        signaling.respondToCall(callerId: targetId, accepted: accepted)
    }
    
    // MARK: - SocketIOSignalingDelegate
    
    func signalingDidReceiveCall(callerId: String, streamId: String, modelId: String) {
        DispatchQueue.main.async {
            self.incomingCallerId = callerId
            self.incomingCallStreamId = streamId
            self.targetId = callerId
        }
    }
    
    func signalingDidReceiveCallResponse(accepted: Bool) {
        if accepted && isHost {
            // Receiver accepted. Host generates Offer
            webRTC.generateOffer { [weak self] sdp in
                guard let self = self else { return }
                self.signaling.sendOffer(receiverId: self.targetId, sdp: sdp.sdp)
            }
        }
    }
    
    func signalingDidReceiveOffer(sdp: String) {
        webRTC.setRemoteDescription(sdp: sdp, type: .offer)
        webRTC.generateAnswer { [weak self] answer in
            guard let self = self else { return }
            self.signaling.sendAnswer(callerId: self.targetId, sdp: answer.sdp)
        }
    }
    
    func signalingDidReceiveAnswer(sdp: String) {
        webRTC.setRemoteDescription(sdp: sdp, type: .answer)
    }
    
    func signalingDidReceiveIceCandidate(candidate: String) {
        // A minimal implementation would parse the JSON candidate here.
        // For simplicity, we just add it to WebRTC. (In production, parse sdpMid and sdpMLineIndex).
        webRTC.addIceCandidate(sdp: candidate, sdpMLineIndex: 0, sdpMid: nil)
    }
    
    // MARK: - WebRTCClientDelegate
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        // Send candidate to target
        signaling.sendIceCandidate(targetId: targetId, candidate: candidate.sdp)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            self.isConnected = (state == .connected || state == .completed)
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {}
    
    func webRTCClient(_ client: WebRTCClient, didReceiveVideoTrack track: RTCVideoTrack) {
        DispatchQueue.main.async {
            self.remoteVideoTrack = track
        }
    }
}

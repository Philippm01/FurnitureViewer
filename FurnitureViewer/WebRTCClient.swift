import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
    func webRTCClient(_ client: WebRTCClient, didReceiveVideoTrack track: RTCVideoTrack)
}

class WebRTCClient: NSObject {
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    weak var delegate: WebRTCClientDelegate?
    private var peerConnection: RTCPeerConnection?
    private var videoSource: RTCVideoSource?
    private var localVideoTrack: RTCVideoTrack?
    
    override init() {
        super.init()
        setupPeerConnection()
    }
    
    func setupPeerConnectionIfNeeded() {
        if peerConnection == nil {
            setupPeerConnection()
        }
    }
    
    private func setupPeerConnection() {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: self)
        
        // Create video source for the AR frames
        videoSource = WebRTCClient.factory.videoSource()
        if let source = videoSource {
            localVideoTrack = WebRTCClient.factory.videoTrack(with: source, trackId: "AR_VIDEO_TRACK")
            if let track = localVideoTrack {
                peerConnection?.add(track, streamIds: ["AR_STREAM"])
            }
        }
    }
    
    func captureFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        let rtcBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let frame = RTCVideoFrame(buffer: rtcBuffer, rotation: ._0, timeStampNs: Int64(timestamp.seconds * 1_000_000_000))
        videoSource?.capturer(RTCVideoCapturer(delegate: videoSource!), didCapture: frame)
    }
    
    func generateOffer(completion: @escaping (RTCSessionDescription) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else { return }
            self?.peerConnection?.setLocalDescription(sdp, completionHandler: { _ in
                completion(sdp)
            })
        }
    }
    
    func generateAnswer(completion: @escaping (RTCSessionDescription) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)
        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else { return }
            self?.peerConnection?.setLocalDescription(sdp, completionHandler: { _ in
                completion(sdp)
            })
        }
    }
    
    func setRemoteDescription(sdp: String, type: RTCSdpType) {
        let description = RTCSessionDescription(type: type, sdp: sdp)
        peerConnection?.setRemoteDescription(description, completionHandler: { error in
            if let error = error { print("Failed to set remote description: \(error)") }
        })
    }
    
    func addIceCandidate(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        peerConnection?.add(candidate)
    }
    
    func close() {
        peerConnection?.close()
        peerConnection = nil
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let videoTrack = stream.videoTracks.first {
            delegate?.webRTCClient(self, didReceiveVideoTrack: videoTrack)
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

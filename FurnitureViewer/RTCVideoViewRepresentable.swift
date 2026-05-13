import SwiftUI
import WebRTC

struct RTCVideoViewRepresentable: UIViewRepresentable {
    let videoTrack: RTCVideoTrack
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        videoTrack.add(view)
        return view
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {}
}

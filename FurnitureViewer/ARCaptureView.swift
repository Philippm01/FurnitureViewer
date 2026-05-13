import SwiftUI
import RealityKit
import ARKit

struct ARCaptureView: UIViewRepresentable {
    let usdzURL: URL
    let onFrameCaptured: (CVPixelBuffer, CMTime) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        // Load model
        Task {
            if let entity = try? Entity.load(contentsOf: usdzURL) {
                let anchor = AnchorEntity(plane: .horizontal)
                anchor.addChild(entity)
                await MainActor.run {
                    arView.scene.addAnchor(anchor)
                    // Start capture loop once model is added
                    context.coordinator.startCapture(arView: arView)
                }
            }
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stopCapture()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARCaptureView
        weak var arView: ARView?
        var displayLink: CADisplayLink?
        var isCapturing = false
        
        init(_ parent: ARCaptureView) {
            self.parent = parent
            super.init()
        }
        
        func startCapture(arView: ARView) {
            self.arView = arView
            displayLink = CADisplayLink(target: self, selector: #selector(captureFrame))
            displayLink?.preferredFramesPerSecond = 30
            displayLink?.add(to: .main, forMode: .common)
        }
        
        func stopCapture() {
            displayLink?.invalidate()
            displayLink = nil
        }
        
        @objc func captureFrame() {
            guard !isCapturing, let arView = arView else { return }
            isCapturing = true
            
            arView.snapshot(saveToHDR: false) { [weak self] image in
                guard let self = self, let image = image else {
                    self?.isCapturing = false
                    return
                }
                
                // Process off main thread
                DispatchQueue.global(qos: .userInteractive).async {
                    if let pixelBuffer = self.pixelBuffer(from: image) {
                        let timestamp = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
                        self.parent.onFrameCaptured(pixelBuffer, timestamp)
                    }
                    self.isCapturing = false
                }
            }
        }
        
        private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
            guard let cgImage = image.cgImage else { return nil }
            let width = cgImage.width
            let height = cgImage.height
            
            let attrs = [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
            ] as CFDictionary
            
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
            
            CVPixelBufferLockBaseAddress(buffer, [])
            let pixelData = CVPixelBufferGetBaseAddress(buffer)
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: pixelData,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            
            if let context = context {
                // 1. Apply the original working transform that successfully displayed the video stream
                context.translateBy(x: 0, y: CGFloat(height))
                context.scaleBy(x: 1.0, y: -1.0)
                
                // 2. Apply a 180-degree rotation around the center to fix the upside-down orientation
                context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
                context.rotate(by: .pi)
                context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
                
                let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
                context.draw(cgImage, in: rect)
            }
            
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return buffer
        }
    }
}

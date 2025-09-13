import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        
        // Set up preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update preview layer frame on orientation changes
        DispatchQueue.main.async {
            uiView.previewLayer?.frame = uiView.bounds
        }
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

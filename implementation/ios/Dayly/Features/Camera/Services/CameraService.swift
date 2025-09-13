import AVFoundation
import UIKit
import Combine

protocol CameraServiceProtocol {
    func checkPermissions() async -> Bool
    func requestPermissions() async -> Bool
    func capturePhoto() async throws -> UIImage
    func toggleCamera()
    func toggleFlash()
    func startSession()
    func stopSession()
    var isFlashOn: Bool { get }
    var isFrontCamera: Bool { get }
    var captureSession: AVCaptureSession { get }
}

@MainActor
class CameraService: NSObject, CameraServiceProtocol, ObservableObject {
    @Published var isFlashOn = false
    @Published var isFrontCamera = false
    @Published var isSessionRunning = false
    
    private(set) var captureSession: AVCaptureSession
    private var photoOutput: AVCapturePhotoOutput?
    private var currentCamera: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        self.captureSession = AVCaptureSession()
        super.init()
        setupCaptureSession()
    }
    
    // MARK: - Permissions
    
    func checkPermissions() async -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    func requestPermissions() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
    
    // MARK: - Session Management
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            // Add video input
            if let camera = self.getCamera(position: .back) {
                self.currentCamera = camera
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    if self.captureSession.canAddInput(input) {
                        self.captureSession.addInput(input)
                        self.videoInput = input
                    }
                } catch {
                    print("Error setting up camera input: \(error)")
                }
            }
            
            // Add photo output
            let output = AVCapturePhotoOutput()
            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
                self.photoOutput = output
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    private func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        return discoverySession.devices.first
    }
    
    // MARK: - Camera Controls
    
    func toggleCamera() {
        isFrontCamera.toggle()
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Remove current input
            if let currentInput = self.videoInput {
                self.captureSession.removeInput(currentInput)
            }
            
            // Add new input
            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            if let camera = self.getCamera(position: position) {
                self.currentCamera = camera
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    if self.captureSession.canAddInput(input) {
                        self.captureSession.addInput(input)
                        self.videoInput = input
                    }
                } catch {
                    print("Error switching camera: \(error)")
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            
            let settings = AVCapturePhotoSettings()
            
            // Configure flash
            if self.currentCamera?.hasFlash == true {
                settings.flashMode = self.isFlashOn ? .on : .off
            }
            
            // Capture photo
            self.photoOutput?.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            photoContinuation?.resume(throwing: error)
            photoContinuation = nil
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: CameraError.processingFailed)
            photoContinuation = nil
            return
        }
        
        // Correct orientation for front camera
        let orientedImage = isFrontCamera ? image.mirrored() : image
        
        photoContinuation?.resume(returning: orientedImage)
        photoContinuation = nil
    }
}

// MARK: - Camera Errors

enum CameraError: LocalizedError {
    case processingFailed
    case noCamera
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .processingFailed:
            return "Failed to process the photo"
        case .noCamera:
            return "No camera available"
        case .permissionDenied:
            return "Camera permission denied"
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func mirrored() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        
        let flippedImage = UIImage(
            cgImage: cgImage,
            scale: self.scale,
            orientation: self.imageOrientation == .leftMirrored ? .left : .leftMirrored
        )
        
        return flippedImage
    }
}

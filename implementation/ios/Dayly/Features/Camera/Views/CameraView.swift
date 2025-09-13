import SwiftUI
import AVFoundation

struct CameraView: View {
    let group: GroupViewModel
    @StateObject private var cameraService = CameraService()
    @StateObject private var viewModel: CameraViewModel
    @Environment(\.dismiss) var dismiss
    @State private var capturedImage: UIImage?
    @State private var showingDaylyLimit = false
    @State private var showingPermissionDenied = false
    @State private var isCapturing = false
    
    init(group: GroupViewModel) {
        self.group = group
        self._viewModel = StateObject(wrappedValue: CameraViewModel(groupId: group.id))
    }
    
    var body: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
                .onAppear {
                    cameraService.startSession()
                }
                .onDisappear {
                    cameraService.stopSession()
                }
            
            // Controls overlay
            VStack {
                // Top bar
                HStack {
                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    // Group name
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    
                    Spacer()
                    
                    // Flash toggle
                    Button(action: { cameraService.toggleFlash() }) {
                        Image(systemName: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 60) {
                    // Empty space for balance
                    Color.clear.frame(width: 60, height: 60)
                    
                    // Capture button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            if isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isCapturing || viewModel.isCapturing)
                    
                    // Camera flip
                    Button(action: { cameraService.toggleCamera() }) {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(.white)
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.bottom, 50)
            }
            
            // Loading overlay
            if viewModel.isCapturing {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Sending photo...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Check permissions
            if !await cameraService.checkPermissions() {
                let granted = await cameraService.requestPermissions()
                if !granted {
                    showingPermissionDenied = true
                    return
                }
            }
            
            // Check daily limit
            if await viewModel.hasAlreadySentToday() {
                showingDaylyLimit = true
            }
        }
        .sheet(item: Binding(
            get: { capturedImage },
            set: { capturedImage = $0 }
        )) { _ in
            if let image = capturedImage {
                PhotoPreviewView(
                    image: image,
                    groupName: group.name,
                    onSend: {
                        Task {
                            await viewModel.sendPhoto(image)
                            dismiss()
                        }
                    },
                    onRetake: {
                        capturedImage = nil
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showingDaylyLimit) {
            DaylyLimitView(groupName: group.name) {
                dismiss()
            }
        }
        .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
            Button("Go to Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel") {
                dismiss()
            }
        } message: {
            Text("Dayly needs camera access to share photos. Please enable camera access in Settings.")
        }
    }
    
    private func capturePhoto() {
        isCapturing = true
        
        Task {
            do {
                let image = try await cameraService.capturePhoto()
                await MainActor.run {
                    capturedImage = image
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                    // Handle error
                    print("Failed to capture photo: \(error)")
                }
            }
        }
    }
}

// Helper extension to make UIImage conform to Identifiable
extension UIImage: Identifiable {
    public var id: String {
        return UUID().uuidString
    }
}

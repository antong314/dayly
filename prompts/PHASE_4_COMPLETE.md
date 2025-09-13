# Phase 4: Camera & Photo Capture

## App Context
You are building "Dayly" - a minimalist photo-sharing app where users can share one photo per day with small groups of close friends/family. The app's philosophy is about meaningful, intentional sharing rather than endless content.

**Core Features:**
- One photo per day per group limit
- Small groups (max 12 people)
- Photos disappear after 48 hours
- No comments, likes, or social features
- Phone number authentication

## Technical Stack
- **iOS**: SwiftUI, minimum iOS 15.0
- **Backend**: Python 3.11+ with FastAPI
- **Database**: Supabase (PostgreSQL with auth, storage, realtime)
- **Storage**: Supabase Storage for photos
- **Deployment**: DigitalOcean App Platform

## Current Status
Phases 0-3 are complete with:
- Authentication system working
- Core Data models for offline support
- Groups management UI and API
- Users can create and view groups
- Navigation structure in place

## Your Task: Phase 4 - Camera & Photo Capture

Implement the camera system with daily limit enforcement.

### Camera Service

**Create: `implementation/ios/Dayly/Features/Camera/Services/CameraService.swift`**
```swift
import AVFoundation
import UIKit

protocol CameraServiceProtocol {
    func checkPermissions() async -> Bool
    func requestPermissions() async -> Bool
    func capturePhoto() async throws -> UIImage
    func toggleCamera()
    func toggleFlash()
    var isFlashOn: Bool { get }
    var isFrontCamera: Bool { get }
}

@MainActor
class CameraService: NSObject, CameraServiceProtocol, ObservableObject {
    @Published var isFlashOn = false
    @Published var isFrontCamera = false
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentCamera: AVCaptureDevice?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    func checkPermissions() async -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    func requestPermissions() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
    
    private func setupCaptureSession() {
        // Configure capture session
        // Set up front/back camera
        // Configure photo output
    }
    
    func capturePhoto() async throws -> UIImage {
        // Capture photo
        // Convert to UIImage
        // Return processed image
    }
    
    func toggleCamera() {
        isFrontCamera.toggle()
        // Switch between front and back camera
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
        // Update flash mode
    }
}
```

### Camera View

**Create: `implementation/ios/Dayly/Features/Camera/Views/CameraView.swift`**
```swift
import SwiftUI
import AVFoundation

struct CameraView: View {
    let group: GroupViewModel
    @StateObject private var cameraService = CameraService()
    @StateObject private var viewModel: CameraViewModel
    @Environment(\.dismiss) var dismiss
    @State private var capturedImage: UIImage?
    @State private var showingDaylyLimit = false
    
    init(group: GroupViewModel) {
        self.group = group
        self._viewModel = StateObject(wrappedValue: CameraViewModel(groupId: group.id))
    }
    
    var body: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
            
            // Controls overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    
                    Spacer()
                    
                    // Flash toggle
                    Button(action: { cameraService.toggleFlash() }) {
                        Image(systemName: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 60) {
                    // Empty space for balance
                    Color.clear.frame(width: 40, height: 40)
                    
                    // Capture button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                        }
                    }
                    .disabled(viewModel.isCapturing)
                    
                    // Camera flip
                    Button(action: { cameraService.toggleCamera() }) {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(.white)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .task {
            // Check permissions
            if !await cameraService.checkPermissions() {
                _ = await cameraService.requestPermissions()
            }
            
            // Check daily limit
            if await viewModel.hasAlreadySentToday() {
                showingDaylyLimit = true
            }
        }
        .sheet(item: $capturedImage) { _ in
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
    }
    
    private func capturePhoto() {
        Task {
            do {
                capturedImage = try await cameraService.capturePhoto()
            } catch {
                // Handle error
            }
        }
    }
}
```

### Camera Preview

**Create: `implementation/ios/Dayly/Features/Camera/Views/CameraPreviewView.swift`**
```swift
import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        // Set up preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
}
```

### Photo Preview

**Create: `implementation/ios/Dayly/Features/Camera/Views/PhotoPreviewView.swift`**
```swift
struct PhotoPreviewView: View {
    let image: UIImage
    let groupName: String
    let onSend: () -> Void
    let onRetake: () -> Void
    
    @State private var timeRemaining = 3
    @State private var timerActive = true
    
    var body: some View {
        ZStack {
            // Full screen image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Overlay
            VStack {
                // Auto-dismiss timer
                if timerActive {
                    Text("\(timeRemaining)")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .padding(.top, 100)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 20) {
                    Button(action: {
                        timerActive = false
                        onSend()
                    }) {
                        Text("Send to \(groupName)")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(25)
                    }
                    
                    Button(action: {
                        timerActive = false
                        onRetake()
                    }) {
                        Text("Retake")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startTimer()
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                timerActive = false
                onSend()
            }
        }
    }
}
```

### Dayly Limit View

**Create: `implementation/ios/Dayly/Features/Camera/Views/DaylyLimitView.swift`**
```swift
struct DaylyLimitView: View {
    let groupName: String
    let onDismiss: () -> Void
    @State private var timeUntilMidnight = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "clock.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("Already shared today")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("You've already shared a photo with \(groupName) today.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("See you tomorrow!")
                .font(.title2)
                .fontWeight(.medium)
            
            // Countdown
            VStack(spacing: 8) {
                Text("Next photo in")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(timeUntilMidnight)
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            
            Spacer()
            
            Button(action: onDismiss) {
                Text("OK")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .onAppear {
            updateCountdown()
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                updateCountdown()
            }
        }
    }
    
    private func updateCountdown() {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.startOfDay(for: now).addingTimeInterval(86400)
        let components = calendar.dateComponents([.hour, .minute, .second], from: now, to: tomorrow)
        
        if let hours = components.hour, let minutes = components.minute, let seconds = components.second {
            timeUntilMidnight = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}
```

### Camera View Model

**Create: `implementation/ios/Dayly/Features/Camera/ViewModels/CameraViewModel.swift`**
```swift
@MainActor
class CameraViewModel: ObservableObject {
    @Published var isCapturing = false
    @Published var error: Error?
    
    private let groupId: UUID
    private let photoRepository: PhotoRepositoryProtocol
    private let networkService: NetworkService
    
    init(
        groupId: UUID,
        photoRepository: PhotoRepositoryProtocol = PhotoRepository(),
        networkService: NetworkService = NetworkService.shared
    ) {
        self.groupId = groupId
        self.photoRepository = photoRepository
        self.networkService = networkService
    }
    
    func hasAlreadySentToday() async -> Bool {
        // Check daily_sends table
        do {
            let response = try await networkService.checkDaylySend(groupId: groupId)
            return response.hasSent
        } catch {
            // Check local cache if offline
            return false
        }
    }
    
    func sendPhoto(_ image: UIImage) async {
        isCapturing = true
        
        do {
            // Process image
            let processedImage = await processImage(image)
            
            // Convert to JPEG
            guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
                throw PhotoError.processingFailed
            }
            
            // Save locally first
            let photo = Photo(
                groupId: groupId,
                imageData: imageData,
                createdAt: Date()
            )
            try await photoRepository.savePhoto(photo)
            
            // Upload to backend (will be implemented in Phase 5)
            // For now, just mark as complete
            
        } catch {
            self.error = error
        }
        
        isCapturing = false
    }
    
    private func processImage(_ image: UIImage) async -> UIImage {
        // Resize to max 2048x2048
        // Strip EXIF data
        // Return processed image
        return image // Placeholder
    }
}
```

### Update Groups View

Update `GroupsListView.swift` to navigate to camera:
```swift
GroupCard(group: group)
    .onTapGesture {
        selectedGroup = group
        showCamera = true
    }
    .fullScreenCover(item: $selectedGroup) { group in
        CameraView(group: group)
    }
```

## Image Processing

**Create: `implementation/ios/Dayly/Core/Utils/ImageProcessor.swift`**
```swift
import UIKit
import CoreImage

class ImageProcessor {
    static func processForUpload(_ image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 2048
        
        // Calculate new size
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        
        if ratio >= 1 {
            return image // Already small enough
        }
        
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        // Resize
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    static func stripEXIFData(from imageData: Data) -> Data? {
        // Remove EXIF metadata for privacy
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else { return nil }
        
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData as CFMutableData,
            uti,
            1,
            nil
        ) else { return nil }
        
        // Copy image without metadata
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        CGImageDestinationFinalize(destination)
        
        return destinationData as Data
    }
}
```

## Testing

1. **Test Camera Permissions:**
   - First launch requests permission
   - Denied permission shows appropriate UI
   - Settings deep link if needed

2. **Test Photo Capture:**
   - Photo captures correctly
   - Flash toggle works
   - Camera flip works
   - Preview shows for 3 seconds

3. **Test Dayly Limit:
   - Can send one photo per group per day
   - Shows countdown after sending
   - Resets at midnight local time

4. **Test Image Processing:**
   - Large images resized to 2048px max
   - EXIF data removed
   - JPEG compression applied

## Success Criteria
- [ ] Camera opens when tapping group
- [ ] Can capture photos with flash/camera toggle
- [ ] Preview auto-advances after 3 seconds
- [ ] Dayly limit enforced per group
- [ ] Countdown timer shows time until midnight
- [ ] Images processed (resized, EXIF stripped)
- [ ] Error states handled gracefully
- [ ] Photos saved locally via repository
- [ ] Camera permissions handled properly

## Next Phase Preview
Phase 5 will implement the photo upload system to Supabase Storage with retry logic and progress tracking.

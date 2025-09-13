# Phase 6: Photo Viewing Experience

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
Phases 0-5 are complete with:
- Full authentication and groups system
- Camera capture with daily limits
- Photo upload to Supabase Storage
- Background upload support
- Sync system for offline/online

## Your Task: Phase 6 - Photo Viewing Experience

Implement the photo viewer with swipe navigation and caching.

### Photo Viewer UI

**Create: `implementation/ios/Dayly/Features/Photos/Views/PhotoViewerView.swift`**
```swift
import SwiftUI

struct PhotoViewerView: View {
    let groupId: UUID
    let groupName: String
    
    @StateObject private var viewModel: PhotoViewerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex = 0
    @State private var showingOverlay = true
    
    init(groupId: UUID, groupName: String) {
        self.groupId = groupId
        self.groupName = groupName
        self._viewModel = StateObject(wrappedValue: PhotoViewerViewModel(groupId: groupId))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.photos.isEmpty && !viewModel.isLoading {
                EmptyPhotosView(groupName: groupName)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoView(photo: photo)
                            .tag(index)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingOverlay.toggle()
                                }
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
            
            // Overlay with metadata
            if showingOverlay && !viewModel.photos.isEmpty {
                VStack {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        Text(groupName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                        
                        Spacer()
                        
                        // Page indicator
                        if viewModel.photos.count > 1 {
                            Text("\(currentIndex + 1) / \(viewModel.photos.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom metadata
                    if currentIndex < viewModel.photos.count {
                        let photo = viewModel.photos[currentIndex]
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(photo.senderName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(photo.timeAgo)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.8), Color.clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                }
                .transition(.opacity)
            }
            
            // Loading overlay
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .task {
            await viewModel.loadPhotos()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
    }
}
```

### Individual Photo View

**Create: `implementation/ios/Dayly/Features/Photos/Views/PhotoView.swift`**
```swift
struct PhotoView: View {
    let photo: PhotoViewModel
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity)
            } else if loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Failed to load photo")
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            await loadPhoto()
        }
    }
    
    private func loadPhoto() async {
        isLoading = true
        loadError = false
        
        do {
            // Try cache first
            if let cachedImage = await PhotoCacheManager.shared.getCachedPhoto(for: photo.id) {
                self.image = cachedImage
            } else {
                // Download from URL
                let imageData = try await NetworkService.shared.downloadData(from: photo.url)
                if let downloadedImage = UIImage(data: imageData) {
                    self.image = downloadedImage
                    // Cache for future use
                    await PhotoCacheManager.shared.cachePhoto(downloadedImage, for: photo.id)
                }
            }
        } catch {
            loadError = true
        }
        
        isLoading = false
    }
}
```

### Photo View Model

**Create: `implementation/ios/Dayly/Features/Photos/ViewModels/PhotoViewerViewModel.swift`**
```swift
@MainActor
class PhotoViewerViewModel: ObservableObject {
    @Published var photos: [PhotoViewModel] = []
    @Published var isLoading = false
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
    
    func loadPhotos() async {
        isLoading = true
        
        do {
            // Load from cache first for instant display
            let cachedPhotos = try await photoRepository.fetchPhotos(for: groupId)
            if !cachedPhotos.isEmpty {
                self.photos = cachedPhotos.map { PhotoViewModel(from: $0) }
            }
            
            // Then fetch latest from network
            let response = try await networkService.getTodaysPhotos(groupId: groupId)
            
            // Update cache and UI
            var updatedPhotos: [PhotoViewModel] = []
            for photoData in response {
                // Save to cache
                await photoRepository.cachePhoto(
                    id: photoData.id,
                    url: photoData.url,
                    metadata: photoData
                )
                
                updatedPhotos.append(PhotoViewModel(
                    id: UUID(uuidString: photoData.id) ?? UUID(),
                    url: URL(string: photoData.url)!,
                    senderName: photoData.senderName,
                    timestamp: ISO8601DateFormatter().date(from: photoData.timestamp) ?? Date()
                ))
            }
            
            self.photos = updatedPhotos.sorted { $0.timestamp > $1.timestamp }
            
        } catch {
            self.error = error
            // Still show cached photos on error
        }
        
        isLoading = false
    }
}

struct PhotoViewModel: Identifiable {
    let id: UUID
    let url: URL
    let senderName: String
    let timestamp: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
```

### Enhanced Photo Cache Manager

**Update: `implementation/ios/Dayly/Core/Storage/PhotoCacheManager.swift`**
```swift
actor PhotoCacheManager {
    static let shared = PhotoCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("photos")
    }
    
    init() {
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        
        // Start cleanup timer
        startCleanupTimer()
    }
    
    func cachePhoto(_ image: UIImage, for photoId: UUID) async throws {
        let key = photoId.uuidString as NSString
        
        // Memory cache
        memoryCache.setObject(image, forKey: key)
        
        // Disk cache
        if let data = image.jpegData(compressionQuality: 0.8) {
            let fileURL = cacheDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
            try data.write(to: fileURL)
        }
    }
    
    func getCachedPhoto(for photoId: UUID) async -> UIImage? {
        let key = photoId.uuidString as NSString
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: key) {
            return cachedImage
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Add back to memory cache
            memoryCache.setObject(image, forKey: key)
            return image
        }
        
        return nil
    }
    
    func clearExpiredPhotos() async {
        let cutoffDate = Date().addingTimeInterval(-48 * 60 * 60) // 48 hours ago
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attributes.creationDate,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Error cleaning cache: \(error)")
        }
    }
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.clearExpiredPhotos()
            }
        }
    }
}
```

### Empty State View

**Create: `implementation/ios/Dayly/Features/Photos/Views/EmptyPhotosView.swift`**
```swift
struct EmptyPhotosView: View {
    let groupName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No photos yet")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Be the first to share a moment with \(groupName) today")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
```

### Update Groups List View

Update `GroupsListView.swift` to handle long press:
```swift
GroupCard(group: group)
    .onTapGesture {
        selectedGroup = group
        showCamera = true
    }
    .onLongPressGesture {
        selectedGroupForViewing = group
        showPhotoViewer = true
    }
    .fullScreenCover(item: $selectedGroupForViewing) { group in
        PhotoViewerView(groupId: group.id, groupName: group.name)
    }
```

### Progressive Image Loading

**Create: `implementation/ios/Dayly/Core/Utils/ProgressiveImageLoader.swift`**
```swift
class ProgressiveImageLoader {
    static func loadImage(from url: URL, progress: @escaping (Double) -> Void) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageLoadError.invalidResponse
        }
        
        let expectedLength = response.expectedContentLength
        var data = Data()
        var bytesReceived: Int64 = 0
        
        for try await byte in asyncBytes {
            data.append(byte)
            bytesReceived += 1
            
            if expectedLength > 0 {
                let currentProgress = Double(bytesReceived) / Double(expectedLength)
                await MainActor.run {
                    progress(currentProgress)
                }
            }
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageLoadError.invalidImageData
        }
        
        return image
    }
}
```

### Gesture Handling

**Create: `implementation/ios/Dayly/Core/Extensions/View+Gestures.swift`**
```swift
extension View {
    func onSwipeDown(threshold: CGFloat = 100, action: @escaping () -> Void) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > threshold {
                        action()
                    }
                }
        )
    }
}
```

## Testing

1. **Test Photo Loading:**
   - Photos load from cache instantly
   - Network photos update the view
   - Loading states show appropriately

2. **Test Navigation:**
   - Swipe between photos smoothly
   - Tap to show/hide overlay
   - Swipe down to dismiss

3. **Test Caching:**
   - Viewed photos load instantly on return
   - Cache clears after 48 hours
   - Memory pressure handled gracefully

4. **Test Empty States:**
   - No photos shows appropriate message
   - Loading errors handled gracefully

## Success Criteria
- [ ] Long press group opens photo viewer
- [ ] Photos load with progress indication
- [ ] Can swipe between photos horizontally
- [ ] Tap toggles metadata overlay
- [ ] Shows sender name and time
- [ ] Swipe down dismisses viewer
- [ ] Photos cached for offline viewing
- [ ] 48-hour cleanup works automatically
- [ ] Empty state when no photos
- [ ] Smooth animations and transitions

## Next Phase Preview
Phase 7 will implement push notifications for new photos in groups.

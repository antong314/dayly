import SwiftUI

struct PhotoView: View {
    let photo: PhotoViewModel
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var loadProgress: Double = 0
    
    var body: some View {
        ZStack {
            Color.black
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: image)
            } else if loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Failed to load photo")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Button(action: {
                        Task {
                            await loadPhoto()
                        }
                    }) {
                        Text("Retry")
                            .font(.callout)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.2)))
                    }
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    if loadProgress > 0 && loadProgress < 1 {
                        VStack(spacing: 4) {
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(Int(loadProgress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            await loadPhoto()
        }
    }
    
    @MainActor
    private func loadPhoto() async {
        isLoading = true
        loadError = false
        loadProgress = 0
        
        do {
            // Try cache first
            if let cachedImage = await PhotoCacheManager.shared.getCachedPhoto(for: photo.id) {
                withAnimation {
                    self.image = cachedImage
                }
                isLoading = false
                return
            }
            
            // Download from URL with progress
            let imageData = try await downloadWithProgress(from: photo.url)
            
            if let downloadedImage = UIImage(data: imageData) {
                withAnimation {
                    self.image = downloadedImage
                }
                
                // Cache for future use
                Task {
                    try? await PhotoCacheManager.shared.cachePhoto(downloadedImage, for: photo.id)
                }
            } else {
                loadError = true
            }
        } catch {
            print("Failed to load photo: \(error)")
            loadError = true
        }
        
        isLoading = false
    }
    
    private func downloadWithProgress(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        // Add auth header if available
        if let token = NetworkService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let expectedLength = response.expectedContentLength
        var data = Data()
        var bytesReceived: Int64 = 0
        
        if expectedLength > 0 {
            data.reserveCapacity(Int(expectedLength))
        }
        
        for try await byte in asyncBytes {
            data.append(byte)
            bytesReceived += 1
            
            if expectedLength > 0 && bytesReceived % 1024 == 0 { // Update every 1KB
                let progress = Double(bytesReceived) / Double(expectedLength)
                await MainActor.run {
                    self.loadProgress = progress
                }
            }
        }
        
        return data
    }
}

struct PhotoView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoView(photo: PhotoViewModel(
            id: UUID(),
            url: URL(string: "https://example.com/photo.jpg")!,
            senderName: "John Doe",
            timestamp: Date()
        ))
        .background(Color.black)
    }
}

import Foundation
import SwiftUI

@MainActor
class PhotoViewerViewModel: ObservableObject {
    @Published var photos: [PhotoViewModel] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let groupId: UUID
    private let photoRepository: PhotoRepositoryProtocol
    private let networkService: NetworkServiceProtocol
    
    init(
        groupId: UUID,
        photoRepository: PhotoRepositoryProtocol? = nil,
        networkService: NetworkServiceProtocol = NetworkService.shared
    ) {
        self.groupId = groupId
        self.networkService = networkService
        self.photoRepository = photoRepository ?? PhotoRepository(
            networkService: networkService
        )
    }
    
    func loadPhotos() async {
        isLoading = true
        error = nil
        
        do {
            // Load from cache first for instant display
            let cachedPhotos = try await photoRepository.fetchPhotos(for: groupId)
            if !cachedPhotos.isEmpty {
                self.photos = cachedPhotos.map { PhotoViewModel(from: $0) }
                    .sorted { $0.timestamp > $1.timestamp }
            }
            
            // Then fetch latest from network
            let endpoint = "/api/photos/\(groupId.uuidString.lowercased())/today"
            let remotePhotos: [PhotoResponse] = try await networkService.request(
                endpoint: endpoint,
                method: .get,
                responseType: [PhotoResponse].self
            )
            
            // Update cache and UI
            var updatedPhotos: [PhotoViewModel] = []
            for photoData in remotePhotos {
                let photoId = UUID(uuidString: photoData.id) ?? UUID()
                
                // Create view model
                let photoVM = PhotoViewModel(
                    id: photoId,
                    url: URL(string: photoData.url)!,
                    senderName: photoData.sender_name,
                    timestamp: photoData.created_at,
                    expiresAt: photoData.expires_at
                )
                updatedPhotos.append(photoVM)
            }
            
            // Update UI with sorted photos
            self.photos = updatedPhotos.sorted { $0.timestamp > $1.timestamp }
            
        } catch NetworkError.unauthorized {
            // Handle auth error
            error = NetworkError.unauthorized
        } catch {
            self.error = error
            // Still show cached photos on error
            print("Error loading photos: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Photo View Model

struct PhotoViewModel: Identifiable {
    let id: UUID
    let url: URL
    let senderName: String
    let timestamp: Date
    let expiresAt: Date?
    
    init(id: UUID, url: URL, senderName: String, timestamp: Date, expiresAt: Date? = nil) {
        self.id = id
        self.url = url
        self.senderName = senderName
        self.timestamp = timestamp
        self.expiresAt = expiresAt
    }
    
    init(from photo: Photo) {
        self.id = photo.id
        self.senderName = photo.senderName
        self.timestamp = photo.createdAt
        self.expiresAt = photo.expiresAt
        
        // Use remote URL if available, otherwise construct from local path
        if let remoteUrl = photo.remoteUrl,
           let url = URL(string: remoteUrl) {
            self.url = url
        } else if let localPath = photo.localPath {
            self.url = URL(fileURLWithPath: localPath)
        } else {
            // Fallback URL - this should not happen in practice
            self.url = URL(string: "https://example.com")!
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.formattingContext = .standalone
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var expiresIn: String? {
        guard let expiresAt = expiresAt else { return nil }
        
        let timeInterval = expiresAt.timeIntervalSince(Date())
        guard timeInterval > 0 else { return nil }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

import Foundation
import CoreData
import UIKit

protocol PhotoRepositoryProtocol {
    func fetchPhotos(for groupId: UUID) async throws -> [Photo]
    func savePhoto(_ photo: Photo) async throws
    func deleteExpiredPhotos() async throws
    func syncPhotos(for groupId: UUID) async throws
    func deletePhoto(_ photoId: UUID) async throws
}

class PhotoRepository: PhotoRepositoryProtocol {
    private let coreDataStack: CoreDataStack
    private let networkService: NetworkServiceProtocol
    private let photoCacheManager: PhotoCacheManager
    
    init(
        coreDataStack: CoreDataStack = .shared,
        networkService: NetworkServiceProtocol = NetworkService.shared,
        photoCacheManager: PhotoCacheManager = .shared
    ) {
        self.coreDataStack = coreDataStack
        self.networkService = networkService
        self.photoCacheManager = photoCacheManager
    }
    
    // MARK: - Fetch Photos
    
    func fetchPhotos(for groupId: UUID) async throws -> [Photo] {
        // First, clean up expired photos
        try await deleteExpiredPhotos()
        
        // Fetch from local storage
        let localPhotos = try await fetchLocalPhotos(for: groupId)
        
        // If online, sync with backend
        if networkService.isConnected {
            do {
                try await syncPhotos(for: groupId)
                return try await fetchLocalPhotos(for: groupId)
            } catch {
                print("Failed to sync photos: \(error)")
                return localPhotos
            }
        }
        
        return localPhotos
    }
    
    private func fetchLocalPhotos(for groupId: UUID) async throws -> [Photo] {
        return try await coreDataStack.performBackgroundTask { context in
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "groupId == %@ AND expiresAt > %@", 
                                           groupId as CVarArg, 
                                           Date() as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            do {
                return try context.fetch(request)
            } catch {
                throw CoreDataError.fetchFailed(error as NSError)
            }
        }
    }
    
    // MARK: - Save Photo
    
    func savePhoto(_ photo: Photo) async throws {
        // Save to Core Data
        try coreDataStack.save(context: photo.managedObjectContext)
        
        // If we have image data, cache it locally
        if let remoteUrl = photo.remoteUrl,
           let url = URL(string: remoteUrl),
           networkService.isConnected {
            do {
                let imageData = try await downloadImageData(from: url)
                let localPath = try photoCacheManager.cachePhoto(imageData, for: photo.id)
                
                // Update photo with local path
                photo.localPath = localPath.path
                try coreDataStack.save(context: photo.managedObjectContext)
            } catch {
                print("Failed to cache photo: \(error)")
            }
        }
    }
    
    // MARK: - Delete Expired Photos
    
    func deleteExpiredPhotos() async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "expiresAt < %@", Date() as NSDate)
            
            do {
                let expiredPhotos = try context.fetch(request)
                
                // Delete cached images
                for photo in expiredPhotos {
                    if let localPath = photo.localPath {
                        try? self.photoCacheManager.deleteCachedPhoto(at: localPath)
                    }
                    context.delete(photo)
                }
                
                try context.save()
            } catch {
                throw CoreDataError.fetchFailed(error as NSError)
            }
        }
        
        // Also clean up orphaned cache files
        photoCacheManager.clearExpiredPhotos()
    }
    
    // MARK: - Sync Photos
    
    func syncPhotos(for groupId: UUID) async throws {
        // Call backend endpoint: GET /api/photos/{group_id}/today
        let endpoint = "/api/photos/\(groupId.uuidString.lowercased())/today"
        
        do {
            let response = try await networkService.request(
                endpoint: endpoint,
                method: .get,
                responseType: PhotosResponse.self
            )
            
            try await syncLocalPhotos(response.photos, for: groupId)
        } catch NetworkError.unauthorized {
            throw NetworkError.unauthorized
        } catch {
            print("Failed to fetch photos from server: \(error)")
            throw error
        }
    }
    
    private func syncLocalPhotos(_ remotePhotos: [PhotoDTO], for groupId: UUID) async throws {
        try await coreDataStack.performBackgroundTask { context in
            // Get existing photos for this group
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "groupId == %@", groupId as CVarArg)
            let existingPhotos = try context.fetch(request)
            let existingPhotoIds = Set(existingPhotos.map { $0.id.uuidString })
            
            // Add new photos from remote
            for remotePhoto in remotePhotos {
                if !existingPhotoIds.contains(remotePhoto.id) {
                    let photo = remotePhoto.toCoreDataPhoto(in: context)
                    
                    // Download and cache the photo
                    if let url = URL(string: remotePhoto.url) {
                        do {
                            let imageData = try await self.downloadImageData(from: url)
                            let localPath = try self.photoCacheManager.cachePhoto(imageData, for: photo.id)
                            photo.localPath = localPath.path
                        } catch {
                            print("Failed to cache photo \(remotePhoto.id): \(error)")
                        }
                    }
                }
            }
            
            try context.save()
        }
    }
    
    // MARK: - Delete Photo
    
    func deletePhoto(_ photoId: UUID) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", photoId as CVarArg)
            
            if let photo = try context.fetch(request).first {
                // Delete cached image
                if let localPath = photo.localPath {
                    try? self.photoCacheManager.deleteCachedPhoto(at: localPath)
                }
                
                context.delete(photo)
                try context.save()
            }
        }
    }
    
    func isPhotoCached(_ photoId: UUID) async -> Bool {
        return await coreDataStack.performBackgroundTask { context in
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", photoId as CVarArg)
            request.fetchLimit = 1
            
            do {
                let count = try context.count(for: request)
                return count > 0
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func downloadImageData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(0)
        }
        
        return data
    }
}

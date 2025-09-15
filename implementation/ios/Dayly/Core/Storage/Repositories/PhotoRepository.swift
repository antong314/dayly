import Foundation
import CoreData
import UIKit

protocol PhotoRepositoryProtocol {
    func fetchPhotos(for groupId: UUID) async throws -> [Photo]
    func savePhoto(_ photo: Photo) async throws
    func deleteExpiredPhotos() async throws
    func syncPhotos(for groupId: UUID) async throws
    func deletePhoto(_ photoId: UUID) async throws
    func isPhotoCached(_ photoId: UUID) async -> Bool
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
        guard let context = photo.managedObjectContext else {
            throw CoreDataError.saveFailed(NSError(domain: "PhotoRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo has no managed object context"]))
        }
        
        try coreDataStack.save(context: context)
        
        // If we have image data, cache it locally
        if let remoteUrl = photo.remoteUrl,
           let url = URL(string: remoteUrl),
           networkService.isConnected {
            do {
                let imageData = try await downloadImageData(from: url)
                if let localPath = await photoCacheManager.cachePhoto(imageData, for: photo.id) {
                    // Update photo with local path
                    photo.localPath = localPath.path
                }
                try coreDataStack.save(context: context)
            } catch {
                print("Failed to cache photo: \(error)")
            }
        }
    }
    
    // MARK: - Delete Expired Photos
    
    func deleteExpiredPhotos() async throws {
        // First get the photos to delete
        let photosToDelete = try await coreDataStack.performBackgroundTask { context in
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "expiresAt < %@", Date() as NSDate)
            
            do {
                let expiredPhotos = try context.fetch(request)
                
                // Collect paths to delete
                let pathsToDelete = expiredPhotos.compactMap { $0.localPath }
                
                // Delete from Core Data
                for photo in expiredPhotos {
                    context.delete(photo)
                }
                
                try context.save()
                
                return pathsToDelete
            } catch {
                throw CoreDataError.fetchFailed(error as NSError)
            }
        }
        
        // Delete cached images
        for path in photosToDelete {
            try? await photoCacheManager.deleteCachedPhoto(at: path)
        }
        
        // Also clean up orphaned cache files
        await photoCacheManager.clearExpiredPhotos()
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
        // First, determine which photos need to be added
        let photosToAdd = try await coreDataStack.performBackgroundTask { context in
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "groupId == %@", groupId as CVarArg)
            let existingPhotos = try context.fetch(request)
            let existingPhotoIds = Set(existingPhotos.map { $0.id.uuidString })
            
            // Filter remote photos that don't exist locally
            return remotePhotos.filter { !existingPhotoIds.contains($0.id) }
        }
        
        // Process each new photo
        for remotePhoto in photosToAdd {
            // Create photo in Core Data
            let photoId = try await coreDataStack.performBackgroundTask { context in
                let photo = remotePhoto.toCoreDataPhoto(in: context)
                try context.save()
                return photo.id
            }
            
            // Download and cache the photo
            if let url = URL(string: remotePhoto.url) {
                do {
                    let imageData = try await self.downloadImageData(from: url)
                    if let localPath = await self.photoCacheManager.cachePhoto(imageData, for: photoId) {
                        // Update photo with local path
                        try await coreDataStack.performBackgroundTask { context in
                            let request = Photo.fetchRequest()
                            request.predicate = NSPredicate(format: "id == %@", photoId as CVarArg)
                            if let photo = try context.fetch(request).first {
                                photo.localPath = localPath.path
                                try context.save()
                            }
                        }
                    }
                } catch {
                    print("Failed to cache photo \(remotePhoto.id): \(error)")
                }
            }
        }
    }
    
    // MARK: - Delete Photo
    
    func deletePhoto(_ photoId: UUID) async throws {
        // First get the photo's local path
        let localPath = try await coreDataStack.performBackgroundTask { context in
            let request = Photo.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", photoId as CVarArg)
            
            if let photo = try context.fetch(request).first {
                let path = photo.localPath
                context.delete(photo)
                try context.save()
                return path
            }
            return nil
        }
        
        // Delete cached image if exists
        if let path = localPath {
            try? await photoCacheManager.deleteCachedPhoto(at: path)
        }
    }
    
    func isPhotoCached(_ photoId: UUID) async -> Bool {
        do {
            return try await coreDataStack.performBackgroundTask { context in
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
        } catch {
            return false
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

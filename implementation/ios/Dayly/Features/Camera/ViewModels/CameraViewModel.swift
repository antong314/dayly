import Foundation
import UIKit
import CoreData

@MainActor
class CameraViewModel: ObservableObject {
    @Published var isCapturing = false
    @Published var error: Error?
    
    private let groupId: UUID
    private let photoRepository: PhotoRepositoryProtocol
    private let networkService: NetworkServiceProtocol
    private let coreDataStack: CoreDataStack
    
    init(
        groupId: UUID,
        photoRepository: PhotoRepositoryProtocol? = nil,
        networkService: NetworkServiceProtocol = NetworkService.shared,
        coreDataStack: CoreDataStack = .shared
    ) {
        self.groupId = groupId
        self.networkService = networkService
        self.coreDataStack = coreDataStack
        self.photoRepository = photoRepository ?? PhotoRepository(
            coreDataStack: coreDataStack,
            networkService: networkService
        )
    }
    
    func hasAlreadySentToday() async -> Bool {
        // Check daily_sends table via API
        do {
            let endpoint = "/api/groups/\(groupId.uuidString.lowercased())/daily-status"
            let response: DailyStatusResponse = try await networkService.request(
                endpoint: endpoint,
                method: .get,
                responseType: DailyStatusResponse.self
            )
            return response.hasSentToday
        } catch {
            // If offline, check local Core Data
            return checkLocalDailyStatus()
        }
    }
    
    private func checkLocalDailyStatus() -> Bool {
        let context = coreDataStack.viewContext
        let request = NSFetchRequest<Daily_sends>(entityName: "Daily_sends")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        request.predicate = NSPredicate(
            format: "user_id == %@ AND group_id == %@ AND sent_date >= %@",
            AuthManager.shared.currentUserId ?? "" as CVarArg,
            groupId as CVarArg,
            today as NSDate
        )
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Error checking local daily status: \(error)")
            return false
        }
    }
    
    func sendPhoto(_ image: UIImage) async {
        isCapturing = true
        error = nil
        
        do {
            // Process image
            guard let processedImage = await processImage(image) else {
                throw PhotoError.processingFailed
            }
            
            // Convert to JPEG
            guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
                throw PhotoError.processingFailed
            }
            
            // Create upload object
            let photoId = UUID()
            let upload = PhotoUpload(
                id: photoId,
                groupId: groupId,
                imageData: imageData,
                createdAt: Date()
            )
            
            // Queue for upload
            await PhotoUploadService.shared.queuePhoto(upload)
            
            // Create photo entity in Core Data
            let context = coreDataStack.newBackgroundContext()
            
            try await context.perform {
                let photo = Photo(context: context)
                photo.id = photoId
                photo.groupId = self.groupId
                photo.senderId = UUID(uuidString: AuthManager.shared.currentUserId ?? "") ?? UUID()
                photo.senderName = AuthManager.shared.currentUserName ?? "Unknown"
                photo.createdAt = Date()
                photo.expiresAt = Date().addingTimeInterval(48 * 60 * 60) // 48 hours
                
                // Save image data locally
                if let localPath = self.saveImageLocally(imageData, photoId: photo.id) {
                    photo.localPath = localPath
                }
                
                // Save to Core Data
                try context.save()
            }
            
            // Mark as sent today
            await markAsSentToday()
            
            // Trigger sync
            await SyncManager.shared.syncGroup(groupId)
            
        } catch {
            self.error = error
            print("Error sending photo: \(error)")
        }
        
        isCapturing = false
    }
    
    private func processImage(_ image: UIImage) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let processedImage = ImageProcessor.processForUpload(image)
                continuation.resume(returning: processedImage)
            }
        }
    }
    
    private func saveImageLocally(_ imageData: Data, photoId: UUID) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosPath = documentsPath.appendingPathComponent("photos")
        
        // Create photos directory if it doesn't exist
        try? FileManager.default.createDirectory(at: photosPath, withIntermediateDirectories: true)
        
        let fileName = "\(photoId.uuidString).jpg"
        let filePath = photosPath.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: filePath)
            return filePath.path
        } catch {
            print("Failed to save image locally: \(error)")
            return nil
        }
    }
    
    private func markAsSentToday() async {
        // Update backend
        do {
            let endpoint = "/api/groups/\(groupId.uuidString.lowercased())/mark-sent"
            let _: SuccessResponse = try await networkService.request(
                endpoint: endpoint,
                method: .post,
                responseType: SuccessResponse.self
            )
        } catch {
            print("Failed to mark as sent on backend: \(error)")
        }
        
        // Update local Core Data
        let context = coreDataStack.viewContext
        let dailySend = Daily_sends(context: context)
        dailySend.user_id = AuthManager.shared.currentUserId ?? ""
        dailySend.group_id = groupId.uuidString.lowercased()
        dailySend.sent_date = Date()
        
        try? coreDataStack.save(context: context)
    }
}

// MARK: - Photo Errors

enum PhotoError: LocalizedError {
    case processingFailed
    case uploadFailed
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .processingFailed:
            return "Failed to process the photo"
        case .uploadFailed:
            return "Failed to upload the photo"
        case .quotaExceeded:
            return "Daily photo limit reached"
        }
    }
}

// MARK: - Response Models

struct DailyStatusResponse: Decodable {
    let hasSentToday: Bool
    
    enum CodingKeys: String, CodingKey {
        case hasSentToday = "has_sent_today"
    }
}

private struct SuccessResponse: Decodable {
    let success: Bool
}


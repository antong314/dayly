import UIKit
import Foundation

// MARK: - Notification Names

extension Notification.Name {
    static let photoUploadProgress = Notification.Name("photoUploadProgress")
    static let photoUploadCompleted = Notification.Name("photoUploadCompleted")
    static let photoUploadFailed = Notification.Name("photoUploadFailed")
}

// MARK: - Background Upload Manager

class BackgroundUploadManager: NSObject {
    static let shared = BackgroundUploadManager()
    
    private let sessionIdentifier = "com.dayly.photo-upload-background"
    private var backgroundCompletionHandler: (() -> Void)?
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var uploadTasks: [Int: PhotoUpload] = [:]
    private let networkService: NetworkServiceProtocol
    
    override init() {
        self.networkService = NetworkService.shared
        super.init()
    }
    
    // MARK: - Public Methods
    
    func uploadPhoto(_ photo: PhotoUpload) async throws {
        // First get upload URL from backend
        let uploadInfo = try await getUploadInfo(for: photo.groupId)
        
        // Save photo to temporary file
        let tempURL = savePhotoToTemp(photo.imageData, photoId: photo.id)
        
        // Create upload request
        var request = URLRequest(url: URL(string: uploadInfo.uploadURL)!)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        // Add auth header
        if let token = NetworkService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create background upload task
        let task = urlSession.uploadTask(with: request, fromFile: tempURL)
        uploadTasks[task.taskIdentifier] = photo
        
        task.resume()
    }
    
    func handleBackgroundSession(identifier: String, completionHandler: @escaping () -> Void) {
        if identifier == sessionIdentifier {
            backgroundCompletionHandler = completionHandler
        }
    }
    
    // MARK: - Private Methods
    
    private func getUploadInfo(for groupId: UUID) async throws -> UploadInfo {
        let endpoint = "/api/photos/upload-url"
        let body = try JSONEncoder().encode(["group_id": groupId.uuidString])
        
        return try await networkService.request(
            endpoint: endpoint,
            method: .post,
            body: body,
            responseType: UploadInfo.self
        )
    }
    
    private func savePhotoToTemp(_ data: Data, photoId: UUID) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(photoId.uuidString).jpg"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    private func confirmUpload(_ photo: PhotoUpload) async {
        do {
            let endpoint = "/api/photos/confirm-upload"
            let body = try JSONEncoder().encode([
                "photo_id": photo.id.uuidString,
                "group_id": photo.groupId.uuidString
            ])
            
            let _: SuccessResponse = try await networkService.request(
                endpoint: endpoint,
                method: .post,
                body: body,
                responseType: SuccessResponse.self
            )
            
            // Notify success
            NotificationCenter.default.post(
                name: .photoUploadCompleted,
                object: nil,
                userInfo: ["photoId": photo.id]
            )
            
        } catch {
            print("Failed to confirm upload: \(error)")
        }
    }
    
    private func retryUpload(_ photo: PhotoUpload, error: Error) {
        // Add to retry queue in PhotoUploadService
        Task {
            await PhotoUploadService.shared.queuePhoto(photo)
        }
    }
}

// MARK: - URLSession Delegate

extension BackgroundUploadManager: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }
}

extension BackgroundUploadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            uploadTasks.removeValue(forKey: task.taskIdentifier)
        }
        
        guard let photo = uploadTasks[task.taskIdentifier] else { return }
        
        if let error = error {
            // Handle retry logic
            NotificationCenter.default.post(
                name: .photoUploadFailed,
                object: nil,
                userInfo: [
                    "photoId": photo.id,
                    "error": error
                ]
            )
            
            retryUpload(photo, error: error)
        } else if let httpResponse = task.response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 {
            // Confirm upload with backend
            Task {
                await confirmUpload(photo)
            }
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard let photo = uploadTasks[task.taskIdentifier] else { return }
        
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        
        // Notify progress
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .photoUploadProgress,
                object: nil,
                userInfo: [
                    "photoId": photo.id,
                    "progress": progress
                ]
            )
        }
    }
}

// MARK: - Response Models

private struct UploadInfo: Decodable {
    let uploadURL: String
    let photoId: String
    
    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case photoId = "photo_id"
    }
}

private struct SuccessResponse: Decodable {
    let success: Bool
}

// MARK: - Singleton Access

extension PhotoUploadService {
    static let shared = PhotoUploadService()
}

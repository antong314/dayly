import Foundation
import UIKit
import Combine

// MARK: - Protocols and Models

protocol PhotoUploadServiceProtocol {
    func queuePhoto(_ photo: PhotoUpload) async
    func retryFailedUploads() async
    func cancelUpload(_ photoId: UUID)
    var uploadProgress: AnyPublisher<UploadProgress, Never> { get }
}

struct PhotoUpload {
    let id: UUID
    let groupId: UUID
    let imageData: Data
    var retryCount: Int = 0
    let createdAt: Date
}

struct UploadProgress {
    let photoId: UUID
    let progress: Double // 0.0 to 1.0
    let status: UploadStatus
}

enum UploadStatus: Equatable {
    case queued
    case uploading(progress: Double)
    case completed
    case failed(Error)
    
    static func == (lhs: UploadStatus, rhs: UploadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.queued, .queued), (.completed, .completed):
            return true
        case let (.uploading(p1), .uploading(p2)):
            return p1 == p2
        case let (.failed(e1), .failed(e2)):
            return (e1 as NSError) == (e2 as NSError)
        default:
            return false
        }
    }
}

// MARK: - Upload Operation

class PhotoUploadOperation: Operation {
    let photo: PhotoUpload
    let networkService: NetworkServiceProtocol
    let onProgress: (UploadProgress) -> Void
    
    private var uploadTask: URLSessionUploadTask?
    
    init(
        photo: PhotoUpload,
        networkService: NetworkServiceProtocol,
        onProgress: @escaping (UploadProgress) -> Void
    ) {
        self.photo = photo
        self.networkService = networkService
        self.onProgress = onProgress
        super.init()
    }
    
    override var isAsynchronous: Bool { true }
    
    private var _isExecuting = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _isFinished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isExecuting: Bool { _isExecuting }
    override var isFinished: Bool { _isFinished }
    
    override func start() {
        guard !isCancelled else {
            finish()
            return
        }
        
        _isExecuting = true
        
        Task {
            await uploadPhoto()
        }
    }
    
    override func cancel() {
        uploadTask?.cancel()
        super.cancel()
        finish()
    }
    
    private func uploadPhoto() async {
        do {
            // Notify starting
            onProgress(UploadProgress(
                photoId: photo.id,
                progress: 0.0,
                status: .uploading(progress: 0.0)
            ))
            
            // Create multipart form data
            let boundary = UUID().uuidString
            var body = Data()
            
            // Add image data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(photo.imageData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add group_id
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"group_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(photo.groupId.uuidString.lowercased())\r\n".data(using: .utf8)!)
            
            // Close boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // Upload with progress tracking
            let response: PhotoUploadResponse = try await networkService.request(
                endpoint: "/api/photos/upload",
                method: .post,
                body: body,
                responseType: PhotoUploadResponse.self
            )
            
            // Notify completion
            onProgress(UploadProgress(
                photoId: photo.id,
                progress: 1.0,
                status: .completed
            ))
            
        } catch {
            // Notify failure
            onProgress(UploadProgress(
                photoId: photo.id,
                progress: 0.0,
                status: .failed(error)
            ))
        }
        
        finish()
    }
    
    private func finish() {
        _isExecuting = false
        _isFinished = true
    }
}

// MARK: - Upload Service

@MainActor
class PhotoUploadService: PhotoUploadServiceProtocol, ObservableObject {
    private let progressSubject = PassthroughSubject<UploadProgress, Never>()
    
    var uploadProgress: AnyPublisher<UploadProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    private let uploadQueue = OperationQueue()
    private let networkService: NetworkServiceProtocol
    private let photoRepository: PhotoRepositoryProtocol
    private let maxRetries = 3
    
    // Track failed uploads for retry
    private var failedUploads: [PhotoUpload] = []
    
    init(
        networkService: NetworkServiceProtocol = NetworkService.shared,
        photoRepository: PhotoRepositoryProtocol? = nil
    ) {
        self.networkService = networkService
        self.photoRepository = photoRepository ?? PhotoRepository()
        
        uploadQueue.maxConcurrentOperationCount = 1
        uploadQueue.qualityOfService = .userInitiated
        uploadQueue.name = "com.dayly.photo-upload"
    }
    
    func queuePhoto(_ photo: PhotoUpload) async {
        // Check if already uploading
        let existingOps = uploadQueue.operations.compactMap { $0 as? PhotoUploadOperation }
        guard !existingOps.contains(where: { $0.photo.id == photo.id }) else {
            return
        }
        
        // Add to upload queue
        let operation = PhotoUploadOperation(
            photo: photo,
            networkService: networkService,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    self?.handleProgress(progress)
                }
            }
        )
        
        uploadQueue.addOperation(operation)
    }
    
    func retryFailedUploads() async {
        let uploadsToRetry = failedUploads
        failedUploads.removeAll()
        
        for var upload in uploadsToRetry {
            upload.retryCount += 1
            
            if upload.retryCount <= maxRetries {
                // Add exponential backoff delay
                let delay = pow(2.0, Double(upload.retryCount - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                await queuePhoto(upload)
            }
        }
    }
    
    func cancelUpload(_ photoId: UUID) {
        let operations = uploadQueue.operations.compactMap { $0 as? PhotoUploadOperation }
        if let operation = operations.first(where: { $0.photo.id == photoId }) {
            operation.cancel()
        }
    }
    
    private func handleProgress(_ progress: UploadProgress) {
        progressSubject.send(progress)
        
        // Track failed uploads for retry
        if case .failed(_) = progress.status {
            if let operation = uploadQueue.operations
                .compactMap({ $0 as? PhotoUploadOperation })
                .first(where: { $0.photo.id == progress.photoId }) {
                failedUploads.append(operation.photo)
            }
        }
    }
}

// MARK: - Response Model

struct PhotoUploadResponse: Decodable {
    let photoId: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case expiresAt = "expires_at"
    }
}

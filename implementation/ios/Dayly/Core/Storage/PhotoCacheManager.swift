import Foundation
import UIKit

actor PhotoCacheManager {
    static let shared = PhotoCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var cleanupTimer: Timer?
    
    private init() {
        // Set up cache directory
        let documentsPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("photo_cache")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 50 // Max 50 images in memory
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        
        // Start cleanup timer
        Task {
            await startCleanupTimer()
        }
        
        // Listen for memory warnings
        Task {
            await setupMemoryWarningObserver()
        }
    }
    
    // MARK: - Cache Operations
    
    func cachePhoto(_ image: UIImage, for photoId: UUID) async throws {
        let key = photoId.uuidString as NSString
        
        // Memory cache
        await MainActor.run {
            memoryCache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        }
        
        // Disk cache
        if let data = image.jpegData(compressionQuality: 0.8) {
            let fileURL = cacheDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
            try data.write(to: fileURL)
        }
    }
    
    func cachePhoto(_ data: Data, for photoId: UUID) -> URL? {
        let fileName = "\(photoId.uuidString).jpg"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            // Save to disk
            try data.write(to: fileURL)
            
            // Also cache in memory if we can create an image
            if let image = UIImage(data: data) {
                Task { @MainActor in
                    memoryCache.setObject(image, forKey: photoId.uuidString as NSString, cost: data.count)
                }
            }
            
            return fileURL
        } catch {
            print("Failed to cache photo: \(error)")
            return nil
        }
    }
    
    func getCachedPhoto(for photoId: UUID) async -> UIImage? {
        let key = photoId.uuidString as NSString
        
        // Check memory cache first
        if let cachedImage = await MainActor.run(body: { memoryCache.object(forKey: key) }) {
            return cachedImage
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Add back to memory cache
            await MainActor.run {
                memoryCache.setObject(image, forKey: key, cost: data.count)
            }
            return image
        }
        
        return nil
    }
    
    func deleteCachedPhoto(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        let photoId = url.deletingPathExtension().lastPathComponent
        
        // Remove from memory cache
        Task { @MainActor in
            memoryCache.removeObject(forKey: photoId as NSString)
        }
        
        // Remove from disk
        try fileManager.removeItem(at: url)
    }
    
    // MARK: - Cleanup
    
    func clearExpiredPhotos() async {
        let cutoffDate = Date().addingTimeInterval(-48 * 60 * 60) // 48 hours ago
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            )
            
            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attributes.creationDate,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: file)
                    
                    // Remove from memory cache
                    let photoId = file.deletingPathExtension().lastPathComponent
                    await MainActor.run {
                        memoryCache.removeObject(forKey: photoId as NSString)
                    }
                }
            }
        } catch {
            print("Error cleaning cache: \(error)")
        }
    }
    
    func clearAllCache() async {
        // Clear memory cache
        await MainActor.run {
            memoryCache.removeAllObjects()
        }
        
        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func cleanupExpiredPhotos() {
        Task {
            await clearExpiredPhotos()
        }
    }
    
    private func startCleanupTimer() async {
        // Run cleanup every hour
        await MainActor.run {
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
                Task {
                    await self.clearExpiredPhotos()
                }
            }
        }
    }
    
    private func setupMemoryWarningObserver() async {
        await MainActor.run {
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                self.memoryCache.removeAllObjects()
            }
        }
    }
    
    // MARK: - Cache Info
    
    var cacheSize: Int64 {
        get async {
            do {
                let files = try fileManager.contentsOfDirectory(
                    at: cacheDirectory,
                    includingPropertiesForKeys: [.fileSizeKey]
                )
                
                return files.reduce(0) { total, file in
                    let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    return total + Int64(size)
                }
            } catch {
                return 0
            }
        }
    }
    
    func formattedCacheSize() async -> String {
        let size = await cacheSize
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
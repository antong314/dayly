import Foundation
import UIKit

enum ImageLoadError: LocalizedError {
    case invalidResponse
    case invalidImageData
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .invalidImageData:
            return "Could not create image from data"
        case .downloadFailed:
            return "Failed to download image"
        }
    }
}

class ProgressiveImageLoader {
    static func loadImage(
        from url: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        // Add auth header if available
        if let token = NetworkService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageLoadError.invalidResponse
        }
        
        let expectedLength = response.expectedContentLength
        var data = Data()
        var bytesReceived: Int64 = 0
        
        // Reserve capacity if we know the size
        if expectedLength > 0 {
            data.reserveCapacity(Int(expectedLength))
        }
        
        // Track progress as we receive bytes
        for try await byte in asyncBytes {
            data.append(byte)
            bytesReceived += 1
            
            // Update progress every 1KB or at completion
            if expectedLength > 0 && (bytesReceived % 1024 == 0 || bytesReceived == expectedLength) {
                let currentProgress = Double(bytesReceived) / Double(expectedLength)
                await MainActor.run {
                    progress(currentProgress)
                }
            }
        }
        
        // Create image from data
        guard let image = UIImage(data: data) else {
            throw ImageLoadError.invalidImageData
        }
        
        return image
    }
    
    // Convenience method without progress tracking
    static func loadImage(from url: URL) async throws -> UIImage {
        return try await loadImage(from: url) { _ in }
    }
    
    // Load with automatic retry
    static func loadImageWithRetry(
        from url: URL,
        maxAttempts: Int = 3,
        progress: @escaping (Double) -> Void = { _ in }
    ) async throws -> UIImage {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await loadImage(from: url, progress: progress)
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if error is ImageLoadError {
                    throw error
                }
                
                // Wait before retry (exponential backoff)
                if attempt < maxAttempts - 1 {
                    let delay = Double(attempt + 1) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? ImageLoadError.downloadFailed
    }
}

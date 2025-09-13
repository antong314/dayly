import Foundation

// MARK: - Upload Errors

enum UploadError: LocalizedError {
    case maxRetriesExceeded
    case networkUnavailable
    case invalidResponse
    case serverError(Int)
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Failed to upload after multiple attempts"
        case .networkUnavailable:
            return "No internet connection"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .quotaExceeded:
            return "Daily photo limit reached"
        }
    }
}

// MARK: - Retry Manager

class RetryManager {
    
    // MARK: - Retry Configuration
    
    struct RetryConfiguration {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        
        static let `default` = RetryConfiguration(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 60.0,
            multiplier: 2.0
        )
        
        static let aggressive = RetryConfiguration(
            maxAttempts: 5,
            initialDelay: 0.5,
            maxDelay: 30.0,
            multiplier: 1.5
        )
    }
    
    // MARK: - Retry Methods
    
    static func retryWithExponentialBackoff<T>(
        config: RetryConfiguration = .default,
        shouldRetry: ((Error) -> Bool)? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<config.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry this error
                if let shouldRetry = shouldRetry, !shouldRetry(error) {
                    throw error
                }
                
                // Don't retry if it's the last attempt
                if attempt < config.maxAttempts - 1 {
                    let delay = calculateDelay(
                        attempt: attempt,
                        config: config
                    )
                    
                    print("Retry attempt \(attempt + 1) after \(delay)s delay")
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? UploadError.maxRetriesExceeded
    }
    
    static func retryWithFixedDelay<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? UploadError.maxRetriesExceeded
    }
    
    // MARK: - Helper Methods
    
    private static func calculateDelay(
        attempt: Int,
        config: RetryConfiguration
    ) -> TimeInterval {
        let exponentialDelay = config.initialDelay * pow(config.multiplier, Double(attempt))
        return min(exponentialDelay, config.maxDelay)
    }
    
    static func shouldRetryError(_ error: Error) -> Bool {
        // Check if error is retryable
        if let uploadError = error as? UploadError {
            switch uploadError {
            case .maxRetriesExceeded, .quotaExceeded:
                return false
            case .networkUnavailable, .serverError(_), .invalidResponse:
                return true
            }
        }
        
        // Check NSError codes
        let nsError = error as NSError
        
        // Network errors that should be retried
        let retryableCodes = [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorDNSLookupFailed
        ]
        
        if retryableCodes.contains(nsError.code) {
            return true
        }
        
        // HTTP status codes that should be retried
        if let httpResponse = nsError.userInfo["HTTPResponse"] as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 408, 429, 500...599:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - Retry-aware Network Extension

extension NetworkServiceProtocol {
    func requestWithRetry<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data? = nil,
        responseType: T.Type,
        retryConfig: RetryManager.RetryConfiguration = .default
    ) async throws -> T {
        return try await RetryManager.retryWithExponentialBackoff(
            config: retryConfig,
            shouldRetry: RetryManager.shouldRetryError
        ) {
            try await self.request(
                endpoint: endpoint,
                method: method,
                body: body,
                responseType: responseType
            )
        }
    }
}

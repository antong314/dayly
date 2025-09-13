import Foundation
import Combine

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case unauthorized
    case serverError(Int)
    case networkError(Error)
    case noConnection
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noConnection:
            return "No internet connection"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    var isConnected: Bool { get }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        responseType: T.Type
    ) async throws -> T
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        responseType: T.Type
    ) async throws -> T
}

// MARK: - Network Service Implementation
class NetworkService: NetworkServiceProtocol {
    private let baseURL: String
    private let session: URLSession
    private(set) var authToken: String?
    
    var isConnected: Bool {
        // Simple implementation - in production, use NWPathMonitor
        return true
    }
    
    init(baseURL: String = "http://localhost:8000") {
        self.baseURL = baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: configuration)
    }
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if provided
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.noData
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                // Success
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw NetworkError.decodingError
                }
                
            case 401:
                throw NetworkError.unauthorized
                
            default:
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        responseType: T.Type
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: method,
            body: nil,
            responseType: responseType
        )
    }
    
    func downloadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        // Add auth header if available
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        return data
    }
}

// MARK: - Singleton
extension NetworkService {
    static let shared = NetworkService()
}

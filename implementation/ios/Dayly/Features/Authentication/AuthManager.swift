import Foundation
import SwiftUI

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @AppStorage("authToken") private var authToken: String?
    @AppStorage("user_id") private var userId: String?
    @AppStorage("user_name") private var userName: String?
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    
    private let networkService = NetworkService.shared
    
    var currentUserId: String? {
        userId
    }
    
    var currentUserName: String? {
        userName
    }
    
    private init() {}
    
    // MARK: - Phone Verification
    
    func sendVerificationCode(phoneNumber: String) async throws -> VerificationResponse {
        struct Request: Encodable {
            let phone_number: String
        }
        
        let request = Request(phone_number: "+1\(phoneNumber)")
        let bodyData = try JSONEncoder().encode(request)
        
        let response: VerificationResponse = try await networkService.request(
            endpoint: "/api/auth/verify",
            method: .post,
            body: bodyData,
            responseType: VerificationResponse.self
        )
        
        return response
    }
    
    // MARK: - Code Verification
    
    func verifyCode(phoneNumber: String, code: String, firstName: String?) async throws -> AuthResponse {
        struct Request: Encodable {
            let phone_number: String
            let code: String
            let first_name: String?
        }
        
        let request = Request(
            phone_number: "+1\(phoneNumber)",
            code: code,
            first_name: firstName
        )
        let bodyData = try JSONEncoder().encode(request)
        
        let response: AuthResponse = try await networkService.request(
            endpoint: "/api/auth/verify/confirm",
            method: .post,
            body: bodyData,
            responseType: AuthResponse.self
        )
        
        // Store auth data
        setAuthToken(response.access_token)
        userId = response.user.id
        userName = response.user.first_name
        isAuthenticated = true
        
        return response
    }
    
    // MARK: - Token Management
    
    func setAuthToken(_ token: String) {
        authToken = token
        networkService.setAuthToken(token)
    }
    
    func clearAuth() {
        authToken = nil
        userId = nil
        userName = nil
        isAuthenticated = false
        networkService.setAuthToken(nil)
    }
    
    // MARK: - Current User
    
    func refreshCurrentUser() async throws {
        guard authToken != nil else { return }
        
        struct UserResponse: Decodable {
            let id: String
            let phone_number: String
            let first_name: String
        }
        
        let response: UserResponse = try await networkService.request(
            endpoint: "/api/auth/me",
            method: .get,
            responseType: UserResponse.self
        )
        
        userId = response.id
        userName = response.first_name
    }
}

// MARK: - Response Models

struct VerificationResponse: Decodable {
    let message: String
}

struct AuthResponse: Decodable {
    let access_token: String
    let token_type: String
    let user: UserInfo
    
    struct UserInfo: Decodable {
        let id: String
        let phone_number: String
        let first_name: String
    }
}

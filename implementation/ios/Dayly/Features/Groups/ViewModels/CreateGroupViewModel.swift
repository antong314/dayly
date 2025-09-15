import Foundation
import SwiftUI

@MainActor
class CreateGroupViewModel: ObservableObject {
    @Published var selectedContacts: [Contact] = []
    @Published var isCreating = false
    @Published var error: Error?
    
    private let networkService: NetworkServiceProtocol
    private let groupRepository: GroupRepositoryProtocol
    
    init(
        networkService: NetworkServiceProtocol = NetworkService.shared,
        groupRepository: GroupRepositoryProtocol? = nil
    ) {
        self.networkService = networkService
        self.groupRepository = groupRepository ?? GroupRepository(
            networkService: networkService
        )
    }
    
    func removeContact(_ contact: Contact) {
        selectedContacts.removeAll { $0.id == contact.id }
    }
    
    func createGroup(name: String) async -> Bool {
        // Validate input
        guard !name.isEmpty, name.count <= 50 else {
            error = GroupError.invalidName
            return false
        }
        
        guard !selectedContacts.isEmpty else {
            error = GroupError.noMembers
            return false
        }
        
        guard selectedContacts.count <= 11 else {
            error = GroupError.tooManyMembers
            return false
        }
        
        isCreating = true
        error = nil
        
        // Check if in dev mode
        let isDevMode = UserDefaults.standard.string(forKey: "authToken") == "dev-bypass-token"
        
        if isDevMode {
            // In dev mode, show an alert that group creation isn't available
            print("⚠️ Dev mode: Group creation not available")
            
            self.error = GroupError.networkError(
                NSError(domain: "Dayly", 
                        code: 403, 
                        userInfo: [NSLocalizedDescriptionKey: "Group creation is not available in developer mode. To test group features, you need to run the backend server with proper authentication."])
            )
            
            isCreating = false
            return false
        }
        
        do {
            // Prepare phone numbers
            let phoneNumbers = selectedContacts.map { $0.phoneNumber }
            
            // Create group via API
            let createData = GroupCreateRequest(
                name: name,
                memberPhoneNumbers: phoneNumbers
            )
            
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let body = try encoder.encode(createData)
            
            let response: GroupCreateResponse = try await networkService.request(
                endpoint: "/api/groups/",
                method: .post,
                body: body,
                responseType: GroupCreateResponse.self
            )
            
            // Sync to get the new group
            await SyncManager.shared.performSync()
            
            isCreating = false
            return true
            
        } catch {
            print("❌ Group creation failed: \(error)")
            
            // Provide more specific error messages
            if let networkError = error as? NetworkError {
                switch networkError {
                case .serverError(let statusCode):
                    if statusCode == 403 {
                        self.error = GroupError.networkError(NSError(domain: "Dayly", code: 403, userInfo: [NSLocalizedDescriptionKey: "Authentication failed. In dev mode, you can only view existing groups."]))
                    } else {
                        self.error = GroupError.networkError(error)
                    }
                case .unauthorized:
                    self.error = GroupError.networkError(NSError(domain: "Dayly", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please log in again."]))
                default:
                    self.error = GroupError.networkError(error)
                }
            } else {
                self.error = GroupError.networkError(error)
            }
            
            isCreating = false
            return false
        }
    }
    
    private func sendInvites(groupId: String) async {
        let phoneNumbers = selectedContacts.map { $0.phoneNumber }
        
        do {
            // Check which users already have the app
            let checkRequest = CheckUsersRequest(phone_numbers: phoneNumbers)
            let checkData = try JSONEncoder().encode(checkRequest)
            
            let checkResponse: CheckUsersResponse = try await networkService.request(
                endpoint: "/api/invites/check-users",
                method: .post,
                body: checkData,
                responseType: CheckUsersResponse.self
            )
            
            // Send invites
            let inviteRequest = SendInvitesRequest(
                group_id: groupId,
                phone_numbers: checkResponse.needs_invite,
                existing_users: checkResponse.existing.map { user in
                    ["user_id": user.user_id, "phone_number": user.phone_number]
                }
            )
            
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let inviteData = try encoder.encode(inviteRequest)
            
            let inviteResponse: SendInvitesResponse = try await networkService.request(
                endpoint: "/api/invites/send",
                method: .post,
                body: inviteData,
                responseType: SendInvitesResponse.self
            )
            
            print("✅ Added \(inviteResponse.added_members) members, sent \(inviteResponse.sent_invites.count) invites")
            
        } catch {
            print("❌ Failed to send invites: \(error)")
            // Don't fail the group creation if invites fail
        }
    }
}

// MARK: - Error Types

enum GroupError: LocalizedError {
    case invalidName
    case noMembers
    case tooManyMembers
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Group name must be between 1 and 50 characters"
        case .noMembers:
            return "Please add at least one member"
        case .tooManyMembers:
            return "Groups can have a maximum of 12 members"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Request/Response Models

struct GroupCreateRequest: Encodable {
    let name: String
    let memberPhoneNumbers: [String]
}

struct GroupCreateResponse: Decodable {
    let id: String
    let name: String
}

// Invite Models
struct CheckUsersRequest: Encodable {
    let phone_numbers: [String]
}

struct CheckUsersResponse: Decodable {
    struct ExistingUser: Decodable {
        let phone_number: String
        let user_id: String
        let first_name: String?
    }
    
    let existing: [ExistingUser]
    let needs_invite: [String]
}

struct SendInvitesRequest: Encodable {
    let group_id: String
    let phone_numbers: [String]
    let existing_users: [[String: String]]
}

struct SendInvitesResponse: Decodable {
    struct InviteInfo: Decodable {
        let phone_number: String
        let invite_code: String
    }
    
    let sent_invites: [InviteInfo]
    let added_members: Int
}

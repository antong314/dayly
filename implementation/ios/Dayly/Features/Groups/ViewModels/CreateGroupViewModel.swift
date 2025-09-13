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
                endpoint: "/api/groups",
                method: .post,
                body: body,
                responseType: GroupCreateResponse.self
            )
            
            // Sync to get the new group
            await SyncManager.shared.performSync()
            
            isCreating = false
            return true
            
        } catch {
            self.error = error
            isCreating = false
            return false
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

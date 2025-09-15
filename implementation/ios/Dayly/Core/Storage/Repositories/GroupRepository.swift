import Foundation
import CoreData
import Combine
import UIKit

protocol GroupRepositoryProtocol {
    func fetchGroups() async throws -> [Group]
    func createGroup(_ group: Group) async throws
    func updateGroup(_ group: Group) async throws
    func deleteGroup(_ groupId: UUID) async throws
    func syncGroups(from remote: [GroupDTO]) async throws
    func getGroup(by id: UUID) async throws -> Group?
}

class GroupRepository: GroupRepositoryProtocol {
    private let coreDataStack: CoreDataStack
    private let networkService: NetworkServiceProtocol
    
    init(
        coreDataStack: CoreDataStack = .shared,
        networkService: NetworkServiceProtocol
    ) {
        self.coreDataStack = coreDataStack
        self.networkService = networkService
    }
    
    // MARK: - Fetch Groups
    
    func fetchGroups() async throws -> [Group] {
        // First, fetch from Core Data
        let localGroups = try await fetchLocalGroups()
        
        // If we have network, sync with backend
        if networkService.isConnected {
            do {
                let remoteGroups = try await fetchRemoteGroups()
                try await syncGroups(from: remoteGroups)
                return try await fetchLocalGroups()
            } catch {
                // If sync fails, return local data
                print("Failed to sync groups: \(error)")
                return localGroups
            }
        }
        
        return localGroups
    }
    
    private func fetchLocalGroups() async throws -> [Group] {
        return try await coreDataStack.performBackgroundTask { context in
            let request = Group.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            
            do {
                return try context.fetch(request)
            } catch {
                throw CoreDataError.fetchFailed(error as NSError)
            }
        }
    }
    
    private func fetchRemoteGroups() async throws -> [GroupDTO] {
        // This calls the backend endpoint GET /api/groups
        return try await networkService.request(
            endpoint: "/api/groups",
            method: .get,
            responseType: GroupsResponse.self
        ).groups
    }
    
    // MARK: - Create Group
    
    func createGroup(_ group: Group) async throws {
        // Save locally first
        try coreDataStack.save(context: group.managedObjectContext)
        
        // Then sync with backend if online
        if networkService.isConnected {
            // Backend endpoint would be POST /api/groups
            // For now, we'll just save locally
        }
    }
    
    // MARK: - Update Group
    
    func updateGroup(_ group: Group) async throws {
        try coreDataStack.save(context: group.managedObjectContext)
        
        if networkService.isConnected {
            // Backend endpoint would be PUT /api/groups/{id}
        }
    }
    
    // MARK: - Delete Group
    
    func deleteGroup(_ groupId: UUID) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = Group.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", groupId as CVarArg)
            
            if let group = try context.fetch(request).first {
                context.delete(group)
                try context.save()
            }
        }
        
        if networkService.isConnected {
            // Backend endpoint would be DELETE /api/groups/{id}
        }
    }
    
    // MARK: - Sync Groups
    
    func syncGroups(from remote: [GroupDTO]) async throws {
        try await coreDataStack.performBackgroundTask { context in
            // Create a dictionary of existing groups by ID
            let existingGroups = try self.fetchExistingGroups(in: context)
            let existingGroupsDict = Dictionary(
                uniqueKeysWithValues: existingGroups.map { ($0.id.uuidString, $0) }
            )
            
            // Track which groups we've seen from the server
            var seenGroupIds = Set<String>()
            
            // Update or create groups from remote
            for remoteGroup in remote {
                seenGroupIds.insert(remoteGroup.id)
                
                if let existingGroup = existingGroupsDict[remoteGroup.id] {
                    // Update existing group
                    self.updateLocalGroup(existingGroup, from: remoteGroup, in: context)
                } else {
                    // Create new group
                    _ = remoteGroup.toCoreDataGroup(in: context)
                }
            }
            
            // Delete groups that no longer exist on server
            for (groupId, group) in existingGroupsDict {
                if !seenGroupIds.contains(groupId) {
                    context.delete(group)
                }
            }
            
            // Save all changes
            try context.save()
        }
    }
    
    // MARK: - Get Single Group
    
    func getGroup(by id: UUID) async throws -> Group? {
        return try await coreDataStack.performBackgroundTask { context in
            let request = Group.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            return try context.fetch(request).first
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchExistingGroups(in context: NSManagedObjectContext) throws -> [Group] {
        let request = Group.fetchRequest()
        return try context.fetch(request)
    }
    
    private func updateLocalGroup(_ group: Group, from dto: GroupDTO, in context: NSManagedObjectContext) {
        group.name = dto.name
        group.hasSentToday = dto.hasSentToday
        
        if let lastPhoto = dto.lastPhoto {
            group.lastPhotoDate = lastPhoto.timestamp
        }
        
        // Update members
        // First, remove all existing members
        if let existingMembers = group.members as? Set<GroupMember> {
            for member in existingMembers {
                context.delete(member)
            }
        }
        
        // Then add new members from DTO
        for memberDTO in dto.members {
            let member = GroupMember(context: context)
            member.userId = UUID(uuidString: memberDTO.id) ?? UUID()
            member.firstName = memberDTO.firstName ?? "Unknown"
            member.joinedAt = Date()
            member.group = group
        }
    }
}

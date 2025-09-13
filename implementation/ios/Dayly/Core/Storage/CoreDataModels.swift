import Foundation
import CoreData

// MARK: - Core Data Entity Definitions
// Note: These correspond to entities that should be defined in Dayly.xcdatamodeld

extension User {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var phoneNumber: String
    @NSManaged public var firstName: String?
}

extension Group {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Group> {
        return NSFetchRequest<Group>(entityName: "Group")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var lastPhotoDate: Date?
    @NSManaged public var hasSentToday: Bool
    @NSManaged public var members: NSSet?
}

// MARK: - Group Core Data Generated Accessors
extension Group {
    @objc(addMembersObject:)
    @NSManaged public func addToMembers(_ value: GroupMember)
    
    @objc(removeMembersObject:)
    @NSManaged public func removeFromMembers(_ value: GroupMember)
    
    @objc(addMembers:)
    @NSManaged public func addToMembers(_ values: NSSet)
    
    @objc(removeMembers:)
    @NSManaged public func removeFromMembers(_ values: NSSet)
}

extension GroupMember {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GroupMember> {
        return NSFetchRequest<GroupMember>(entityName: "GroupMember")
    }
    
    @NSManaged public var userId: UUID
    @NSManaged public var firstName: String
    @NSManaged public var joinedAt: Date
    @NSManaged public var group: Group?
}

extension Photo {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var groupId: UUID
    @NSManaged public var senderId: UUID
    @NSManaged public var senderName: String
    @NSManaged public var localPath: String?
    @NSManaged public var remoteUrl: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var expiresAt: Date
}

extension Daily_sends {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Daily_sends> {
        return NSFetchRequest<Daily_sends>(entityName: "Daily_sends")
    }
    
    @NSManaged public var user_id: String
    @NSManaged public var group_id: String
    @NSManaged public var sent_date: Date
}

// MARK: - Convenience Extensions

extension Group {
    var memberArray: [GroupMember] {
        let set = members as? Set<GroupMember> ?? []
        return set.sorted { $0.joinedAt < $1.joinedAt }
    }
    
    var isExpired: Bool {
        guard let lastPhotoDate = lastPhotoDate else { return false }
        return Date().timeIntervalSince(lastPhotoDate) > 48 * 60 * 60
    }
}

extension Photo {
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var isLocallyAvailable: Bool {
        return localPath != nil
    }
}

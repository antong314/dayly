import Foundation

// MARK: - Group DTOs

struct GroupDTO: Codable {
    let id: String
    let name: String
    let memberCount: Int
    let members: [MemberDTO]
    let lastPhoto: LastPhotoDTO?
    let hasSentToday: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, members
        case memberCount = "member_count"
        case lastPhoto = "last_photo"
        case hasSentToday = "has_sent_today"
    }
}

struct MemberDTO: Codable {
    let id: String
    let firstName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
    }
}

struct LastPhotoDTO: Codable {
    let timestamp: Date
    let senderId: String
    let senderName: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case senderId = "sender_id"
        case senderName = "sender_name"
    }
}

// MARK: - Photo DTOs

struct PhotoDTO: Codable {
    let id: String
    let groupId: String
    let senderId: String
    let senderName: String
    let url: String
    let createdAt: Date
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, url
        case groupId = "group_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

// MARK: - Response Wrappers

struct GroupsResponse: Codable {
    let groups: [GroupDTO]
}

struct PhotosResponse: Codable {
    let photos: [PhotoDTO]
}

// MARK: - Photo Response for sync

struct PhotoResponse: Codable {
    let id: String
    let sender_id: String
    let sender_name: String
    let url: String
    let created_at: Date
    let expires_at: Date
}

// MARK: - Conversion Extensions

extension GroupDTO {
    func toCoreDataGroup(in context: NSManagedObjectContext) -> Group {
        let group = Group(context: context)
        group.id = UUID(uuidString: id) ?? UUID()
        group.name = name
        group.hasSentToday = hasSentToday
        group.createdAt = Date()
        
        if let lastPhoto = lastPhoto {
            group.lastPhotoDate = lastPhoto.timestamp
        }
        
        // Convert members
        for memberDTO in members {
            let member = GroupMember(context: context)
            member.userId = UUID(uuidString: memberDTO.id) ?? UUID()
            member.firstName = memberDTO.firstName ?? "Unknown"
            member.joinedAt = Date()
            member.group = group
        }
        
        return group
    }
}

extension PhotoDTO {
    func toCoreDataPhoto(in context: NSManagedObjectContext) -> Photo {
        let photo = Photo(context: context)
        photo.id = UUID(uuidString: id) ?? UUID()
        photo.groupId = UUID(uuidString: groupId) ?? UUID()
        photo.senderId = UUID(uuidString: senderId) ?? UUID()
        photo.senderName = senderName
        photo.remoteUrl = url
        photo.createdAt = createdAt
        photo.expiresAt = expiresAt
        
        return photo
    }
}

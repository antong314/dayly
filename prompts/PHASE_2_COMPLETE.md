# Phase 2: Data Layer & Local Storage

## App Context
You are building "Dayly" - a minimalist photo-sharing app where users can share one photo per day with small groups of close friends/family. The app's philosophy is about meaningful, intentional sharing rather than endless content.

**Core Features:**
- One photo per day per group limit
- Small groups (max 12 people)
- Photos disappear after 48 hours
- No comments, likes, or social features
- Phone number authentication

## Technical Stack
- **iOS**: SwiftUI, minimum iOS 15.0
- **Backend**: Python 3.11+ with FastAPI
- **Database**: Supabase (PostgreSQL with auth, storage, realtime)
- **Storage**: Supabase Storage for photos
- **Deployment**: DigitalOcean App Platform

## Current Status
Phase 0 & 1 are complete with:
- iOS project with authentication views
- Backend with working auth endpoints
- Users can verify phone numbers and receive tokens
- Tokens stored securely in Keychain
- Supabase auth fully integrated

## Your Task: Phase 2 - Data Layer & Local Storage

Implement Core Data models and repository pattern for offline support and data caching.

### iOS Core Data Setup

**Create Core Data Model File:**
`implementation/ios/Dayly/Core/Storage/Dayly.xcdatamodeld`

Define these entities:

1. **User Entity**
   - id: UUID
   - phoneNumber: String
   - firstName: String (optional)

2. **Group Entity**
   - id: UUID
   - name: String
   - createdAt: Date
   - lastPhotoDate: Date (optional)
   - hasSentToday: Boolean
   - Relationship: members (to-many GroupMember)

3. **GroupMember Entity**
   - userId: UUID
   - firstName: String
   - joinedAt: Date
   - Relationship: group (to-one Group)

4. **Photo Entity**
   - id: UUID
   - groupId: UUID
   - senderId: UUID
   - senderName: String
   - localPath: String (optional)
   - remoteUrl: String (optional)
   - createdAt: Date
   - expiresAt: Date

### Core Data Stack

**Create: `implementation/ios/Dayly/Core/Storage/CoreDataStack.swift`**
```swift
import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Dayly")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func save() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }
}
```

### Repository Implementations

**Create: `implementation/ios/Dayly/Core/Storage/Repositories/GroupRepository.swift`**
```swift
protocol GroupRepositoryProtocol {
    func fetchGroups() async throws -> [Group]
    func createGroup(_ group: Group) async throws
    func updateGroup(_ group: Group) async throws
    func deleteGroup(_ groupId: UUID) async throws
    func syncGroups(from remote: [GroupDTO]) async throws
}

class GroupRepository: GroupRepositoryProtocol {
    private let coreDataStack = CoreDataStack.shared
    private let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    // Implement all protocol methods
    // Fetch from Core Data first, then sync with backend
    // Handle offline/online scenarios
}
```

**Create: `implementation/ios/Dayly/Core/Storage/Repositories/PhotoRepository.swift`**
```swift
protocol PhotoRepositoryProtocol {
    func fetchPhotos(for groupId: UUID) async throws -> [Photo]
    func savePhoto(_ photo: Photo) async throws
    func deleteExpiredPhotos() async throws
    func syncPhotos(for groupId: UUID) async throws
}

class PhotoRepository: PhotoRepositoryProtocol {
    private let coreDataStack = CoreDataStack.shared
    
    // Implement all methods
    // Auto-delete photos older than 48 hours
    // Cache photo data locally
}
```

### Data Transfer Objects (DTOs)

**Create: `implementation/ios/Dayly/Models/DTOs/GroupDTO.swift`**
```swift
struct GroupDTO: Codable {
    let id: String
    let name: String
    let memberCount: Int
    let members: [MemberDTO]
    let lastPhoto: LastPhotoDTO?
    let hasSentToday: Bool
}

struct MemberDTO: Codable {
    let id: String
    let firstName: String?
}

struct LastPhotoDTO: Codable {
    let timestamp: Date
    let senderId: String
}
```

### Sync Manager

**Create: `implementation/ios/Dayly/Core/Storage/SyncManager.swift`**
```swift
class SyncManager {
    private let groupRepository: GroupRepositoryProtocol
    private let photoRepository: PhotoRepositoryProtocol
    
    func performSync() async {
        // Sync groups from backend
        // Update local Core Data
        // Handle conflicts (last-write-wins)
        // Clean up expired photos
    }
    
    func syncOnAppLaunch() async {
        await performSync()
    }
    
    func syncOnForeground() async {
        await performSync()
    }
}
```

### Backend Updates

No new backend endpoints needed for this phase, but ensure these existing endpoints work:

1. GET /api/groups - Returns user's groups
2. GET /api/photos/{group_id}/today - Returns today's photos

### Photo Cache Manager

**Create: `implementation/ios/Dayly/Core/Storage/PhotoCacheManager.swift`**
```swift
class PhotoCacheManager {
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("photos")
    }
    
    func cachePhoto(_ data: Data, for photoId: UUID) throws -> URL {
        // Save photo data to cache directory
        // Return local file URL
    }
    
    func getCachedPhoto(for photoId: UUID) -> UIImage? {
        // Retrieve from cache if exists
    }
    
    func clearExpiredPhotos() {
        // Delete photos older than 48 hours
    }
}
```

### Migrations

**Create: `implementation/ios/Dayly/Core/Storage/MigrationManager.swift`**
```swift
class MigrationManager {
    static func performMigrationsIfNeeded() {
        // Handle Core Data model migrations
        // Version tracking in UserDefaults
    }
}
```

### Update App Delegate

Update `DaylyApp.swift` to initialize Core Data:
```swift
@main
struct DaylyApp: App {
    init() {
        // Initialize Core Data
        _ = CoreDataStack.shared
        MigrationManager.performMigrationsIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
        }
    }
}
```

## Testing

1. **Test Core Data Stack:**
   - Verify entities save correctly
   - Test fetch requests work
   - Confirm relationships are properly set

2. **Test Sync:**
   - Works offline (returns cached data)
   - Syncs when online
   - Handles conflicts properly

3. **Test Photo Cleanup:**
   - Photos older than 48 hours are deleted
   - Cache directory doesn't grow unbounded

## Success Criteria
- [ ] Core Data stack initializes without errors
- [ ] Can save and retrieve groups locally
- [ ] Can save and retrieve photos locally
- [ ] Sync manager updates local data from backend
- [ ] Expired photos are automatically cleaned up
- [ ] App works offline with cached data
- [ ] Repository pattern properly abstracts data access
- [ ] Photo cache manager handles local image storage

## Next Phase Preview
Phase 3 will implement the groups management UI and backend endpoints for creating, updating, and managing groups.

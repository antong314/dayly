import Foundation
import Combine
import UIKit

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let groupRepository: GroupRepositoryProtocol
    private let photoRepository: PhotoRepositoryProtocol
    private let userDefaults = UserDefaults.standard
    private let syncQueue = DispatchQueue(label: "com.dayly.sync", qos: .background)
    
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private let lastSyncDateKey = "lastSyncDate"
    
    init(
        groupRepository: GroupRepositoryProtocol? = nil,
        photoRepository: PhotoRepositoryProtocol? = nil
    ) {
        // Use injected repositories or create defaults
        self.groupRepository = groupRepository ?? GroupRepository(
            networkService: NetworkService.shared
        )
        self.photoRepository = photoRepository ?? PhotoRepository()
        
        // Load last sync date
        self.lastSyncDate = userDefaults.object(forKey: lastSyncDateKey) as? Date
        
        // Setup automatic sync triggers
        setupAutoSync()
    }
    
    // MARK: - Public Methods
    
    func performSync() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncError = nil
        }
        
        do {
            // Clean up expired data first
            try await photoRepository.deleteExpiredPhotos()
            
            // Sync groups
            let groups = try await groupRepository.fetchGroups()
            
            // Sync photos for each group
            for group in groups {
                do {
                    try await photoRepository.syncPhotos(for: group.id)
                } catch {
                    print("Failed to sync photos for group \(group.name): \(error)")
                    // Continue syncing other groups
                }
            }
            
            // Update last sync date
            let now = Date()
            await MainActor.run {
                self.lastSyncDate = now
                self.userDefaults.set(now, forKey: self.lastSyncDateKey)
            }
            
        } catch {
            await MainActor.run {
                self.syncError = error
            }
            print("Sync failed: \(error)")
        }
        
        await MainActor.run {
            self.isSyncing = false
        }
    }
    
    func syncOnAppLaunch() async {
        // Always sync on app launch
        await performSync()
    }
    
    func syncOnForeground() async {
        // Sync if it's been more than 5 minutes since last sync
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 300 { // 5 minutes
            return
        }
        
        await performSync()
    }
    
    func syncGroup(_ groupId: UUID) async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            self.isSyncing = true
        }
        
        do {
            // Sync photos for this specific group
            try await syncPhotos(for: groupId)
            
            // Update last sync date
            let now = Date()
            await MainActor.run {
                self.lastSyncDate = now
                self.userDefaults.set(now, forKey: self.lastSyncDateKey)
            }
        } catch {
            await MainActor.run {
                self.syncError = error
            }
        }
        
        await MainActor.run {
            self.isSyncing = false
        }
    }
    
    private func syncPhotos(for groupId: UUID) async throws {
        // Fetch today's photos from backend
        let endpoint = "/api/photos/\(groupId.uuidString.lowercased())/today"
        
        do {
            let remotePhotos: [PhotoResponse] = try await networkService.request(
                endpoint: endpoint,
                method: .get,
                responseType: [PhotoResponse].self
            )
            
            // Update local cache
            for remotePhoto in remotePhotos {
                // Check if already cached
                let photoId = UUID(uuidString: remotePhoto.id) ?? UUID()
                
                // Skip if we already have this photo locally
                if await photoRepository.isPhotoCached(photoId) {
                    continue
                }
                
                // Download and cache the photo
                if let url = URL(string: remotePhoto.url) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        
                        // Cache the photo
                        let context = coreDataStack.newBackgroundContext()
                        try await context.perform {
                            let photo = Photo(context: context)
                            photo.id = photoId
                            photo.groupId = groupId
                            photo.senderId = UUID(uuidString: remotePhoto.sender_id) ?? UUID()
                            photo.senderName = remotePhoto.sender_name
                            photo.createdAt = remotePhoto.created_at
                            photo.expiresAt = remotePhoto.expires_at
                            photo.remoteUrl = remotePhoto.url
                            
                            // Save image locally
                            if let localPath = PhotoCacheManager.shared.cachePhoto(data, for: photoId) {
                                photo.localPath = localPath.path
                            }
                            
                            try context.save()
                        }
                    } catch {
                        print("Failed to download/cache photo \(remotePhoto.id): \(error)")
                    }
                }
            }
            
            // Clean expired photos
            try await photoRepository.deleteExpiredPhotos()
            
        } catch NetworkError.unauthorized {
            throw NetworkError.unauthorized
        } catch {
            print("Photo sync failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSync() {
        // Sync when app becomes active
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.syncOnForeground()
                }
            }
            .store(in: &cancellables)
        
        // Sync when network becomes available
        // In a real app, you'd use NWPathMonitor here
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                if NetworkService.shared.isConnected {
                    Task {
                        await self?.performSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Debug
    
    func forceSync() async {
        // Force a sync regardless of last sync time
        await performSync()
    }
    
    func clearSyncData() {
        userDefaults.removeObject(forKey: lastSyncDateKey)
        lastSyncDate = nil
    }
}

// MARK: - Sync Status

extension SyncManager {
    enum SyncStatus {
        case idle
        case syncing
        case success(Date)
        case failure(Error)
    }
    
    var currentStatus: SyncStatus {
        if isSyncing {
            return .syncing
        } else if let error = syncError {
            return .failure(error)
        } else if let date = lastSyncDate {
            return .success(date)
        } else {
            return .idle
        }
    }
    
    var statusDescription: String {
        switch currentStatus {
        case .idle:
            return "Not synced"
        case .syncing:
            return "Syncing..."
        case .success(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .failure(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}

import Foundation
import SwiftUI
import Combine

@MainActor
class GroupsViewModel: ObservableObject {
    @Published var groups: [GroupViewModel] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedGroupForCamera: GroupViewModel?
    @Published var selectedGroupForPhotos: GroupViewModel?
    @Published var uploadProgress: [UUID: Double] = [:] // GroupId -> Progress
    
    private let groupRepository: GroupRepositoryProtocol
    private let networkService: NetworkServiceProtocol
    private let photoUploadService: PhotoUploadServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        groupRepository: GroupRepositoryProtocol? = nil,
        networkService: NetworkServiceProtocol = NetworkService.shared,
        photoUploadService: PhotoUploadServiceProtocol = PhotoUploadService.shared
    ) {
        self.networkService = networkService
        self.photoUploadService = photoUploadService
        self.groupRepository = groupRepository ?? GroupRepository(
            networkService: networkService
        )
        
        // Listen for sync updates
        SyncManager.shared.$lastSyncDate
            .sink { [weak self] _ in
                Task {
                    await self?.loadGroups()
                }
            }
            .store(in: &cancellables)
        
        // Listen for upload progress
        photoUploadService.uploadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.handleUploadProgress(progress)
            }
            .store(in: &cancellables)
        
        // Listen for upload notifications
        NotificationCenter.default.publisher(for: .photoUploadProgress)
            .compactMap { $0.userInfo }
            .sink { [weak self] userInfo in
                if let photoId = userInfo["photoId"] as? UUID,
                   let progress = userInfo["progress"] as? Double {
                    self?.updateProgressForPhoto(photoId: photoId, progress: progress)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .photoUploadCompleted)
            .compactMap { $0.userInfo?["photoId"] as? UUID }
            .sink { [weak self] photoId in
                self?.handleUploadCompleted(photoId: photoId)
            }
            .store(in: &cancellables)
    }
    
    func loadGroups() async {
        isLoading = true
        error = nil
        
        do {
            // Fetch from repository (handles offline/online)
            let coreDataGroups = try await groupRepository.fetchGroups()
            
            // Convert to view models
            groups = coreDataGroups.map { group in
                GroupViewModel(from: group)
            }
            
            // Sort by most recent activity
            groups.sort { group1, group2 in
                if let date1 = group1.lastPhotoDate, let date2 = group2.lastPhotoDate {
                    return date1 > date2
                } else if group1.lastPhotoDate != nil {
                    return true
                } else if group2.lastPhotoDate != nil {
                    return false
                } else {
                    return group1.name < group2.name
                }
            }
        } catch {
            self.error = error
            print("Error loading groups: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteGroup(_ groupId: UUID) async throws {
        try await groupRepository.deleteGroup(groupId)
        await loadGroups()
    }
    
    func refreshGroups() async {
        await SyncManager.shared.performSync()
    }
    
    // MARK: - Upload Progress Handling
    
    private func handleUploadProgress(_ progress: UploadProgress) {
        // Find which group this upload belongs to
        // For now, we'll need to track uploads by group
        // This would be improved with a proper upload tracking system
        
        switch progress.status {
        case .uploading(let progressValue):
            // Update progress for the group
            updateUploadProgress(progressValue)
        case .completed:
            // Clear progress and refresh groups
            clearUploadProgress()
            Task {
                await loadGroups()
            }
        case .failed:
            // Clear progress and show error
            clearUploadProgress()
        default:
            break
        }
    }
    
    private func updateProgressForPhoto(photoId: UUID, progress: Double) {
        // In a real app, we'd track which group each photo belongs to
        // For demo, we'll update the first group that's uploading
        if let firstGroup = groups.first {
            uploadProgress[firstGroup.id] = progress
        }
    }
    
    private func handleUploadCompleted(photoId: UUID) {
        // Clear progress for the group
        clearUploadProgress()
        
        // Refresh groups to show updated status
        Task {
            await loadGroups()
        }
    }
    
    private func updateUploadProgress(_ progress: Double) {
        // Update the first group that has a photo being uploaded
        if let firstGroup = groups.first(where: { !$0.hasSentToday }) {
            uploadProgress[firstGroup.id] = progress
        }
    }
    
    private func clearUploadProgress() {
        uploadProgress.removeAll()
    }
}

struct GroupViewModel: Identifiable {
    let id: UUID
    let name: String
    let memberCount: Int
    let memberAvatars: [String]
    let hasSentToday: Bool
    let lastPhotoTime: String?
    let lastPhotoDate: Date?
    
    init(from coreDataGroup: Group) {
        self.id = coreDataGroup.id
        self.name = coreDataGroup.name
        self.memberCount = coreDataGroup.memberArray.count
        self.memberAvatars = coreDataGroup.memberArray
            .prefix(5)
            .map { $0.firstName }
        self.hasSentToday = coreDataGroup.hasSentToday
        self.lastPhotoDate = coreDataGroup.lastPhotoDate
        
        // Format last photo time
        if let lastPhoto = coreDataGroup.lastPhotoDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            self.lastPhotoTime = formatter.localizedString(for: lastPhoto, relativeTo: Date())
        } else {
            self.lastPhotoTime = nil
        }
    }
    
    // For preview/testing
    init(
        id: UUID,
        name: String,
        memberCount: Int,
        memberAvatars: [String],
        hasSentToday: Bool,
        lastPhotoTime: String?
    ) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.memberAvatars = memberAvatars
        self.hasSentToday = hasSentToday
        self.lastPhotoTime = lastPhotoTime
        self.lastPhotoDate = nil
    }
}

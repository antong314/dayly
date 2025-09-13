# Phase 5: Photo Upload & Sync

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
Phases 0-4 are complete with:
- Full authentication system
- Groups management working
- Camera capture implemented
- Dayly limit enforcement
- Local photo storage via Core Data

## Your Task: Phase 5 - Photo Upload & Sync

Implement the photo upload system with background uploads, retry logic, and sync.

### iOS Upload Queue System

**Create: `implementation/ios/Dayly/Core/Services/PhotoUploadService.swift`**
```swift
import Foundation
import UIKit

protocol PhotoUploadServiceProtocol {
    func queuePhoto(_ photo: PhotoUpload) async
    func retryFailedUploads() async
    var uploadProgress: AnyPublisher<UploadProgress, Never> { get }
}

struct PhotoUpload {
    let id: UUID
    let groupId: UUID
    let imageData: Data
    let retryCount: Int = 0
    let createdAt: Date
}

struct UploadProgress {
    let photoId: UUID
    let progress: Double // 0.0 to 1.0
    let status: UploadStatus
}

enum UploadStatus {
    case queued
    case uploading(progress: Double)
    case completed
    case failed(Error)
}

@MainActor
class PhotoUploadService: PhotoUploadServiceProtocol {
    @Published private var progressSubject = PassthroughSubject<UploadProgress, Never>()
    
    var uploadProgress: AnyPublisher<UploadProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    private let uploadQueue = OperationQueue()
    private let networkService: NetworkService
    private let photoRepository: PhotoRepositoryProtocol
    
    init(
        networkService: NetworkService = NetworkService.shared,
        photoRepository: PhotoRepositoryProtocol = PhotoRepository()
    ) {
        self.networkService = networkService
        self.photoRepository = photoRepository
        
        uploadQueue.maxConcurrentOperationCount = 1
        uploadQueue.qualityOfService = .userInitiated
    }
    
    func queuePhoto(_ photo: PhotoUpload) async {
        // Add to upload queue
        let operation = PhotoUploadOperation(
            photo: photo,
            networkService: networkService,
            onProgress: { [weak self] progress in
                self?.progressSubject.send(progress)
            }
        )
        
        uploadQueue.addOperation(operation)
    }
    
    func retryFailedUploads() async {
        // Get failed uploads from Core Data
        // Re-queue with increased retry count
        // Implement exponential backoff
    }
}
```

### Background Upload Manager

**Create: `implementation/ios/Dayly/Core/Services/BackgroundUploadManager.swift`**
```swift
import UIKit

class BackgroundUploadManager: NSObject {
    static let shared = BackgroundUploadManager()
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.daily.photo-upload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var uploadTasks: [URLSessionTask: PhotoUpload] = [:]
    
    func uploadPhoto(_ photo: PhotoUpload) async throws -> String {
        // Create upload request
        let url = try await getUploadURL(for: photo.groupId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        // Create background upload task
        let task = urlSession.uploadTask(with: request, fromFile: savePhotoToTemp(photo.imageData))
        uploadTasks[task] = photo
        
        task.resume()
        
        return task.taskIdentifier.description
    }
    
    private func getUploadURL(for groupId: UUID) async throws -> URL {
        // Call backend to get signed upload URL
        let response = try await networkService.getUploadURL(groupId: groupId)
        return URL(string: response.uploadURL)!
    }
    
    private func savePhotoToTemp(_ data: Data) -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try? data.write(to: tempURL)
        return tempURL
    }
}

extension BackgroundUploadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { uploadTasks[task] = nil }
        
        guard let photo = uploadTasks[task] else { return }
        
        if let error = error {
            // Handle retry logic
            retryUpload(photo, error: error)
        } else {
            // Confirm upload with backend
            Task {
                await confirmUpload(photo)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let photo = uploadTasks[task] else { return }
        
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        
        // Notify progress
        NotificationCenter.default.post(
            name: .photoUploadProgress,
            object: nil,
            userInfo: [
                "photoId": photo.id,
                "progress": progress
            ]
        )
    }
}
```

### Backend Upload Flow

**Create/Update: `implementation/backend/app/api/photos.py`**
```python
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from app.core.supabase import supabase_client
from app.core.security import get_current_user
from app.models.schemas import UploadURLRequest, PhotoResponse
import uuid
from datetime import datetime, timedelta

router = APIRouter()

@router.post("/upload")
async def upload_photo(
    group_id: str,
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user)
):
    """Upload photo to Supabase Storage"""
    # Check daily limit
    today = datetime.now().date()
    existing_send = supabase_client.table("daily_sends").select("*").eq(
        "user_id", user_id
    ).eq("group_id", group_id).eq("sent_date", today).execute()
    
    if existing_send.data:
        raise HTTPException(
            status_code=400, 
            detail="Already sent photo to this group today"
        )
    
    # Validate file
    if file.size > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=413, detail="File too large")
    
    if file.content_type not in ["image/jpeg", "image/png", "image/heif"]:
        raise HTTPException(status_code=415, detail="Invalid file type")
    
    # Generate storage path
    file_extension = file.filename.split(".")[-1]
    storage_path = f"{group_id}/{user_id}/{uuid.uuid4()}.{file_extension}"
    
    # Upload to Supabase Storage
    file_content = await file.read()
    
    try:
        storage_response = supabase_client.storage.from_("photos").upload(
            storage_path,
            file_content,
            {"content-type": file.content_type}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
    
    # Create photo record
    photo_record = supabase_client.table("photos").insert({
        "group_id": group_id,
        "sender_id": user_id,
        "storage_path": storage_path
    }).execute()
    
    # Mark daily send
    supabase_client.table("daily_sends").insert({
        "user_id": user_id,
        "group_id": group_id,
        "sent_date": today
    }).execute()
    
    # Trigger notification for group members
    await notify_group_members(group_id, user_id)
    
    return {
        "photo_id": photo_record.data[0]["id"],
        "expires_at": photo_record.data[0]["expires_at"]
    }

@router.get("/{group_id}/today")
async def get_todays_photos(
    group_id: str,
    user_id: str = Depends(get_current_user)
):
    """Get today's photos for a group"""
    # Verify user is member
    membership = supabase_client.table("group_members").select("*").eq(
        "group_id", group_id
    ).eq("user_id", user_id).eq("is_active", True).execute()
    
    if not membership.data:
        raise HTTPException(status_code=403, detail="Not a member of this group")
    
    # Get photos from last 24 hours
    yesterday = datetime.now() - timedelta(days=1)
    
    photos = supabase_client.table("photos").select(
        """
        *,
        profiles:sender_id(first_name)
        """
    ).eq("group_id", group_id).gt(
        "created_at", yesterday.isoformat()
    ).execute()
    
    # Generate signed URLs
    photos_with_urls = []
    for photo in photos.data:
        # Get signed URL (1 hour expiry)
        url_response = supabase_client.storage.from_("photos").create_signed_url(
            photo["storage_path"], 
            3600  # 1 hour
        )
        
        photos_with_urls.append({
            "id": photo["id"],
            "sender_id": photo["sender_id"],
            "sender_name": photo["profiles"]["first_name"] or "User",
            "url": url_response["signedURL"],
            "timestamp": photo["created_at"]
        })
    
    return photos_with_urls

async def notify_group_members(group_id: str, sender_id: str):
    """Send push notification to group members"""
    # This will be fully implemented in Phase 7
    # For now, just log
    print(f"Would notify members of group {group_id} about photo from {sender_id}")
```

### Supabase Storage Setup

In Supabase Dashboard:
1. Create storage bucket named 'photos'
2. Set to private (no public access)
3. Add policies:

```sql
-- Allow authenticated users to upload to their paths
CREATE POLICY "Users can upload photos" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'photos' AND
    auth.uid()::text = split_part(name, '/', 2)
);

-- Allow users to view photos in their groups
CREATE POLICY "Users can view group photos" ON storage.objects
FOR SELECT USING (
    bucket_id = 'photos' AND
    EXISTS (
        SELECT 1 FROM group_members
        WHERE group_members.group_id = split_part(name, '/', 1)::uuid
        AND group_members.user_id = auth.uid()
        AND group_members.is_active = true
    )
);
```

### Update Camera View Model

Update `CameraViewModel.swift` to use upload service:
```swift
func sendPhoto(_ image: UIImage) async {
    isCapturing = true
    
    do {
        // Process image
        let processedImage = ImageProcessor.processForUpload(image) ?? image
        
        // Convert to JPEG
        guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
            throw PhotoError.processingFailed
        }
        
        // Create upload
        let upload = PhotoUpload(
            id: UUID(),
            groupId: groupId,
            imageData: imageData,
            createdAt: Date()
        )
        
        // Queue for upload
        await photoUploadService.queuePhoto(upload)
        
        // Save reference locally
        let photo = Photo(
            id: upload.id,
            groupId: groupId,
            senderId: currentUserId,
            createdAt: Date()
        )
        try await photoRepository.savePhoto(photo)
        
    } catch {
        self.error = error
    }
    
    isCapturing = false
}
```

### Sync Manager Updates

Update `SyncManager.swift` to handle photo syncing:
```swift
extension SyncManager {
    func syncPhotos(for groupId: UUID) async {
        do {
            // Fetch today's photos from backend
            let remotePhotos = try await networkService.getTodaysPhotos(groupId: groupId)
            
            // Update local cache
            for remotePhoto in remotePhotos {
                // Check if already cached
                if !photoRepository.isPhotoCached(remotePhoto.id) {
                    // Download and cache
                    if let imageData = try? await networkService.downloadPhoto(from: remotePhoto.url) {
                        try await photoRepository.cachePhoto(
                            id: remotePhoto.id,
                            data: imageData,
                            metadata: remotePhoto
                        )
                    }
                }
            }
            
            // Clean expired photos
            try await photoRepository.deleteExpiredPhotos()
            
        } catch {
            print("Photo sync failed: \(error)")
        }
    }
}
```

### Retry Logic

**Create: `implementation/ios/Dayly/Core/Services/RetryManager.swift`**
```swift
class RetryManager {
    static func retryWithExponentialBackoff<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? UploadError.maxRetriesExceeded
    }
}
```

### Update App Delegate for Background

Update `DaylyApp.swift`:
```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Handle background upload completion
        BackgroundUploadManager.shared.handleBackgroundSession(
            identifier: identifier,
            completionHandler: completionHandler
        )
    }
}

@main
struct DaylyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // ... rest of app
}
```

### Progress UI

Update group card to show upload progress:
```swift
// In GroupCard.swift
if let uploadProgress = viewModel.activeUploadProgress {
    ProgressView(value: uploadProgress)
        .progressViewStyle(LinearProgressViewStyle())
        .padding(.horizontal)
}
```

## Testing

1. **Test Upload Flow:**
   - Photo uploads successfully
   - Progress updates in UI
   - Completes in background

2. **Test Retry Logic:**
   - Disconnect network mid-upload
   - Verify retry with backoff
   - Eventually succeeds when reconnected

3. **Test Dayly Limit:
   - Can't upload second photo
   - Backend enforces limit

4. **Test Sync:**
   - Photos appear on other devices
   - Expired photos deleted
   - Works offline then syncs

## Success Criteria
- [ ] Photos upload to Supabase Storage
- [ ] Upload progress shown in UI
- [ ] Background uploads continue when app closed
- [ ] Failed uploads retry automatically
- [ ] Dayly send limit enforced on backend
- [ ] Photos sync across devices
- [ ] Signed URLs work for viewing
- [ ] 48-hour cleanup functions
- [ ] Offline queue for uploads

## Next Phase Preview
Phase 6 will implement the photo viewing experience with swipe navigation and auto-cleanup.

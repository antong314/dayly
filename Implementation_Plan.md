# Dayly - Detailed Implementation Plan

## Overview
This implementation plan breaks down the Dayly app into 10 independent phases that can be developed and tested separately. Each phase includes detailed specifications, deliverables, and testing criteria.

## Technology Stack Update
This plan has been updated to use:
- **Backend**: Python 3.11+ with FastAPI (instead of Node.js/Express)
- **Database & Auth**: Supabase (PostgreSQL with built-in auth, storage, and realtime)
- **Storage**: Supabase Storage (instead of S3/Spaces)
- **Deployment**: DigitalOcean App Platform
- **iOS**: SwiftUI with Supabase Swift SDK

Key benefits of using Supabase:
- Built-in phone authentication
- Row Level Security (RLS) for data access control
- Integrated file storage with signed URLs
- Realtime subscriptions out of the box
- Automatic database backups
- Edge Functions for complex operations (if needed)

## Phase 0: Project Setup & Infrastructure (3-4 days)

### iOS App Setup
**Specifications:**
- Create new iOS project using SwiftUI
- Minimum iOS version: 15.0
- Configure app identifiers and capabilities
- Set up project structure following MVVM pattern
- Configure SwiftLint for code consistency

**Project Structure:**
```
Dayly/
├── App/
│   ├── DaylyApp.swift
│   └── Info.plist
├── Core/
│   ├── Network/
│   ├── Storage/
│   ├── Extensions/
│   └── Constants/
├── Features/
│   ├── Authentication/
│   ├── Groups/
│   ├── Camera/
│   └── Photos/
├── Resources/
│   └── Assets.xcassets
└── Tests/
```

**Dependencies (via Swift Package Manager):**
- Alamofire (networking)
- KeychainAccess (secure storage)
- Sentry (error tracking)

### Backend Infrastructure Setup
**Specifications:**
- Python 3.11+ with FastAPI
- Supabase for database, auth, and storage
- Pydantic for data validation
- Environment configuration with python-dotenv

**Supabase Project Setup:**
- Create new Supabase project
- Enable Phone Auth provider
- Configure storage buckets for photos
- Set up Row Level Security (RLS) policies
- Edge Functions for complex operations (if needed)

**Database Schema (via Supabase migrations):**
```sql
-- Users table is managed by Supabase Auth
-- Additional user data in profiles table
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    first_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active TIMESTAMP
);

-- Custom tables for app logic
CREATE TABLE groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE group_members (
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (group_id, user_id)
);

-- Additional tables for invites and push notifications
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(6) UNIQUE NOT NULL,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    invited_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    used_by UUID REFERENCES auth.users(id)
);

CREATE TABLE user_devices (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) DEFAULT 'ios',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, device_token)
);

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_sends ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
```

**API Structure:**
```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   ├── auth.py
│   │   ├── groups.py
│   │   ├── photos.py
│   │   └── invites.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   └── supabase.py
│   ├── models/
│   │   └── schemas.py
│   └── services/
│       ├── sms_service.py
│       └── storage_service.py
├── tests/
├── requirements.txt
├── .env
└── Dockerfile
```

**Deployment:**
- DigitalOcean App Platform
- Python buildpack
- Environment variables for Supabase credentials
- Auto-deploy from GitHub

**Deliverables:**
- [ ] iOS project with proper structure
- [ ] Backend API boilerplate running
- [ ] Database connected and migrations ready
- [ ] Development environment documented
- [ ] CI/CD pipeline configured (GitHub Actions)

---

## Phase 1: Authentication System (4-5 days)

### iOS Authentication Module
**Specifications:**
```swift
// Core authentication interfaces
protocol AuthenticationServiceProtocol {
    func requestVerification(phoneNumber: String) async throws -> VerificationSession
    func confirmVerification(session: VerificationSession, code: String) async throws -> AuthToken
    func logout() async
    var isAuthenticated: Bool { get }
}

struct VerificationSession {
    let sessionId: String
    let phoneNumber: String
    let expiresAt: Date
}

struct AuthToken {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}
```

**UI Components:**
- Phone number input view with country code picker
- Verification code input (6 digits, auto-advance)
- Loading states and error handling
- Automatic SMS code detection (if available)

### Backend Authentication with Supabase
**Supabase Auth Configuration:**
- Phone auth provider enabled in Supabase dashboard
- Custom SMS template: "Your Dayly verification code is: {{.Code}}"
- Token expiration: Configurable in Supabase

**FastAPI Endpoints (wrapping Supabase Auth):**
```python
# app/api/auth.py
from fastapi import APIRouter, HTTPException
from app.core.supabase import supabase_client
from app.models.schemas import PhoneVerification, VerifyCode

router = APIRouter()

@router.post("/request-verification")
async def request_verification(data: PhoneVerification):
    """Send OTP to phone number via Supabase Auth"""
    try:
        response = supabase_client.auth.sign_in_with_otp({
            "phone": data.phone_number
        })
        return {"message": "Verification code sent", "expires_in": 300}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/verify")
async def verify_code(data: VerifyCode):
    """Verify OTP and return session"""
    try:
        response = supabase_client.auth.verify_otp({
            "phone": data.phone_number,
            "token": data.code,
            "type": "sms"
        })
        
        # Create/update profile
        profile_data = {"first_name": data.first_name} if data.first_name else {}
        supabase_client.table("profiles").upsert({
            "id": response.user.id,
            **profile_data
        }).execute()
        
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "user": {
                "id": response.user.id,
                "phone": response.user.phone
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/refresh")
async def refresh_token(refresh_token: str):
    """Refresh access token using Supabase"""
    try:
        response = supabase_client.auth.refresh_session(refresh_token)
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token
        }
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
```

**Security Measures (Built into Supabase):**
- Rate limiting configurable in Supabase dashboard
- Automatic OTP expiration (default 60 seconds, configurable)
- Secure session management
- RLS policies for data access control

**Deliverables:**
- [ ] Phone verification flow working end-to-end
- [ ] Token management and refresh logic
- [ ] Keychain storage implementation
- [ ] Error handling for common scenarios
- [ ] Unit tests for auth logic

---

## Phase 2: Data Layer & Local Storage (3-4 days)

### iOS Core Data Models
**Specifications:**
```swift
// Core Data Entities
@objc(User)
class User: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var phoneNumber: String
    @NSManaged var firstName: String?
}

@objc(Group)
class Group: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var members: Set<GroupMember>
    @NSManaged var lastPhotoDate: Date?
    @NSManaged var hasSentToday: Bool
}

@objc(Photo)
class Photo: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var groupId: UUID
    @NSManaged var senderId: UUID
    @NSManaged var localPath: String?
    @NSManaged var remoteUrl: String?
    @NSManaged var createdAt: Date
    @NSManaged var expiresAt: Date
}
```

**Repository Pattern:**
```swift
protocol GroupRepositoryProtocol {
    func fetchGroups() async throws -> [Group]
    func createGroup(_ group: Group) async throws
    func updateGroup(_ group: Group) async throws
    func deleteGroup(_ groupId: UUID) async throws
}

protocol PhotoRepositoryProtocol {
    func fetchPhotos(for groupId: UUID) async throws -> [Photo]
    func savePhoto(_ photo: Photo) async throws
    func deleteExpiredPhotos() async throws
}
```

### Backend Data Models with Supabase
**Database Schema (Complete with RLS policies):**
```sql
-- Photos table with automatic expiration
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id),
    storage_path VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '48 hours')
);

CREATE TABLE daily_sends (
    user_id UUID REFERENCES auth.users(id),
    group_id UUID REFERENCES groups(id),
    sent_date DATE DEFAULT CURRENT_DATE,
    PRIMARY KEY (user_id, group_id, sent_date)
);

-- RLS Policies
CREATE POLICY "Users can view groups they belong to"
ON groups FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM group_members
        WHERE group_members.group_id = groups.id
        AND group_members.user_id = auth.uid()
        AND group_members.is_active = true
    )
);

CREATE POLICY "Users can view photos in their groups"
ON photos FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM group_members
        WHERE group_members.group_id = photos.group_id
        AND group_members.user_id = auth.uid()
        AND group_members.is_active = true
    )
    AND expires_at > CURRENT_TIMESTAMP
);

-- Supabase Storage Bucket Configuration
-- Create 'photos' bucket with:
-- - Private access (no public URLs)
-- - 10MB file size limit
-- - Allowed MIME types: image/jpeg, image/png, image/heif

-- Scheduled function to delete expired photos (Supabase Edge Function)
CREATE OR REPLACE FUNCTION delete_expired_photos()
RETURNS void AS $$
BEGIN
    DELETE FROM photos WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Schedule to run every hour using pg_cron (configure in Supabase dashboard)
```

**Realtime Subscriptions Setup:**
```python
# Enable realtime for photos table in Supabase dashboard
# Client subscribes to new photos in their groups
```

**Sync Manager:**
- Conflict resolution strategy (last-write-wins)
- Offline queue for pending operations
- Background sync on app launch

**Deliverables:**
- [ ] Core Data stack configured
- [ ] Repository implementations
- [ ] Migration strategy for schema updates
- [ ] Offline storage working
- [ ] Data sync foundations ready

---

## Phase 3: Groups Management (4-5 days)

### iOS Groups Feature
**UI Specifications:**
- Groups list view (max 5 groups)
- Group card component with member avatars
- Create group flow (name + contact selection)
- Group settings sheet

**Group Card Design:**
```
┌─────────────────────────────┐
│ Family              •••     │  <- Name + settings button
│ ⚪⚪⚪⚪⚪ +2 more     │  <- Member bubbles
│ ✅ Sent • 2 hours ago      │  <- Status + timestamp
└─────────────────────────────┘
```

**View Models:**
```swift
@MainActor
class GroupsViewModel: ObservableObject {
    @Published var groups: [GroupViewModel] = []
    @Published var isCreatingGroup = false
    
    func loadGroups() async
    func createGroup(name: String, members: [Contact]) async throws
    func deleteGroup(_ groupId: UUID) async throws
}

struct GroupViewModel: Identifiable {
    let id: UUID
    let name: String
    let memberCount: Int
    let memberAvatars: [String] // First names
    let hasSentToday: Bool
    let lastPhotoTime: String?
}
```

### Backend Groups API with FastAPI
**Endpoints:**
```python
# app/api/groups.py
from fastapi import APIRouter, Depends, HTTPException
from app.core.supabase import supabase_client
from app.core.security import get_current_user
from app.models.schemas import GroupCreate, GroupResponse, AddMembers

router = APIRouter()

@router.get("/", response_model=list[GroupResponse])
async def get_groups(user_id: str = Depends(get_current_user)):
    """Get all groups for current user"""
    # Query with RLS automatically filters by user
    groups = supabase_client.table("groups").select(
        "*, group_members!inner(user_id), photos(created_at, sender_id)"
    ).execute()
    
    # Check daily sends
    today = datetime.now().date()
    daily_sends = supabase_client.table("daily_sends").select("group_id").eq(
        "user_id", user_id
    ).eq("sent_date", today).execute()
    
    return format_groups_response(groups.data, daily_sends.data)

@router.post("/", response_model=dict)
async def create_group(
    data: GroupCreate,
    user_id: str = Depends(get_current_user)
):
    """Create new group and invite members"""
    # Check group limit (5 max)
    existing_groups = supabase_client.table("group_members").select(
        "group_id"
    ).eq("user_id", user_id).execute()
    
    if len(existing_groups.data) >= 5:
        raise HTTPException(status_code=400, detail="Maximum 5 groups allowed")
    
    # Create group
    group = supabase_client.table("groups").insert({
        "name": data.name,
        "created_by": user_id
    }).execute()
    
    # Add creator as member
    supabase_client.table("group_members").insert({
        "group_id": group.data[0]["id"],
        "user_id": user_id
    }).execute()
    
    # Process invites
    invite_links = await process_invites(
        group.data[0]["id"], 
        data.member_phone_numbers
    )
    
    return {
        "id": group.data[0]["id"],
        "invite_links": invite_links
    }

@router.put("/{group_id}")
async def update_group(
    group_id: str,
    name: str,
    user_id: str = Depends(get_current_user)
):
    """Update group name"""
    # RLS ensures only members can update
    result = supabase_client.table("groups").update({
        "name": name
    }).eq("id", group_id).execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Group not found")
    
    return {"success": True}

@router.delete("/{group_id}")
async def leave_group(
    group_id: str,
    user_id: str = Depends(get_current_user)
):
    """Leave a group (soft delete membership)"""
    supabase_client.table("group_members").update({
        "is_active": False
    }).eq("group_id", group_id).eq("user_id", user_id).execute()
    
    return {"success": True}
```

**Business Logic:**
- Maximum 5 groups per user
- Maximum 12 members per group
- Minimum 2 members to create group
- All members can add/remove others (no admin)

**Deliverables:**
- [ ] Groups list UI with proper styling
- [ ] Create group flow complete
- [ ] Contact picker integration
- [ ] Group settings functionality
- [ ] API endpoints tested
- [ ] Group member sync working

---

## Phase 4: Camera & Photo Capture (4-5 days)

### Camera Module
**Specifications:**
```swift
protocol CameraServiceProtocol {
    func checkPermissions() async -> Bool
    func requestPermissions() async -> Bool
    func capturePhoto() async throws -> UIImage
    func toggleCamera()
    func toggleFlash()
}

struct CameraView: View {
    // Full-screen camera preview
    // Minimal controls: capture, flip, flash, close
    // No filters, no gallery access
}

struct PhotoPreviewView: View {
    let image: UIImage
    let onSend: () async -> Void
    let onRetake: () -> Void
    // 3-second auto-dismiss timer
}
```

**Camera Flow States:**
1. Permission check/request
2. Camera active (capture available)
3. Preview (3 seconds, then auto-proceed)
4. Sending (loading state)
5. Success (brief confirmation)

**Image Processing:**
- Convert HEIC to JPEG
- Maximum resolution: 2048x2048
- Compression quality: 0.8
- EXIF data stripped

**Dayly Limit Check:
```swift
func canSendToGroup(_ groupId: UUID) -> Bool {
    // Check daily_sends for current date
    // Show countdown if already sent
}

struct DaylyLimitView: View {
    let timeUntilMidnight: TimeInterval
    // "Already shared today. See you tomorrow!"
    // Countdown timer display
}
```

**Deliverables:**
- [ ] Camera permissions handling
- [ ] Camera capture working smoothly
- [ ] Preview flow with auto-advance
- [ ] Image processing pipeline
- [ ] Dayly limit enforcement
- [ ] Proper error states

---

## Phase 5: Photo Upload & Sync (5-6 days)

### Upload Queue System
**iOS Implementation:**
```swift
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

class BackgroundUploadManager {
    // URLSession background configuration
    // Retry logic with exponential backoff
    // Progress tracking
}
```

### Backend Upload Flow with Supabase Storage
**FastAPI Endpoints:**
```python
# app/api/photos.py
from fastapi import APIRouter, Depends, HTTPException, UploadFile
from app.core.supabase import supabase_client
from app.core.security import get_current_user
import uuid
from datetime import datetime, timedelta

router = APIRouter()

@router.post("/upload")
async def upload_photo(
    group_id: str,
    file: UploadFile,
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
    
    # Check file size and type
    if file.size > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=413, detail="File too large")
    
    if file.content_type not in ["image/jpeg", "image/png", "image/heif"]:
        raise HTTPException(status_code=415, detail="Invalid file type")
    
    # Generate unique path
    file_extension = file.filename.split(".")[-1]
    storage_path = f"{group_id}/{user_id}/{uuid.uuid4()}.{file_extension}"
    
    # Upload to Supabase Storage
    file_content = await file.read()
    storage_response = supabase_client.storage.from_("photos").upload(
        storage_path,
        file_content,
        {"content-type": file.content_type}
    )
    
    if storage_response.error:
        raise HTTPException(status_code=500, detail="Upload failed")
    
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
    # Get photos from last 24 hours
    yesterday = datetime.now() - timedelta(days=1)
    
    photos = supabase_client.table("photos").select(
        "*, profiles!photos_sender_id_fkey(first_name)"
    ).eq("group_id", group_id).gt(
        "created_at", yesterday.isoformat()
    ).execute()
    
    # Generate signed URLs for each photo
    photos_with_urls = []
    for photo in photos.data:
        # Get signed URL from Supabase Storage (1 hour expiry)
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
```

**Supabase Storage Configuration:**
- Storage bucket: 'photos' (private)
- File size limit: 10MB (configured in bucket settings)
- Allowed MIME types: image/jpeg, image/png, image/heif
- No public access - all via signed URLs
- Automatic cleanup via scheduled database function

**Sync Logic:**
- Check for new photos on app foreground
- WebSocket for real-time updates (optional)
- Efficient delta sync (only new photos)

**Deliverables:**
- [ ] Upload queue with retry logic
- [ ] Background upload support
- [ ] S3/Spaces integration working
- [ ] Progress tracking UI
- [ ] Photo fetch and caching
- [ ] 48-hour cleanup job

---

## Phase 6: Photo Viewing Experience (4-5 days)

### Photo Viewer UI
**Specifications:**
```swift
struct PhotoViewerView: View {
    let groupId: UUID
    @State private var photos: [PhotoViewModel] = []
    @State private var currentIndex: Int = 0
    
    // Full-screen photo display
    // Horizontal swipe navigation
    // Minimal overlay: sender name + time
    // Dismiss on vertical swipe
}

struct PhotoViewModel {
    let id: UUID
    let image: UIImage?
    let senderName: String
    let timeAgo: String
    let isLoading: Bool
}
```

**Image Caching:**
```swift
protocol ImageCacheProtocol {
    func store(_ image: UIImage, for key: String)
    func retrieve(for key: String) -> UIImage?
    func clear(olderThan date: Date)
}

// Memory + disk cache
// Automatic cleanup of expired photos
// Progressive loading with blur placeholder
```

**Gesture Handling:**
- Long press on group card → open viewer
- Horizontal swipe → navigate photos
- Vertical swipe down → dismiss
- No pinch zoom, no save button

**Photo Metadata Display:**
- Sender first name (from contacts)
- Relative time ("3 hours ago", "Just now")
- Fade in/out on tap

**Deliverables:**
- [ ] Photo viewer with swipe navigation
- [ ] Image caching system
- [ ] Progressive image loading
- [ ] Smooth animations
- [ ] Proper memory management
- [ ] 48-hour auto-cleanup

---

## Phase 7: Push Notifications (3-4 days)

### iOS Notification Setup
**Specifications:**
```swift
protocol NotificationServiceProtocol {
    func requestPermissions() async -> Bool
    func registerForPushNotifications() async
    func handleNotification(_ notification: UNNotification)
}

class NotificationManager {
    // APNS registration
    // Token management
    // Deep link handling
    // Notification grouping by group
}
```

**Notification Handling:**
- Register device token with backend
- Group notifications by group ID
- Single notification per group per day
- Deep link to specific group photos

### Backend Push Service
**FastAPI Endpoints:**
```python
# app/api/devices.py
from fastapi import APIRouter, Depends
from app.core.supabase import supabase_client
from app.core.security import get_current_user
from app.services.push_service import PushNotificationService

router = APIRouter()
push_service = PushNotificationService()

@router.post("/register")
async def register_device(
    device_token: str,
    platform: str = "ios",
    user_id: str = Depends(get_current_user)
):
    """Register device for push notifications"""
    # Upsert device token
    supabase_client.table("user_devices").upsert({
        "user_id": user_id,
        "device_token": device_token,
        "platform": platform,
        "updated_at": datetime.now().isoformat()
    }).execute()
    
    return {"success": True}

# app/services/push_service.py
class PushNotificationService:
    async def send_group_notification(
        self, 
        group_id: str, 
        exclude_user_id: str
    ):
        """Send notification for new photos in group"""
        # Check if first photo of the day for this group
        today_start = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        
        existing_photos = supabase_client.table("photos").select("id").eq(
            "group_id", group_id
        ).gte("created_at", today_start.isoformat()).execute()
        
        if len(existing_photos.data) > 1:
            # Not the first photo, skip notification
            return
        
        # Get group details and members
        group = supabase_client.table("groups").select(
            "name, group_members!inner(user_id)"
        ).eq("id", group_id).execute()
        
        if not group.data:
            return
        
        # Get device tokens for all members except sender
        member_ids = [
            m["user_id"] for m in group.data[0]["group_members"] 
            if m["user_id"] != exclude_user_id
        ]
        
        devices = supabase_client.table("user_devices").select(
            "device_token, platform"
        ).in_("user_id", member_ids).execute()
        
        # Send notifications
        group_name = group.data[0]["name"]
        for device in devices.data:
            await self._send_apns(
                device["device_token"],
                title="Dayly",
                body=f"{group_name} has new photos",
                data={"group_id": group_id, "type": "new_photos"}
            )
    
    async def _send_apns(self, token, title, body, data):
        """Send push via APNS using aioapns or similar"""
        # Implementation depends on APNS library choice
        pass
```

**Notification Rules:**
- One per group per day (first photo triggers)
- No notification for your own photos
- Respect mute settings
- Clear notification on app open

**Deliverables:**
- [ ] Push permission request flow
- [ ] Device token registration
- [ ] Notification handling and grouping
- [ ] Deep linking to groups
- [ ] Backend notification service
- [ ] Mute functionality

---

## Phase 8: Invites & Onboarding (4-5 days)

### Contact Integration
**Specifications:**
```swift
protocol ContactServiceProtocol {
    func requestAccess() async -> Bool
    func fetchContacts() async -> [Contact]
    func searchContacts(query: String) -> [Contact]
}

struct Contact {
    let identifier: String
    let firstName: String
    let phoneNumber: String
    let hasApp: Bool
}
```

**Invite Flow:**
```swift
struct ContactPickerView: View {
    @Binding var selectedContacts: [Contact]
    let maxSelection: Int = 11 // (12 minus self)
    
    // Search bar
    // Sectioned list (has app / needs invite)
    // Multi-select with checkmarks
}
```

### Backend Invite System
**FastAPI Endpoints:**
```python
# app/api/invites.py
from fastapi import APIRouter, Depends, HTTPException
from app.core.supabase import supabase_client
from app.core.security import get_current_user
from app.services.sms_service import send_invite_sms
import secrets
import string

router = APIRouter()

def generate_invite_code():
    """Generate 6-character invite code"""
    return ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))

@router.post("/check-users")
async def check_users(
    phone_numbers: list[str],
    user_id: str = Depends(get_current_user)
):
    """Check which phone numbers are existing users"""
    # Query auth.users by phone (requires service role key)
    existing_users = []
    needs_invite = []
    
    for phone in phone_numbers:
        # Check if user exists in Supabase Auth
        user_check = supabase_client.rpc(
            "check_phone_exists", 
            {"phone_number": phone}
        ).execute()
        
        if user_check.data:
            existing_users.append({
                "phone_number": phone,
                "user_id": user_check.data[0]["id"]
            })
        else:
            needs_invite.append(phone)
    
    return {
        "existing": existing_users,
        "needs_invite": needs_invite
    }

@router.post("/send")
async def send_invites(
    group_id: str,
    phone_numbers: list[str],
    user_id: str = Depends(get_current_user)
):
    """Send invite SMS to non-users"""
    # Verify sender is member of group
    membership = supabase_client.table("group_members").select("*").eq(
        "group_id", group_id
    ).eq("user_id", user_id).execute()
    
    if not membership.data:
        raise HTTPException(status_code=403, detail="Not a member of this group")
    
    # Get group name and sender name
    group = supabase_client.table("groups").select("name").eq(
        "id", group_id
    ).execute()
    
    sender = supabase_client.table("profiles").select("first_name").eq(
        "id", user_id
    ).execute()
    
    group_name = group.data[0]["name"]
    sender_name = sender.data[0]["first_name"] or "Someone"
    
    sent_invites = []
    
    for phone in phone_numbers:
        # Generate unique invite code
        invite_code = generate_invite_code()
        
        # Store invite
        supabase_client.table("invites").insert({
            "code": invite_code,
            "group_id": group_id,
            "phone_number": phone,
            "invited_by": user_id,
            "expires_at": (datetime.now() + timedelta(days=7)).isoformat()
        }).execute()
        
        # Send SMS
        app_store_link = "https://apps.apple.com/app/daily/id..."
        message = (
            f"{sender_name} invited you to share daily photos "
            f"with \"{group_name}\" on Dayly.\n"
            f"Download: {app_store_link}\n"
            f"Join with code: {invite_code}"
        )
        
        await send_invite_sms(phone, message)
        
        sent_invites.append({
            "phone_number": phone,
            "invite_code": invite_code
        })
    
    return {"sent": sent_invites}

@router.post("/redeem")
async def redeem_invite(
    invite_code: str,
    user_id: str = Depends(get_current_user)
):
    """Redeem invite code to join group"""
    # Find valid invite
    invite = supabase_client.table("invites").select(
        "*, groups(name)"
    ).eq("code", invite_code).gt(
        "expires_at", datetime.now().isoformat()
    ).execute()
    
    if not invite.data:
        raise HTTPException(status_code=404, detail="Invalid or expired invite code")
    
    invite_data = invite.data[0]
    
    # Add user to group
    supabase_client.table("group_members").insert({
        "group_id": invite_data["group_id"],
        "user_id": user_id
    }).execute()
    
    # Mark invite as used
    supabase_client.table("invites").update({
        "used_at": datetime.now().isoformat(),
        "used_by": user_id
    }).eq("code", invite_code).execute()
    
    return {
        "group_id": invite_data["group_id"],
        "group_name": invite_data["groups"]["name"]
    }
```

**SMS Invite Message:**
```
John invited you to share daily photos with "Family" on Dayly.
Download: [App Store Link]
Join with code: ABC123
```

**Onboarding Flow:**
1. Open app from invite link
2. Phone verification
3. Auto-join group with code
4. See last 24 hours of photos
5. Ready to share

**Deliverables:**
- [ ] Contact picker UI
- [ ] Contact permission handling
- [ ] Invite SMS integration
- [ ] Deep link handling for invites
- [ ] Auto-join group flow
- [ ] New user onboarding

---

## Phase 9: Polish & Edge Cases (5-6 days)

### Error Handling
**Comprehensive Error States:**
```swift
enum DaylyError: LocalizedError {
    case networkUnavailable
    case photoUploadFailed(retry: Bool)
    case groupLimitReached
    case invalidPhoneNumber
    case verificationFailed
    case cameraPermissionDenied
    
    var errorDescription: String? { }
    var recoverySuggestion: String? { }
}
```

**UI Polish:**
- Loading states with subtle animations
- Empty states with helpful messaging
- Error states with recovery actions
- Haptic feedback for key actions
- Accessibility labels throughout

### Block User Feature
**Implementation:**
```swift
// Long press photo → "Block person" option
POST /api/users/:userId/block
// Removes from all shared groups
// Prevents future group additions
```

### Performance Optimization
- Image loading optimization
- Memory management for photos
- Background task efficiency
- Network request batching
- Core Data query optimization

### Analytics (Basic)
```swift
// Privacy-focused analytics
enum AnalyticsEvent {
    case photoSent(groupId: UUID)
    case groupCreated
    case appOpened
    case inviteSent(count: Int)
}
```

### App Store Preparation
- App icon and launch screen
- Screenshot automation
- Privacy policy and terms
- App Store description
- TestFlight beta setup

**Deliverables:**
- [ ] Comprehensive error handling
- [ ] All UI states polished
- [ ] Block user functionality
- [ ] Performance optimization complete
- [ ] Basic analytics integrated
- [ ] App Store assets ready
- [ ] Beta testing plan

---

## Testing Strategy

### Unit Tests
- Repository tests with mocked Core Data
- Service layer tests with mocked network
- View model tests with combine
- Backend API endpoint tests

### Integration Tests
- End-to-end auth flow
- Photo upload and sync
- Group creation and management
- Notification delivery

### UI Tests
- Critical user flows automated
- Camera permission flows
- Group creation flow
- Photo viewing experience

### Beta Testing Plan
- 10-20 person closed beta
- Dayly usage for 2 weeks
- Feedback collection via TestFlight
- Performance monitoring with Sentry

---

## Timeline Summary

**Total Duration: 7-8 weeks**

- **Week 1:** Phase 0 + Phase 1 (Setup + Auth)
- **Week 2:** Phase 2 + Phase 3 start (Data + Groups)
- **Week 3:** Phase 3 complete + Phase 4 (Groups + Camera)
- **Week 4:** Phase 5 (Upload system)
- **Week 5:** Phase 6 + Phase 7 (Viewing + Notifications)
- **Week 6:** Phase 8 (Invites)
- **Week 7:** Phase 9 (Polish)
- **Week 8:** Beta testing + fixes

Each phase is designed to be independently testable with clear deliverables, allowing for parallel development where possible and easy progress tracking.

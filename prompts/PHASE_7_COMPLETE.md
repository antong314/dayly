# Phase 7: Push Notifications

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
Phases 0-6 are complete with:
- Full authentication and groups system
- Camera and photo upload working
- Photo viewing with caching
- Background uploads
- All core features functional

## Your Task: Phase 7 - Push Notifications

Implement push notifications for new photos with proper grouping and deep linking.

### iOS Notification Setup

**Create: `implementation/ios/Dayly/Core/Services/NotificationService.swift`**
```swift
import UserNotifications
import UIKit

protocol NotificationServiceProtocol {
    func requestPermissions() async -> Bool
    func registerForPushNotifications() async
    func handleNotification(_ notification: UNNotification)
}

@MainActor
class NotificationService: NSObject, NotificationServiceProtocol {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    @Published var pendingGroupId: UUID?
    
    override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    func requestPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    func registerForPushNotifications() async {
        guard await requestPermissions() else { return }
        
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func handleNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        if let groupId = userInfo["group_id"] as? String,
           let uuid = UUID(uuidString: groupId) {
            // Store for deep linking
            pendingGroupId = uuid
            
            // Post notification for app to handle
            NotificationCenter.default.post(
                name: .openGroupPhotos,
                object: nil,
                userInfo: ["groupId": uuid]
            )
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotification(response.notification)
        completionHandler()
    }
}

extension Notification.Name {
    static let openGroupPhotos = Notification.Name("openGroupPhotos")
}
```

### App Delegate Updates

**Update: `implementation/ios/Dayly/App/DaylyApp.swift`**
```swift
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Set up notifications
        Task {
            await NotificationService.shared.registerForPushNotifications()
        }
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device token: \(token)")
        
        // Register with backend
        Task {
            try? await NetworkService.shared.registerDeviceToken(token)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for notifications: \(error)")
    }
}

@main
struct DaylyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: .openGroupPhotos)) { notification in
                    if let groupId = notification.userInfo?["groupId"] as? UUID {
                        // Handle deep link to group photos
                        handleDeepLink(to: groupId)
                    }
                }
        }
    }
    
    private func handleDeepLink(to groupId: UUID) {
        // Navigate to photo viewer for this group
        // This will be handled by your navigation system
    }
}
```

### Backend Push Service

**Update: `implementation/backend/app/api/devices.py`**
```python
from fastapi import APIRouter, Depends, HTTPException
from app.core.supabase import supabase_client
from app.core.security import get_current_user
from app.models.schemas import DeviceRegistration
from datetime import datetime

router = APIRouter()

@router.post("/register")
async def register_device(
    data: DeviceRegistration,
    user_id: str = Depends(get_current_user)
):
    """Register device for push notifications"""
    # Upsert device token
    result = supabase_client.table("user_devices").upsert({
        "user_id": user_id,
        "device_token": data.device_token,
        "platform": data.platform,
        "updated_at": datetime.now().isoformat()
    }).execute()
    
    return {"success": True}

@router.delete("/unregister")
async def unregister_device(
    device_token: str,
    user_id: str = Depends(get_current_user)
):
    """Remove device token"""
    supabase_client.table("user_devices").delete().eq(
        "user_id", user_id
    ).eq("device_token", device_token).execute()
    
    return {"success": True}
```

**Create: `implementation/backend/app/services/push_service.py`**
```python
import aioapns
from app.core.config import settings
from app.core.supabase import supabase_client
from datetime import datetime
import asyncio

class PushNotificationService:
    def __init__(self):
        # Initialize APNS client
        self.apns_key_client = None
        if settings.APNS_KEY_ID and settings.APNS_TEAM_ID:
            self.apns_key_client = aioapns.APNs(
                key=settings.APNS_AUTH_KEY,
                key_id=settings.APNS_KEY_ID,
                team_id=settings.APNS_TEAM_ID,
                topic=settings.APNS_TOPIC,  # com.yourcompany.daily
                use_sandbox=settings.ENVIRONMENT != "production"
            )
    
    async def send_group_notification(
        self, 
        group_id: str, 
        sender_id: str
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
            """
            name,
            group_members!inner(
                user_id,
                is_active
            )
            """
        ).eq("id", group_id).execute()
        
        if not group.data:
            return
        
        group_name = group.data[0]["name"]
        
        # Get sender name
        sender = supabase_client.table("profiles").select("first_name").eq(
            "id", sender_id
        ).execute()
        
        sender_name = sender.data[0]["first_name"] if sender.data else "Someone"
        
        # Get device tokens for all active members except sender
        member_ids = [
            m["user_id"] for m in group.data[0]["group_members"] 
            if m["user_id"] != sender_id and m["is_active"]
        ]
        
        if not member_ids:
            return
        
        devices = supabase_client.table("user_devices").select(
            "device_token, platform"
        ).in_("user_id", member_ids).execute()
        
        # Send notifications
        notifications = []
        for device in devices.data:
            if device["platform"] == "ios":
                notification = aioapns.NotificationRequest(
                    device_token=device["device_token"],
                    message={
                        "aps": {
                            "alert": {
                                "title": "Dayly",
                                "body": f"{group_name} has new photos"
                            },
                            "badge": 1,
                            "sound": "default",
                            "thread-id": group_id  # For notification grouping
                        },
                        "group_id": group_id,
                        "type": "new_photos"
                    }
                )
                notifications.append(notification)
        
        # Send all notifications
        if notifications and self.apns_key_client:
            try:
                await self.apns_key_client.send_notification_batch(
                    notifications,
                    priority=aioapns.PRIORITY_HIGH
                )
            except Exception as e:
                print(f"Failed to send push notifications: {e}")

# Global instance
push_service = PushNotificationService()
```

**Update photo upload to trigger notifications:**

In `app/api/photos.py`, update the upload endpoint:
```python
from app.services.push_service import push_service

@router.post("/upload")
async def upload_photo(
    # ... existing parameters
):
    # ... existing upload logic
    
    # After successful upload
    # Trigger notification for group members
    asyncio.create_task(
        push_service.send_group_notification(group_id, user_id)
    )
    
    return {
        "photo_id": photo_record.data[0]["id"],
        "expires_at": photo_record.data[0]["expires_at"]
    }
```

### Update Models

**Add to: `implementation/backend/app/models/schemas.py`**
```python
class DeviceRegistration(BaseModel):
    device_token: str
    platform: str = "ios"
    
    @validator('device_token')
    def validate_token(cls, v):
        # Basic validation for APNS token format
        if not re.match(r'^[a-fA-F0-9]{64}$', v):
            raise ValueError('Invalid device token format')
        return v
```

### Network Service Updates

**Add to: `implementation/ios/Dayly/Core/Network/NetworkService.swift`**
```swift
extension NetworkService {
    func registerDeviceToken(_ token: String) async throws {
        let url = baseURL.appendingPathComponent("/api/devices/register")
        
        let body = [
            "device_token": token,
            "platform": "ios"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
    }
}
```

### Settings for Notifications

**Create: `implementation/ios/Dayly/Features/Settings/NotificationSettingsView.swift`**
```swift
struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Push Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationService.shared.requestPermissions()
                                if !granted {
                                    notificationsEnabled = false
                                    showingPermissionAlert = true
                                }
                            }
                        }
                    }
            } footer: {
                Text("Get notified when friends share photos in your groups")
            }
            
            Section("Notification Settings") {
                ForEach(groups) { group in
                    GroupNotificationRow(group: group)
                }
            }
        }
        .navigationTitle("Notifications")
        .alert("Notification Permission", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive photo alerts.")
        }
    }
}
```

### Environment Configuration

Add to backend `.env`:
```
# Apple Push Notification Service
APNS_KEY_ID=your_key_id
APNS_TEAM_ID=your_team_id
APNS_AUTH_KEY=path/to/AuthKey.p8
APNS_TOPIC=com.yourcompany.daily
```

### Testing Push Notifications

**Create: `implementation/backend/tests/test_notifications.py`**
```python
import pytest
from app.services.push_service import push_service

@pytest.mark.asyncio
async def test_notification_grouping():
    """Test that only first photo triggers notification"""
    # Upload first photo - should trigger
    # Upload second photo - should not trigger
    pass

@pytest.mark.asyncio
async def test_notification_delivery():
    """Test notification is sent to correct devices"""
    # Mock APNS client
    # Verify correct tokens receive notification
    pass
```

## Testing

1. **Test Permission Flow:**
   - First launch requests permission
   - Settings reflect permission state
   - Can re-request from settings

2. **Test Notification Delivery:**
   - First photo in group sends notification
   - Additional photos don't send
   - Only group members receive it

3. **Test Deep Linking:**
   - Tap notification opens photo viewer
   - Correct group is displayed
   - Works from background/killed state

4. **Test Grouping:**
   - Multiple groups show as threads
   - Badge count updates correctly

## Success Criteria
- [ ] Push permission requested on first launch
- [ ] Device token registered with backend
- [ ] Notifications sent for first photo only
- [ ] Notifications grouped by group
- [ ] Deep link opens correct group photos
- [ ] Can mute notifications per group
- [ ] Badge clears when viewing photos
- [ ] Works in foreground and background
- [ ] Notification text shows group name

## Next Phase Preview
Phase 8 will implement the invite system with contact integration and SMS invites.

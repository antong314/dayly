# Phase 9: Polish & Edge Cases

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
Phases 0-8 are complete with:
- All features implemented
- Core functionality working
- Ready for polish and optimization

## Your Task: Phase 9 - Polish & Edge Cases

Add comprehensive error handling, UI polish, performance optimization, and prepare for App Store release.

### Comprehensive Error Handling

**Create: `implementation/ios/Dayly/Core/Errors/DaylyError.swift`**
```swift
import Foundation

enum DaylyError: LocalizedError {
    // Network errors
    case networkUnavailable
    case serverError(statusCode: Int)
    case requestTimeout
    
    // Photo errors
    case photoUploadFailed(retry: Bool)
    case photoProcessingFailed
    case photoNotFound
    case dailyLimitReached
    
    // Group errors
    case groupLimitReached
    case groupNotFound
    case notGroupMember
    case invalidGroupName
    
    // Auth errors
    case invalidPhoneNumber
    case verificationFailed
    case sessionExpired
    
    // Permission errors
    case cameraPermissionDenied
    case contactsPermissionDenied
    case notificationPermissionDenied
    
    // Storage errors
    case insufficientStorage
    case cacheError
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection"
        case .serverError(let code):
            return "Server error (\(code))"
        case .requestTimeout:
            return "Request timed out"
        case .photoUploadFailed(let retry):
            return retry ? "Upload failed. Retrying..." : "Failed to upload photo"
        case .photoProcessingFailed:
            return "Failed to process photo"
        case .photoNotFound:
            return "Photo not found"
        case .dailyLimitReached:
            return "You've already shared today"
        case .groupLimitReached:
            return "Maximum 5 groups allowed"
        case .groupNotFound:
            return "Group not found"
        case .notGroupMember:
            return "You're not a member of this group"
        case .invalidGroupName:
            return "Please enter a valid group name"
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .verificationFailed:
            return "Verification failed. Please try again"
        case .sessionExpired:
            return "Session expired. Please sign in again"
        case .cameraPermissionDenied:
            return "Camera access is required to take photos"
        case .contactsPermissionDenied:
            return "Contacts access is required to invite friends"
        case .notificationPermissionDenied:
            return "Enable notifications to get photo alerts"
        case .insufficientStorage:
            return "Not enough storage space"
        case .cacheError:
            return "Failed to cache data"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .cameraPermissionDenied, .contactsPermissionDenied, .notificationPermissionDenied:
            return "Go to Settings to enable permissions"
        case .sessionExpired:
            return "Tap to sign in again"
        case .insufficientStorage:
            return "Free up some space and try again"
        default:
            return nil
        }
    }
}
```

**Create: `implementation/ios/Dayly/Core/UI/ErrorView.swift`**
```swift
struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    
    private var displayError: DaylyError? {
        error as? DaylyError
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let suggestion = displayError?.recoverySuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                if let dismissAction = dismissAction {
                    Button("Dismiss") {
                        dismissAction()
                    }
                    .buttonStyle(.bordered)
                }
                
                if let retryAction = retryAction {
                    Button("Try Again") {
                        retryAction()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if shouldShowSettings {
                    Button("Open Settings") {
                        openSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
    
    private var iconName: String {
        switch displayError {
        case .networkUnavailable:
            return "wifi.slash"
        case .cameraPermissionDenied:
            return "camera.fill"
        case .contactsPermissionDenied:
            return "person.2.fill"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private var shouldShowSettings: Bool {
        switch displayError {
        case .cameraPermissionDenied, .contactsPermissionDenied, .notificationPermissionDenied:
            return true
        default:
            return false
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
```

### UI Polish & Animations

**Create: `implementation/ios/Dayly/Core/UI/Theme.swift`**
```swift
import SwiftUI

struct Theme {
    // Colors
    static let primaryGreen = Color(hex: "4CAF50")
    static let backgroundGray = Color(.systemGray6)
    static let cardBackground = Color(.systemBackground)
    
    // Typography
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title = Font.system(size: 28, weight: .bold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    
    // Spacing
    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24
    
    // Corner radius
    static let smallRadius: CGFloat = 8
    static let mediumRadius: CGFloat = 12
    static let largeRadius: CGFloat = 20
    
    // Animation
    static let defaultAnimation = Animation.easeInOut(duration: 0.3)
    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)
}

// Custom modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(Theme.mediumRadius)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func shimmer() -> some View {
        self.overlay(
            GeometryReader { geometry in
                ShimmerView(width: geometry.size.width, height: geometry.size.height)
            }
        )
    }
}
```

### Loading States

**Create: `implementation/ios/Dayly/Core/UI/LoadingView.swift`**
```swift
struct LoadingView: View {
    let message: String?
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.9))
    }
}

struct ShimmerView: View {
    let width: CGFloat
    let height: CGFloat
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.1),
                Color.gray.opacity(0.3)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width * 2, height: height)
        .offset(x: shimmerOffset * width)
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }
}
```

### Haptic Feedback

**Create: `implementation/ios/Dayly/Core/Utils/HapticManager.swift`**
```swift
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        default:
            break
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
    }
    
    func selection() {
        selection.selectionChanged()
    }
}
```

### Block User Feature

**Create: `implementation/ios/Dayly/Features/Settings/BlockedUsersView.swift`**
```swift
struct BlockedUsersView: View {
    @StateObject private var viewModel = BlockedUsersViewModel()
    
    var body: some View {
        List {
            if viewModel.blockedUsers.isEmpty {
                Text("No blocked users")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.blockedUsers) { user in
                    BlockedUserRow(user: user) {
                        Task {
                            await viewModel.unblockUser(user)
                        }
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .task {
            await viewModel.loadBlockedUsers()
        }
    }
}
```

**Backend endpoint:**
```python
@router.post("/users/{user_id}/block")
async def block_user(
    user_id_to_block: str,
    current_user_id: str = Depends(get_current_user)
):
    """Block a user and remove from all shared groups"""
    # Add to blocked users table
    supabase_client.table("blocked_users").insert({
        "blocker_id": current_user_id,
        "blocked_id": user_id_to_block
    }).execute()
    
    # Remove from all shared groups
    # Get shared groups
    shared_groups = supabase_client.rpc(
        "get_shared_groups",
        {"user1": current_user_id, "user2": user_id_to_block}
    ).execute()
    
    # Remove blocked user from each group
    for group in shared_groups.data:
        supabase_client.table("group_members").update({
            "is_active": False
        }).eq("group_id", group["id"]).eq("user_id", user_id_to_block).execute()
    
    return {"success": True}
```

### Performance Optimization

**Create: `implementation/ios/Dayly/Core/Performance/ImageOptimizer.swift`**
```swift
import UIKit
import CoreImage

class ImageOptimizer {
    static let shared = ImageOptimizer()
    private let context = CIContext()
    
    func optimizeForUpload(_ image: UIImage) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            // Resize if needed
            let maxDimension: CGFloat = 2048
            let resized = self.resize(image, maxDimension: maxDimension)
            
            // Convert to JPEG with optimization
            var compression: CGFloat = 0.8
            var data = resized.jpegData(compressionQuality: compression)
            
            // Reduce quality if still too large
            while let currentData = data, currentData.count > 5 * 1024 * 1024 { // 5MB limit
                compression -= 0.1
                if compression < 0.3 {
                    break
                }
                data = resized.jpegData(compressionQuality: compression)
            }
            
            return data
        }.value
    }
    
    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        
        if ratio >= 1 {
            return image
        }
        
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
```

### Accessibility

**Update all views with accessibility labels:**
```swift
// Example for GroupCard
GroupCard(group: group)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(group.name) group")
    .accessibilityHint("Tap to take photo, long press to view photos")
    .accessibilityValue(group.hasSentToday ? "Photo sent today" : "No photo sent today")

// Camera capture button
Button(action: capturePhoto) {
    // ... button content
}
.accessibilityLabel("Capture photo")
.accessibilityHint("Double tap to take a photo")
```

### Analytics

**Create: `implementation/ios/Dayly/Core/Analytics/AnalyticsManager.swift`**
```swift
import Foundation

enum AnalyticsEvent {
    case appOpened
    case photoSent(groupId: UUID)
    case groupCreated
    case inviteSent(count: Int)
    case errorOccurred(error: Error)
    
    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .photoSent: return "photo_sent"
        case .groupCreated: return "group_created"
        case .inviteSent: return "invite_sent"
        case .errorOccurred: return "error_occurred"
        }
    }
    
    var parameters: [String: Any] {
        switch self {
        case .photoSent(let groupId):
            return ["group_id": groupId.uuidString]
        case .inviteSent(let count):
            return ["invite_count": count]
        case .errorOccurred(let error):
            return ["error": error.localizedDescription]
        default:
            return [:]
        }
    }
}

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    func track(_ event: AnalyticsEvent) {
        // Send to analytics service (e.g., Mixpanel, Amplitude)
        print("Analytics: \(event.name) - \(event.parameters)")
        
        // Also log to Sentry for error events
        if case .errorOccurred(let error) = event {
            // Sentry.capture(error)
        }
    }
}
```

### App Store Preparation

**Create: `implementation/ios/Dayly/Resources/PrivacyPolicy.md`**
```markdown
# Privacy Policy for Dayly

Last updated: [Date]

## Information We Collect
- Phone number (for authentication)
- First name (optional)
- Photos you choose to share
- Contact information (with your permission)

## How We Use Your Information
- To authenticate your account
- To share photos with your chosen groups
- To send notifications about new photos
- To connect you with friends

## Data Storage
- Photos are automatically deleted after 48 hours
- We use encryption for all data transmission
- Your data is stored securely on Supabase

## Your Rights
- You can delete your account at any time
- You can block users
- You can leave groups
- You can disable notifications

## Contact
For questions: privacy@dailyapp.com
```

**Update Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>Dayly needs camera access to let you share photos with your groups.</string>

<key>NSContactsUsageDescription</key>
<string>Dayly needs contacts access to help you invite friends to your groups.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Dayly needs photo library access to save photos you want to keep.</string>
```

### App Icon and Launch Screen

Create app icon assets:
- 1024x1024 for App Store
- All required sizes for iOS

Launch screen:
- Simple, clean design
- App icon centered
- White background

## Testing Checklist

1. **Error Handling:**
   - [ ] Network errors show appropriate UI
   - [ ] Permission denials handled gracefully
   - [ ] Server errors don't crash app

2. **Performance:**
   - [ ] App launches in < 2 seconds
   - [ ] Photos load smoothly
   - [ ] No memory leaks
   - [ ] Battery usage optimized

3. **Edge Cases:**
   - [ ] Works on all iPhone sizes
   - [ ] Handles timezone changes
   - [ ] Works with VoiceOver
   - [ ] Supports Dynamic Type

4. **App Store:**
   - [ ] Screenshots for all device sizes
   - [ ] App Store description ready
   - [ ] Privacy policy URL working
   - [ ] TestFlight beta tested

## Success Criteria
- [ ] All errors handled with user-friendly messages
- [ ] Loading states for all async operations
- [ ] Haptic feedback for key interactions
- [ ] Accessibility labels throughout
- [ ] Block user feature working
- [ ] Performance optimized (60fps scrolling)
- [ ] Analytics tracking key events
- [ ] App Store assets ready
- [ ] Privacy policy and terms published
- [ ] Beta tested with 20+ users

## Deployment Checklist

### Backend:
1. Set production environment variables
2. Enable Supabase production mode
3. Configure Twilio production account
4. Set up monitoring (Sentry)
5. Deploy to DigitalOcean App Platform

### iOS:
1. Generate production certificates
2. Configure push notification certificates
3. Submit to App Store Connect
4. Set up TestFlight
5. Submit for App Store review

Congratulations! The Dayly app is now complete and ready for launch! 🎉

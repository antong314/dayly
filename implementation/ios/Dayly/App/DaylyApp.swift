import SwiftUI
import UIKit
import UserNotifications

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Set up notifications
        Task {
            await NotificationService.shared.registerForPushNotifications()
        }
        
        // Check if launched from notification
        if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
            handleLaunchNotification(notification)
        }
        
        return true
    }
    
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
    
    // MARK: - Push Notifications
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device token: \(token)")
        
        // Register with backend
        Task {
            do {
                try await NetworkService.shared.registerDeviceToken(token)
                print("✅ Device token registered with backend")
            } catch {
                print("❌ Failed to register device token: \(error)")
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for notifications: \(error)")
        
        // In simulator, this is expected
        #if targetEnvironment(simulator)
        print("ℹ️ Push notifications are not supported in the simulator")
        #endif
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 Received remote notification: \(userInfo)")
        
        // Handle notification data
        if let groupId = userInfo["group_id"] as? String,
           let type = userInfo["type"] as? String,
           type == "new_photos" {
            // Trigger sync for this group
            Task {
                if let uuid = UUID(uuidString: groupId) {
                    await SyncManager.shared.syncGroup(uuid)
                }
                completionHandler(.newData)
            }
        } else {
            completionHandler(.noData)
        }
    }
    
    private func handleLaunchNotification(_ userInfo: [String: Any]) {
        if let groupId = userInfo["group_id"] as? String,
           let uuid = UUID(uuidString: groupId) {
            // Store for handling after app launches
            NotificationService.shared.pendingGroupId = uuid
        }
    }
}

// MARK: - Main App

@main
struct DaylyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let coreDataStack = CoreDataStack.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var selectedGroupId: UUID?
    @State private var showPhotoViewer = false
    
    init() {
        // Initialize Core Data
        _ = CoreDataStack.shared
        
        // Perform migrations if needed
        MigrationManager.performMigrationsIfNeeded()
        
        // Setup app lifecycle observers
        setupAppLifecycle()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
                .environmentObject(syncManager)
                .environmentObject(notificationService)
                .onAppear {
                    Task {
                        await syncManager.syncOnAppLaunch()
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openGroupPhotos)) { notification in
                    if let groupId = notification.userInfo?["groupId"] as? UUID {
                        // Handle deep link to group photos
                        selectedGroupId = groupId
                        showPhotoViewer = true
                    }
                }
                .onReceive(notificationService.pendingGroupIdPublisher) { groupId in
                    // Handle pending notification on app launch
                    if let groupId = groupId {
                        selectedGroupId = groupId
                        showPhotoViewer = true
                        // Clear the pending group ID
                        Task { @MainActor in
                            notificationService.pendingGroupId = nil
                        }
                    }
                }
                .fullScreenCover(isPresented: $showPhotoViewer) {
                    if let groupId = selectedGroupId {
                        // Find group name from the groups list
                        // For now, we'll use a placeholder
                        PhotoViewerView(groupId: groupId, groupName: "Group")
                            .onDisappear {
                                selectedGroupId = nil
                                showPhotoViewer = false
                                // Clear badge when viewing photos
                                notificationService.clearBadge()
                            }
                    }
                }
        }
    }
    
    private func setupAppLifecycle() {
        // Handle app termination
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            do {
                try coreDataStack.save()
            } catch {
                print("Failed to save Core Data on termination: \(error)")
            }
        }
        
        // Handle app entering background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            do {
                try coreDataStack.save()
            } catch {
                print("Failed to save Core Data on background: \(error)")
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle invite links: dayly://invite?code=ABC123
        if url.scheme == "dayly" && url.host == "invite",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            
            // Check if authenticated
            if UserDefaults.standard.bool(forKey: "isAuthenticated") {
                // Redeem immediately
                Task {
                    await redeemInvite(code: code)
                }
            } else {
                // Save for after onboarding
                UserDefaults.standard.set(url.absoluteString, forKey: "pendingInviteURL")
            }
        }
    }
    
    private func redeemInvite(code: String) async {
        do {
            struct RedeemResponse: Decodable {
                let group_id: String
                let group_name: String
            }
            
            let response: RedeemResponse = try await NetworkService.shared.request(
                endpoint: "/api/invites/redeem/\(code)",
                method: .post,
                responseType: RedeemResponse.self
            )
            
            print("✅ Joined group via invite: \(response.group_name)")
            
            // Refresh groups
            await syncManager.performSync()
            
        } catch {
            print("❌ Failed to redeem invite: \(error)")
        }
    }
}

// Main app view that shows groups or authentication
struct ContentView: View {
    @EnvironmentObject var syncManager: SyncManager
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("authToken") private var authToken: String?
    
    var body: some View {
        if isAuthenticated && authToken != nil {
            GroupsListView()
                .environmentObject(syncManager)
                .onAppear {
                    // Set auth token for network service
                    if let token = authToken {
                        NetworkService.shared.setAuthToken(token)
                    }
                }
        } else {
            // Show authentication view
            OnboardingView()
                .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
                    // Refresh app state after onboarding
                    Task {
                        await syncManager.syncOnAppLaunch()
                    }
                }
        }
    }
}

// Temporary placeholder for authentication - will be replaced with proper auth UI
struct AuthPlaceholderView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("authToken") private var authToken: String?
    @State private var showingDevBypass = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("Dayly")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Share one photo per day\nwith those who matter")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("Phone authentication coming soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 50)
                
                // Temporary dev bypass button
                #if DEBUG
                Button(action: {
                    showingDevBypass = true
                }) {
                    Text("Developer Bypass")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                }
                .alert("Skip Authentication?", isPresented: $showingDevBypass) {
                    Button("Cancel", role: .cancel) { }
                    Button("Skip", role: .destructive) {
                        // Set mock authentication values
                        isAuthenticated = true
                        authToken = "dev-bypass-token"
                        UserDefaults.standard.set("test-user-id", forKey: "user_id")
                        UserDefaults.standard.set("Test User", forKey: "user_name")
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        
                        // Initialize network service with mock token
                        NetworkService.shared.setAuthToken("dev-bypass-token")
                    }
                } message: {
                    Text("This will bypass authentication for development testing. Use only in development.")
                }
                #endif
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SyncManager.shared)
    }
}

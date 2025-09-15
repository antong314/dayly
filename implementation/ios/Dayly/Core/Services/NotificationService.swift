import UserNotifications
import UIKit
import Combine

// MARK: - Notification Protocol

protocol NotificationServiceProtocol {
    func requestPermissions() async -> Bool
    func registerForPushNotifications() async
    func handleNotification(_ notification: UNNotification)
    func updateBadgeCount(_ count: Int)
    var pendingGroupId: UUID? { get }
    var pendingGroupIdPublisher: AnyPublisher<UUID?, Never> { get }
}

// MARK: - Notification Service

@MainActor
class NotificationService: NSObject, NotificationServiceProtocol, ObservableObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    @Published var pendingGroupId: UUID?
    
    var pendingGroupIdPublisher: AnyPublisher<UUID?, Never> {
        $pendingGroupId.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            if granted {
                print("✅ Notification permissions granted")
            } else {
                print("❌ Notification permissions denied")
            }
            
            return granted
        } catch {
            print("Error requesting notification permissions: \(error)")
            return false
        }
    }
    
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Registration
    
    func registerForPushNotifications() async {
        let status = await checkPermissionStatus()
        
        switch status {
        case .notDetermined:
            // Request permission first
            guard await requestPermissions() else { return }
        case .denied:
            print("Push notifications are denied")
            return
        case .authorized, .provisional, .ephemeral:
            // Can proceed
            break
        @unknown default:
            return
        }
        
        // Register for remote notifications
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Notification Handling
    
    func handleNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        print("📬 Handling notification: \(userInfo)")
        
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
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Notification Content
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        groupId: UUID,
        delay: TimeInterval = 1
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = groupId.uuidString // For grouping
        content.userInfo = ["group_id": groupId.uuidString]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Called when notification is received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        // You might want to check if user is already viewing the group
        let userInfo = notification.request.content.userInfo
        
        if let groupId = userInfo["group_id"] as? String,
           let uuid = UUID(uuidString: groupId),
           uuid == pendingGroupId {
            // User is already viewing this group, don't show banner
            completionHandler([.sound])
        } else {
            // Show full notification
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    // Called when user taps on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotification(response.notification)
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openGroupPhotos = Notification.Name("openGroupPhotos")
    static let refreshGroups = Notification.Name("refreshGroups")
}

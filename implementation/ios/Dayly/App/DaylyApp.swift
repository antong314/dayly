import SwiftUI
import UIKit

// MARK: - App Delegate

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

// MARK: - Main App

@main
struct DaylyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let coreDataStack = CoreDataStack.shared
    @StateObject private var syncManager = SyncManager.shared
    
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
                .onAppear {
                    Task {
                        await syncManager.syncOnAppLaunch()
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
            // Show authentication view (to be implemented in Phase 1 UI)
            AuthPlaceholderView()
        }
    }
}

// Temporary placeholder for authentication - will be replaced with proper auth UI
struct AuthPlaceholderView: View {
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

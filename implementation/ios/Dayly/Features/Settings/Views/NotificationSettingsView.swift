import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationSound") private var notificationSound = true
    @AppStorage("notificationBadges") private var notificationBadges = true
    
    @State private var showingPermissionAlert = false
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var groupNotificationSettings: [UUID: Bool] = [:]
    @Environment(\.dismiss) var dismiss
    
    // Sample groups - in real app, this would come from view model
    let groups: [GroupViewModel] = []
    
    var body: some View {
        NavigationView {
            Form {
                // Main notification toggle
                Section {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            handleNotificationToggle(newValue)
                        }
                } footer: {
                    Text("Get notified when friends share photos in your groups")
                }
                
                // Notification preferences
                if notificationsEnabled {
                    Section("Preferences") {
                        Toggle("Sounds", isOn: $notificationSound)
                        Toggle("Badge App Icon", isOn: $notificationBadges)
                    }
                    
                    // Per-group settings
                    if !groups.isEmpty {
                        Section {
                            ForEach(groups) { group in
                                GroupNotificationRow(
                                    group: group,
                                    isEnabled: groupNotificationSettings[group.id] ?? true
                                ) { enabled in
                                    groupNotificationSettings[group.id] = enabled
                                    saveGroupSettings()
                                }
                            }
                        } header: {
                            Text("Groups")
                        } footer: {
                            Text("Choose which groups can send you notifications")
                        }
                    }
                }
                
                // System settings link
                Section {
                    Button(action: openSystemSettings) {
                        HStack {
                            Label("System Notification Settings", systemImage: "gear")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await checkPermissionStatus()
                loadGroupSettings()
            }
            .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    openSystemSettings()
                }
                Button("Cancel", role: .cancel) { 
                    // Revert toggle
                    notificationsEnabled = false
                }
            } message: {
                Text("Please enable notifications in Settings to receive photo alerts from your groups.")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleNotificationToggle(_ enabled: Bool) {
        Task {
            if enabled {
                let granted = await NotificationService.shared.requestPermissions()
                
                if !granted {
                    await MainActor.run {
                        notificationsEnabled = false
                        
                        // Check if denied or not determined
                        if permissionStatus == .denied {
                            showingPermissionAlert = true
                        }
                    }
                } else {
                    // Register for remote notifications
                    await NotificationService.shared.registerForPushNotifications()
                }
            }
        }
    }
    
    private func checkPermissionStatus() async {
        let status = await NotificationService.shared.checkPermissionStatus()
        await MainActor.run {
            permissionStatus = status
            
            // Update toggle based on actual permission status
            switch status {
            case .authorized, .provisional:
                notificationsEnabled = true
            case .denied, .notDetermined:
                notificationsEnabled = false
            default:
                notificationsEnabled = false
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func loadGroupSettings() {
        // Load saved group notification preferences from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "groupNotificationSettings"),
           let settings = try? JSONDecoder().decode([String: Bool].self, from: data) {
            groupNotificationSettings = settings.compactMapKeys { UUID(uuidString: $0) }
        }
    }
    
    private func saveGroupSettings() {
        // Save group notification preferences to UserDefaults
        let stringKeyedSettings = groupNotificationSettings.reduce(into: [String: Bool]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        
        if let data = try? JSONEncoder().encode(stringKeyedSettings) {
            UserDefaults.standard.set(data, forKey: "groupNotificationSettings")
        }
    }
}

// MARK: - Group Notification Row

struct GroupNotificationRow: View {
    let group: GroupViewModel
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    @State private var localIsEnabled: Bool
    
    init(group: GroupViewModel, isEnabled: Bool, onToggle: @escaping (Bool) -> Void) {
        self.group = group
        self.isEnabled = isEnabled
        self.onToggle = onToggle
        self._localIsEnabled = State(initialValue: isEnabled)
    }
    
    var body: some View {
        Toggle(isOn: $localIsEnabled) {
            HStack {
                // Group icon
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(group.name.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.body)
                    Text("\(group.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: localIsEnabled) { newValue in
            onToggle(newValue)
        }
    }
}

// MARK: - Helper Extensions

extension Dictionary where Key == String, Value == Bool {
    func compactMapKeys<T>(_ transform: (Key) throws -> T?) rethrows -> [T: Value] {
        try self.reduce(into: [T: Value]()) { result, pair in
            if let newKey = try transform(pair.key) {
                result[newKey] = pair.value
            }
        }
    }
}

// MARK: - Preview

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
}

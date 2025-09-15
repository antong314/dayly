import SwiftUI

struct PermissionsView: View {
    let onRequestNotifications: () -> Void
    let onRequestContacts: () -> Void
    
    @State private var hasRequestedNotifications = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Enable Features")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Get the most out of Dayly")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            // Permission cards
            VStack(spacing: 20) {
                // Notifications
                PermissionCard(
                    icon: "bell.fill",
                    title: "Push Notifications",
                    description: "Get notified when friends share photos",
                    isEnabled: hasRequestedNotifications,
                    action: {
                        hasRequestedNotifications = true
                        onRequestNotifications()
                    }
                )
                
                // Contacts
                PermissionCard(
                    icon: "person.2.fill",
                    title: "Access Contacts",
                    description: "Easily invite friends from your contacts",
                    isEnabled: false,
                    action: onRequestContacts
                )
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Skip button
            Button(action: onRequestContacts) {
                Text("Continue")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            
            Text("You can always change these in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isEnabled ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Enable button
            if !isEnabled {
                Button(action: action) {
                    Text("Enable")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(20)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }
}

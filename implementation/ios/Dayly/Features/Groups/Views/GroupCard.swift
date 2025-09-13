import SwiftUI

struct GroupCard: View {
    let group: GroupViewModel
    let uploadProgress: Double?
    @State private var showMenu = false
    
    init(group: GroupViewModel, uploadProgress: Double? = nil) {
        self.group = group
        self.uploadProgress = uploadProgress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name and menu
            HStack {
                Text(group.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Menu {
                    Button {
                        // Handle settings
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        // Handle leave group
                    } label: {
                        Label("Leave Group", systemImage: "arrow.right.square")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
            
            // Member avatars
            HStack(spacing: -8) {
                ForEach(0..<min(5, group.memberAvatars.count), id: \.self) { index in
                    MemberBubble(name: group.memberAvatars[index])
                }
                
                if group.memberCount > 5 {
                    Text("+\(group.memberCount - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
            }
            
            // Upload progress or status line
            if let progress = uploadProgress, progress > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("Uploading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.accentColor)
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .scaleEffect(x: 1, y: 0.8)
                }
            } else {
                // Status line
                HStack(spacing: 4) {
                    if group.hasSentToday {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Sent")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if let lastPhotoTime = group.lastPhotoTime {
                        if group.hasSentToday {
                            Text("•")
                                .foregroundColor(.secondary)
                        }
                        Text(lastPhotoTime)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Long press hint
                    if !group.hasSentToday && uploadProgress == nil {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MemberBubble: View {
    let name: String
    
    private var initials: String {
        let components = name.components(separatedBy: " ")
        let firstInitial = components.first?.first?.uppercased() ?? ""
        let lastInitial = components.count > 1 ? components.last?.first?.uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
    
    private var backgroundColor: Color {
        // Generate a consistent color based on the name
        let hash = name.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.9)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)
            
            Text(initials)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct GroupCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            GroupCard(group: GroupViewModel(
                id: UUID(),
                name: "Family",
                memberCount: 8,
                memberAvatars: ["John", "Jane", "Bob", "Alice", "Charlie", "David", "Eve"],
                hasSentToday: true,
                lastPhotoTime: "2 hours ago"
            ))
            
            GroupCard(group: GroupViewModel(
                id: UUID(),
                name: "Close Friends",
                memberCount: 4,
                memberAvatars: ["Mike", "Sarah", "Tom", "Lisa"],
                hasSentToday: false,
                lastPhotoTime: "Yesterday"
            ))
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

import SwiftUI

struct InviteRedemptionView: View {
    let inviteCode: String
    let onRedeem: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            // Header
            VStack(spacing: 12) {
                Text("You have an invite!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Someone invited you to join their group")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Invite code display
            Text(inviteCode)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button(action: onRedeem) {
                    Text("Join Group")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                
                Button(action: onSkip) {
                    Text("Skip for Now")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
}

import SwiftUI

struct EmptyPhotosView: View {
    let groupName: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .padding()
            }
            
            Spacer()
            
            // Empty state content
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "photo.stack")
                        .font(.system(size: 45))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                // Title
                Text("No photos yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Message
                Text("Be the first to share a moment\nwith \(groupName) today")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                // Hint
                Text("Tap the group to take a photo")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct EmptyPhotosView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyPhotosView(groupName: "Family")
            .preferredColorScheme(.dark)
    }
}

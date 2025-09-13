import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage
    let groupName: String
    let onSend: () -> Void
    let onRetake: () -> Void
    
    @State private var timeRemaining = 3
    @State private var timerActive = true
    @State private var timer: Timer?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Full screen image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Dark gradient overlay for better text visibility
            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                
                Spacer()
                
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
            }
            .ignoresSafeArea()
            
            // Overlay controls
            VStack {
                // Auto-dismiss timer
                if timerActive {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(timeRemaining) / 3.0)
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: timeRemaining)
                            
                            Text("\(timeRemaining)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                    }
                } else {
                    // Manual close button when timer is stopped
                    HStack {
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // Group indicator
                    Text("Sending to")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(groupName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.bottom, 20)
                    
                    // Send button
                    Button(action: {
                        stopTimer()
                        onSend()
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Photo")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 40)
                    
                    // Retake button
                    Button(action: {
                        stopTimer()
                        onRetake()
                    }) {
                        Text("Retake")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                stopTimer()
                onSend()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerActive = false
    }
}

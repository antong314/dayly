import SwiftUI

struct DaylyLimitView: View {
    let groupName: String
    let onDismiss: () -> Void
    
    @State private var timeUntilMidnight = ""
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                }
                
                // Title
                Text("Already shared today")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Message
                VStack(spacing: 8) {
                    Text("You've already shared a photo with")
                    Text("**\(groupName)**")
                    Text("today")
                }
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                
                // Motivational message
                Text("See you tomorrow! 🌅")
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.top, 10)
                
                // Countdown
                VStack(spacing: 12) {
                    Text("Next photo in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(timeUntilMidnight)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .monospacedDigit()
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 30)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                
                Spacer()
                
                // Dismiss button
                Button(action: onDismiss) {
                    Text("OK")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            updateCountdown()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateCountdown()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCountdown() {
        let calendar = Calendar.current
        let now = Date()
        
        // Get tomorrow at midnight
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return }
        let tomorrowMidnight = calendar.startOfDay(for: tomorrow)
        
        // Calculate time difference
        let components = calendar.dateComponents([.hour, .minute, .second], from: now, to: tomorrowMidnight)
        
        if let hours = components.hour, 
           let minutes = components.minute, 
           let seconds = components.second {
            timeUntilMidnight = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

struct DaylyLimitView_Previews: PreviewProvider {
    static var previews: some View {
        DaylyLimitView(groupName: "Family") {
            print("Dismissed")
        }
    }
}

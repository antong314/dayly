import SwiftUI

struct PhoneVerificationView: View {
    @Binding var phoneNumber: String
    let onSendCode: () -> Void
    
    @State private var formattedPhone = ""
    @FocusState private var isPhoneFocused: Bool
    
    var isValidPhone: Bool {
        let digitsOnly = phoneNumber.filter { $0.isNumber }
        return digitsOnly.count == 10 // US phone numbers
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("What's your phone number?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("We'll send you a verification code via WhatsApp")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            // Phone input
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("🇺🇸 +1")
                        .font(.title2)
                    
                    TextField("(555) 123-4567", text: $formattedPhone)
                        .font(.title2)
                        .keyboardType(.phonePad)
                        .focused($isPhoneFocused)
                        .onChange(of: formattedPhone) { newValue in
                            formatPhoneNumber(newValue)
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Continue button
            Button(action: onSendCode) {
                Text("Send Code")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValidPhone ? Color.accentColor : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!isValidPhone)
            
            // Privacy note
            Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
            
            // Developer bypass button
            #if DEBUG
            Button(action: {
                // Skip directly to main app
                UserDefaults.standard.set(true, forKey: "isAuthenticated")
                UserDefaults.standard.set("dev-bypass-token", forKey: "authToken")
                UserDefaults.standard.set("test-user-id", forKey: "user_id")
                UserDefaults.standard.set("Test User", forKey: "user_name")
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                
                // Initialize network service with mock token
                NetworkService.shared.setAuthToken("dev-bypass-token")
                
                // Post completion notification
                NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
            }) {
                Text("Developer Bypass")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 20)
            #endif
        }
        .padding(.horizontal, 24)
        .onAppear {
            isPhoneFocused = true
        }
    }
    
    private func formatPhoneNumber(_ input: String) {
        // Remove all non-digits
        let digitsOnly = input.filter { $0.isNumber }
        phoneNumber = digitsOnly
        
        // Format for display
        var formatted = ""
        for (index, digit) in digitsOnly.enumerated() {
            if index == 0 {
                formatted += "("
            } else if index == 3 {
                formatted += ") "
            } else if index == 6 {
                formatted += "-"
            }
            formatted += String(digit)
            
            if index >= 9 { break } // Limit to 10 digits
        }
        
        formattedPhone = formatted
    }
}

import SwiftUI

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content
            VStack {
                switch coordinator.currentStep {
                case .welcome:
                    WelcomeView()
                        .environmentObject(coordinator)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                    
                case .phoneVerification:
                    PhoneVerificationView(
                        phoneNumber: $coordinator.phoneNumber,
                        onSendCode: {
                            Task {
                                await coordinator.sendVerificationCode()
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    
                case .codeVerification:
                    CodeVerificationView(
                        phoneNumber: coordinator.phoneNumber,
                        onVerifyCode: { code in
                            Task {
                                await coordinator.verifyCode(code)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    
                case .nameEntry:
                    NameEntryView(
                        firstName: $coordinator.firstName,
                        onContinue: {
                            coordinator.nextStep()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    
                case .inviteRedemption:
                    InviteRedemptionView(
                        inviteCode: coordinator.inviteCode ?? "",
                        onRedeem: {
                            Task {
                                await coordinator.redeemInvite()
                            }
                        },
                        onSkip: {
                            coordinator.nextStep()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    
                case .permissions:
                    PermissionsView(
                        onRequestNotifications: {
                            Task {
                                await coordinator.requestNotificationPermission()
                            }
                        },
                        onRequestContacts: {
                            Task {
                                await coordinator.requestContactPermission()
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    
                case .complete:
                    CompleteView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        .onAppear {
                            // Slight delay before dismissing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isAuthenticated = true
                                dismiss()
                            }
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: coordinator.currentStep)
            
            // Navigation controls
            if coordinator.currentStep != .welcome && coordinator.currentStep != .complete {
                VStack {
                    HStack {
                        Button(action: {
                            coordinator.previousStep()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding()
                        }
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
            
            // Loading overlay
            if coordinator.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .alert("Error", isPresented: .constant(coordinator.error != nil)) {
            Button("OK") {
                coordinator.error = nil
            }
        } message: {
            Text(coordinator.error?.localizedDescription ?? "An error occurred")
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
            isAuthenticated = true
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App icon
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            // App name and tagline
            VStack(spacing: 16) {
                Text("Dayly")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                Text("Share one photo per day\nwith those who matter")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Get started button
            Button(action: {
                coordinator.nextStep()
            }) {
                Text("Get Started")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}

import SwiftUI
import Foundation

// MARK: - Onboarding Step

enum OnboardingStep {
    case welcome
    case phoneVerification
    case codeVerification
    case nameEntry
    case inviteRedemption
    case permissions
    case complete
}

// MARK: - Onboarding Coordinator

@MainActor
class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var inviteCode: String?
    @Published var phoneNumber: String = ""
    @Published var firstName: String = ""
    @Published var verificationId: String?
    @Published var isLoading = false
    @Published var error: Error?
    
    // Dependencies
    private let authService = AuthManager.shared
    private let notificationService = NotificationService.shared
    
    init() {
        // Check if launched from invite link
        checkForInviteCode()
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .phoneVerification
        case .phoneVerification:
            currentStep = .codeVerification
        case .codeVerification:
            currentStep = firstName.isEmpty ? .nameEntry : (inviteCode != nil ? .inviteRedemption : .permissions)
        case .nameEntry:
            currentStep = inviteCode != nil ? .inviteRedemption : .permissions
        case .inviteRedemption:
            currentStep = .permissions
        case .permissions:
            currentStep = .complete
        case .complete:
            break
        }
    }
    
    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .phoneVerification:
            currentStep = .welcome
        case .codeVerification:
            currentStep = .phoneVerification
        case .nameEntry:
            currentStep = .codeVerification
        case .inviteRedemption:
            currentStep = firstName.isEmpty ? .nameEntry : .codeVerification
        case .permissions:
            currentStep = inviteCode != nil ? .inviteRedemption : .nameEntry
        case .complete:
            currentStep = .permissions
        }
    }
    
    // MARK: - Phone Verification
    
    func sendVerificationCode() async {
        isLoading = true
        error = nil
        
        do {
            let result = try await authService.sendVerificationCode(phoneNumber: phoneNumber)
            verificationId = result.message // Store the message as confirmation
            nextStep()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func verifyCode(_ code: String) async {
        isLoading = true
        error = nil
        
        do {
            let result = try await authService.verifyCode(
                phoneNumber: phoneNumber,
                code: code,
                firstName: firstName.isEmpty ? nil : firstName
            )
            
            // Auth token is stored automatically by AuthManager
            // Move to next step
            nextStep()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Invite Handling
    
    private func checkForInviteCode() {
        // Check if app was opened with invite code
        if let urlString = UserDefaults.standard.string(forKey: "pendingInviteURL"),
           let url = URL(string: urlString),
           let code = extractInviteCode(from: url) {
            inviteCode = code
            UserDefaults.standard.removeObject(forKey: "pendingInviteURL")
        }
    }
    
    private func extractInviteCode(from url: URL) -> String? {
        // Handle dayly://invite?code=ABC123
        guard url.scheme == "dayly",
              url.host == "invite",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }
    
    func redeemInvite() async {
        guard let code = inviteCode else { return }
        
        isLoading = true
        error = nil
        
        do {
            struct RedeemResponse: Decodable {
                let group_id: String
                let group_name: String
            }
            
            let response: RedeemResponse = try await NetworkService.shared.request(
                endpoint: "/api/invites/redeem/\(code)",
                method: .post,
                responseType: RedeemResponse.self
            )
            
            print("✅ Joined group: \(response.group_name)")
            
            // Clear invite code
            inviteCode = nil
            
            // Move to next step
            nextStep()
        } catch {
            self.error = error
            print("❌ Failed to redeem invite: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Permissions
    
    func requestNotificationPermission() async {
        let granted = await notificationService.requestPermissions()
        if granted {
            await notificationService.registerForPushNotifications()
        }
        // Always move to next step, even if denied
        nextStep()
    }
    
    func requestContactPermission() async {
        _ = await ContactService.shared.requestAccess()
        // Always complete onboarding, even if denied
        completeOnboarding()
    }
    
    // MARK: - Completion
    
    func completeOnboarding() {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Update app state
        currentStep = .complete
        
        // Post notification for app to handle
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}

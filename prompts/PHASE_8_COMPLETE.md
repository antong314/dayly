# Phase 8: Invites & Onboarding

## App Context
You are building "Dayly" - a minimalist photo-sharing app where users can share one photo per day with small groups of close friends/family. The app's philosophy is about meaningful, intentional sharing rather than endless content.

**Core Features:**
- One photo per day per group limit
- Small groups (max 12 people)
- Photos disappear after 48 hours
- No comments, likes, or social features
- Phone number authentication

## Technical Stack
- **iOS**: SwiftUI, minimum iOS 15.0
- **Backend**: Python 3.11+ with FastAPI
- **Database**: Supabase (PostgreSQL with auth, storage, realtime)
- **Storage**: Supabase Storage for photos
- **Deployment**: DigitalOcean App Platform

## Current Status
Phases 0-7 are complete with:
- All core features working
- Push notifications implemented
- Groups, camera, and photo viewing functional
- Ready for invite system

## Your Task: Phase 8 - Invites & Onboarding

Implement contact integration and SMS invite system with smooth onboarding for new users.

### iOS Contact Integration

**Create: `implementation/ios/Dayly/Core/Services/ContactService.swift`**
```swift
import Contacts
import UIKit

protocol ContactServiceProtocol {
    func requestAccess() async -> Bool
    func fetchContacts() async -> [Contact]
    func searchContacts(query: String) -> [Contact]
}

struct Contact: Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let hasApp: Bool
    
    var fullName: String {
        if lastName.isEmpty {
            return firstName
        }
        return "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

@MainActor
class ContactService: ContactServiceProtocol {
    private let contactStore = CNContactStore()
    private var contacts: [Contact] = []
    
    func requestAccess() async -> Bool {
        do {
            return try await contactStore.requestAccess(for: .contacts)
        } catch {
            print("Contact access error: \(error)")
            return false
        }
    }
    
    func fetchContacts() async -> [Contact] {
        guard await requestAccess() else { return [] }
        
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactIdentifierKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var fetchedContacts: [Contact] = []
        
        do {
            try contactStore.enumerateContacts(with: request) { cnContact, _ in
                // Get phone numbers
                for phoneNumber in cnContact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    let formattedNumber = self.formatPhoneNumber(number)
                    
                    if self.isValidPhoneNumber(formattedNumber) {
                        let contact = Contact(
                            id: cnContact.identifier + "_" + formattedNumber,
                            firstName: cnContact.givenName,
                            lastName: cnContact.familyName,
                            phoneNumber: formattedNumber,
                            hasApp: false // Will be checked with backend
                        )
                        fetchedContacts.append(contact)
                    }
                }
            }
            
            // Check which contacts have the app
            if !fetchedContacts.isEmpty {
                let phoneNumbers = fetchedContacts.map { $0.phoneNumber }
                let appUsers = try await checkUsersExist(phoneNumbers: phoneNumbers)
                
                // Update hasApp status
                fetchedContacts = fetchedContacts.map { contact in
                    var updatedContact = contact
                    if appUsers.contains(contact.phoneNumber) {
                        updatedContact = Contact(
                            id: contact.id,
                            firstName: contact.firstName,
                            lastName: contact.lastName,
                            phoneNumber: contact.phoneNumber,
                            hasApp: true
                        )
                    }
                    return updatedContact
                }
            }
            
            self.contacts = fetchedContacts.sorted { $0.fullName < $1.fullName }
            return self.contacts
            
        } catch {
            print("Error fetching contacts: \(error)")
            return []
        }
    }
    
    func searchContacts(query: String) -> [Contact] {
        guard !query.isEmpty else { return contacts }
        
        let lowercasedQuery = query.lowercased()
        return contacts.filter {
            $0.fullName.lowercased().contains(lowercasedQuery) ||
            $0.phoneNumber.contains(query)
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        // Remove all non-numeric characters
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Add country code if missing (assuming US for demo)
        if cleaned.count == 10 {
            return "+1" + cleaned
        } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
            return "+" + cleaned
        }
        
        return "+" + cleaned
    }
    
    private func isValidPhoneNumber(_ number: String) -> Bool {
        // Basic validation
        let pattern = "^\\+[1-9]\\d{1,14}$"
        return number.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func checkUsersExist(phoneNumbers: [String]) async throws -> Set<String> {
        let response = try await NetworkService.shared.checkUsersExist(phoneNumbers: phoneNumbers)
        return Set(response.existingUsers.map { $0.phoneNumber })
    }
}
```

### Enhanced Contact Picker

**Update: `implementation/ios/Dayly/Features/Groups/Views/ContactPickerView.swift`**
```swift
struct ContactPickerView: View {
    @Binding var selectedContacts: [Contact]
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var contactService = ContactService()
    @State private var contacts: [Contact] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showingPermissionDenied = false
    
    private var maxSelections: Int {
        11 // 12 minus the current user
    }
    
    private var groupedContacts: [(key: String, value: [Contact])] {
        let filtered = searchText.isEmpty ? contacts : contactService.searchContacts(query: searchText)
        
        // Group by hasApp status
        let hasApp = filtered.filter { $0.hasApp }
        let needsInvite = filtered.filter { !$0.hasApp }
        
        var groups: [(key: String, value: [Contact])] = []
        if !hasApp.isEmpty {
            groups.append(("Already on Dayly", hasApp))
        }
        if !needsInvite.isEmpty {
            groups.append(("Invite to Dayly", needsInvite))
        }
        
        return groups
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if contacts.isEmpty && !isLoading {
                    EmptyContactsView(showingPermissionDenied: showingPermissionDenied)
                } else {
                    List {
                        ForEach(groupedContacts, id: \.key) { section in
                            Section(header: Text(section.key)) {
                                ForEach(section.value) { contact in
                                    ContactRow(
                                        contact: contact,
                                        isSelected: selectedContacts.contains(contact),
                                        onTap: {
                                            toggleSelection(contact)
                                        }
                                    )
                                    .disabled(
                                        !selectedContacts.contains(contact) &&
                                        selectedContacts.count >= maxSelections
                                    )
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search contacts")
                }
                
                if isLoading {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Select Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(selectedContacts.isEmpty)
                }
            }
        }
        .task {
            await loadContacts()
        }
    }
    
    private func loadContacts() async {
        isLoading = true
        
        let hasAccess = await contactService.requestAccess()
        if hasAccess {
            contacts = await contactService.fetchContacts()
        } else {
            showingPermissionDenied = true
        }
        
        isLoading = false
    }
    
    private func toggleSelection(_ contact: Contact) {
        if let index = selectedContacts.firstIndex(of: contact) {
            selectedContacts.remove(at: index)
        } else if selectedContacts.count < maxSelections {
            selectedContacts.append(contact)
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(contact.phoneNumber)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if contact.hasApp {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

### Backend Invite System

**Update: `implementation/backend/app/api/invites.py`**
```python
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from app.core.supabase import supabase_client
from app.core.security import get_current_user
from app.services.sms_service import send_invite_sms
from app.models.schemas import CheckUsersRequest, SendInvitesRequest, InviteResponse
import secrets
import string
from datetime import datetime, timedelta

router = APIRouter()

def generate_invite_code():
    """Generate 6-character invite code"""
    return ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))

@router.post("/check-users")
async def check_users(
    data: CheckUsersRequest,
    user_id: str = Depends(get_current_user)
):
    """Check which phone numbers are existing users"""
    existing_users = []
    needs_invite = []
    
    for phone in data.phone_numbers:
        # Check if user exists via Supabase Auth
        # Using a Supabase Edge Function or RPC call
        result = supabase_client.rpc(
            "check_phone_exists", 
            {"phone_number": phone}
        ).execute()
        
        if result.data and result.data[0]["exists"]:
            # Get user details
            user_data = supabase_client.table("profiles").select(
                "id, first_name"
            ).eq("phone", phone).execute()
            
            if user_data.data:
                existing_users.append({
                    "phone_number": phone,
                    "user_id": user_data.data[0]["id"],
                    "first_name": user_data.data[0]["first_name"]
                })
        else:
            needs_invite.append(phone)
    
    return {
        "existing": existing_users,
        "needs_invite": needs_invite
    }

@router.post("/send")
async def send_invites(
    data: SendInvitesRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user)
):
    """Send invite SMS to non-users"""
    # Verify user is member of group
    membership = supabase_client.table("group_members").select("*").eq(
        "group_id", data.group_id
    ).eq("user_id", user_id).eq("is_active", True).execute()
    
    if not membership.data:
        raise HTTPException(status_code=403, detail="Not a member of this group")
    
    # Get group and sender info
    group = supabase_client.table("groups").select("name").eq(
        "id", data.group_id
    ).execute()
    
    sender = supabase_client.table("profiles").select("first_name").eq(
        "id", user_id
    ).execute()
    
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
    
    group_name = group.data[0]["name"]
    sender_name = sender.data[0]["first_name"] if sender.data else "Someone"
    
    sent_invites = []
    
    for phone in data.phone_numbers:
        # Check if already invited recently
        recent_invite = supabase_client.table("invites").select("*").eq(
            "phone_number", phone
        ).eq("group_id", data.group_id).gt(
            "created_at", 
            (datetime.now() - timedelta(days=1)).isoformat()
        ).execute()
        
        if recent_invite.data:
            continue  # Skip if already invited in last 24 hours
        
        # Generate unique invite code
        invite_code = generate_invite_code()
        
        # Store invite
        invite_result = supabase_client.table("invites").insert({
            "code": invite_code,
            "group_id": data.group_id,
            "phone_number": phone,
            "invited_by": user_id,
            "expires_at": (datetime.now() + timedelta(days=7)).isoformat()
        }).execute()
        
        if invite_result.data:
            # Queue SMS sending in background
            background_tasks.add_task(
                send_invite_sms_task,
                phone,
                sender_name,
                group_name,
                invite_code
            )
            
            sent_invites.append({
                "phone_number": phone,
                "invite_code": invite_code
            })
    
    # Add existing users directly to group
    for user_data in data.existing_users:
        # Check if already a member
        existing_member = supabase_client.table("group_members").select("*").eq(
            "group_id", data.group_id
        ).eq("user_id", user_data["user_id"]).execute()
        
        if not existing_member.data:
            # Add to group
            supabase_client.table("group_members").insert({
                "group_id": data.group_id,
                "user_id": user_data["user_id"]
            }).execute()
    
    return {
        "sent_invites": sent_invites,
        "added_members": len(data.existing_users)
    }

@router.post("/redeem")
async def redeem_invite(
    invite_code: str,
    user_id: str = Depends(get_current_user)
):
    """Redeem invite code to join group"""
    # Find valid invite
    invite = supabase_client.table("invites").select(
        """
        *,
        groups(name)
        """
    ).eq("code", invite_code.upper()).gt(
        "expires_at", datetime.now().isoformat()
    ).is_("used_at", "null").execute()
    
    if not invite.data:
        raise HTTPException(status_code=404, detail="Invalid or expired invite code")
    
    invite_data = invite.data[0]
    
    # Check if already a member
    existing_member = supabase_client.table("group_members").select("*").eq(
        "group_id", invite_data["group_id"]
    ).eq("user_id", user_id).execute()
    
    if existing_member.data:
        # Reactivate if inactive
        if not existing_member.data[0]["is_active"]:
            supabase_client.table("group_members").update({
                "is_active": True
            }).eq("group_id", invite_data["group_id"]).eq(
                "user_id", user_id
            ).execute()
        else:
            raise HTTPException(status_code=400, detail="Already a member of this group")
    else:
        # Add user to group
        supabase_client.table("group_members").insert({
            "group_id": invite_data["group_id"],
            "user_id": user_id
        }).execute()
    
    # Mark invite as used
    supabase_client.table("invites").update({
        "used_at": datetime.now().isoformat(),
        "used_by": user_id
    }).eq("code", invite_code.upper()).execute()
    
    return {
        "group_id": invite_data["group_id"],
        "group_name": invite_data["groups"]["name"]
    }

async def send_invite_sms_task(
    phone_number: str,
    sender_name: str,
    group_name: str,
    invite_code: str
):
    """Background task to send invite SMS"""
    app_store_link = "https://apps.apple.com/app/daily/id..."  # Replace with actual
    
    message = (
        f"{sender_name} invited you to share daily photos "
        f"with \"{group_name}\" on Dayly.\n\n"
        f"Download: {app_store_link}\n"
        f"Invite code: {invite_code}"
    )
    
    try:
        await send_invite_sms(phone_number, message)
    except Exception as e:
        print(f"Failed to send SMS to {phone_number}: {e}")
```

### SMS Service

**Create: `implementation/backend/app/services/sms_service.py`**
```python
from twilio.rest import Client
from app.core.config import settings

# Initialize Twilio client
twilio_client = None
if settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN:
    twilio_client = Client(
        settings.TWILIO_ACCOUNT_SID,
        settings.TWILIO_AUTH_TOKEN
    )

async def send_invite_sms(phone_number: str, message: str):
    """Send SMS via Twilio"""
    if not twilio_client:
        print(f"SMS to {phone_number}: {message}")
        return  # Skip in development
    
    try:
        message = twilio_client.messages.create(
            body=message,
            from_=settings.TWILIO_PHONE_NUMBER,
            to=phone_number
        )
        return message.sid
    except Exception as e:
        raise Exception(f"Failed to send SMS: {str(e)}")
```

### Onboarding Flow

**Create: `implementation/ios/Dayly/Features/Onboarding/OnboardingCoordinator.swift`**
```swift
class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var inviteCode: String?
    @Published var phoneNumber: String = ""
    @Published var firstName: String = ""
    
    enum OnboardingStep {
        case welcome
        case phoneVerification
        case codeVerification
        case nameEntry
        case inviteRedemption
        case permissions
        case complete
    }
    
    init() {
        // Check if launched from invite link
        checkForInviteCode()
    }
    
    private func checkForInviteCode() {
        // Check if app was opened with invite code
        if let url = UserDefaults.standard.url(forKey: "pendingInviteURL"),
           let code = extractInviteCode(from: url) {
            inviteCode = code
            UserDefaults.standard.removeObject(forKey: "pendingInviteURL")
        }
    }
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .phoneVerification
        case .phoneVerification:
            currentStep = .codeVerification
        case .codeVerification:
            currentStep = inviteCode != nil ? .inviteRedemption : .nameEntry
        case .nameEntry:
            currentStep = .permissions
        case .inviteRedemption:
            currentStep = .permissions
        case .permissions:
            currentStep = .complete
        case .complete:
            break
        }
    }
}
```

### Deep Link Handling

Update `DaylyApp.swift`:
```swift
@main
struct DaylyApp: App {
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle invite links: daily://invite?code=ABC123
        if url.host == "invite",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            
            if AuthService.shared.isAuthenticated {
                // Redeem immediately
                Task {
                    try? await InviteService.shared.redeemInvite(code: code)
                }
            } else {
                // Save for after onboarding
                UserDefaults.standard.set(url, forKey: "pendingInviteURL")
            }
        }
    }
}
```

## Testing

1. **Test Contact Access:**
   - Permission request shown
   - Contacts load correctly
   - Search works properly

2. **Test User Detection:**
   - Existing users marked correctly
   - Non-users shown in invite section

3. **Test Invite Flow:**
   - SMS sent successfully
   - Invite codes work
   - Can join group via code

4. **Test Deep Links:**
   - Invite links open app
   - Code pre-fills if not logged in
   - Auto-joins group if logged in

## Success Criteria
- [ ] Contact picker shows all phone contacts
- [ ] Can identify which contacts have the app
- [ ] Can send SMS invites to non-users
- [ ] Invite codes work and expire properly
- [ ] Deep links handle invite codes
- [ ] New users see proper onboarding
- [ ] Invited users auto-join correct group
- [ ] Rate limiting prevents invite spam
- [ ] Contact permissions handled gracefully

## Next Phase Preview
Phase 9 will add final polish, error handling, and edge cases throughout the app.

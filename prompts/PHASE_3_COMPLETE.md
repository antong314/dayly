# Phase 3: Groups Management

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
Phases 0, 1, and 2 are complete with:
- Authentication working (phone verification)
- Core Data models implemented
- Repository pattern for data access
- Sync manager for offline support
- Backend auth endpoints functional

## Your Task: Phase 3 - Groups Management

Implement the groups feature - creating, viewing, and managing groups.

### iOS Groups UI

**Create: `implementation/ios/Dayly/Features/Groups/Views/GroupsListView.swift`**
```swift
struct GroupsListView: View {
    @StateObject private var viewModel = GroupsViewModel()
    @State private var showCreateGroup = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.groups) { group in
                        GroupCard(group: group)
                            .onTapGesture {
                                // Open camera for this group
                            }
                            .onLongPressGesture {
                                // Show today's photos
                            }
                    }
                    
                    if viewModel.groups.count < 5 {
                        CreateGroupButton()
                            .onTapGesture {
                                showCreateGroup = true
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Dayly")
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView()
            }
        }
        .task {
            await viewModel.loadGroups()
        }
    }
}
```

**Create: `implementation/ios/Dayly/Features/Groups/Views/GroupCard.swift`**
Design implementation:
```
┌─────────────────────────────┐
│ Family              •••     │  <- Name + settings button
│ ⚪⚪⚪⚪⚪ +2 more     │  <- Member bubbles
│ ✅ Sent • 2 hours ago      │  <- Status + timestamp
└─────────────────────────────┘
```

```swift
struct GroupCard: View {
    let group: GroupViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.name)
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Settings") { }
                    Button("Leave Group", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis")
                }
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
                }
            }
            
            // Status
            HStack {
                if group.hasSentToday {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Sent")
                }
                if let lastPhotoTime = group.lastPhotoTime {
                    Text("• \(lastPhotoTime)")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
```

**Create: `implementation/ios/Dayly/Features/Groups/Views/CreateGroupView.swift`**
```swift
struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CreateGroupViewModel()
    @State private var groupName = ""
    @State private var showContactPicker = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Group name input
                VStack(alignment: .leading) {
                    Text("Group Name")
                        .font(.headline)
                    TextField("Family, Friends, etc.", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Add members
                VStack(alignment: .leading) {
                    Text("Add Members")
                        .font(.headline)
                    Button("Select from Contacts") {
                        showContactPicker = true
                    }
                    
                    // Show selected contacts
                    ForEach(viewModel.selectedContacts) { contact in
                        ContactRow(contact: contact)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Group")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Create") {
                    Task {
                        await viewModel.createGroup(name: groupName)
                        dismiss()
                    }
                }
                .disabled(groupName.isEmpty || viewModel.selectedContacts.isEmpty)
            )
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView(selectedContacts: $viewModel.selectedContacts)
            }
        }
    }
}
```

### View Models

**Create: `implementation/ios/Dayly/Features/Groups/ViewModels/GroupsViewModel.swift`**
```swift
@MainActor
class GroupsViewModel: ObservableObject {
    @Published var groups: [GroupViewModel] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let groupRepository: GroupRepositoryProtocol
    private let networkService: NetworkService
    
    init(
        groupRepository: GroupRepositoryProtocol = GroupRepository(),
        networkService: NetworkService = NetworkService.shared
    ) {
        self.groupRepository = groupRepository
        self.networkService = networkService
    }
    
    func loadGroups() async {
        isLoading = true
        do {
            // Fetch from repository (handles offline/online)
            groups = try await groupRepository.fetchGroups()
                .map { GroupViewModel(from: $0) }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    func deleteGroup(_ groupId: UUID) async throws {
        try await groupRepository.deleteGroup(groupId)
        await loadGroups()
    }
}

struct GroupViewModel: Identifiable {
    let id: UUID
    let name: String
    let memberCount: Int
    let memberAvatars: [String] // First names
    let hasSentToday: Bool
    let lastPhotoTime: String?
}
```

### Backend Groups API

**Update: `implementation/backend/app/api/groups.py`**
```python
from fastapi import APIRouter, Depends, HTTPException
from app.core.supabase import supabase_client
from app.core.security import get_current_user
from app.models.schemas import GroupCreate, GroupResponse, AddMembers
from datetime import datetime

router = APIRouter()

@router.get("/", response_model=list[GroupResponse])
async def get_groups(user_id: str = Depends(get_current_user)):
    """Get all groups for current user"""
    # Get groups with members
    groups_response = supabase_client.table("groups").select(
        """
        *,
        group_members!inner(
            user_id,
            profiles:user_id(first_name)
        )
        """
    ).execute()
    
    # Check daily sends
    today = datetime.now().date()
    daily_sends = supabase_client.table("daily_sends").select("group_id").eq(
        "user_id", user_id
    ).eq("sent_date", today).execute()
    
    sent_group_ids = {send["group_id"] for send in daily_sends.data}
    
    # Get last photo for each group
    groups_with_status = []
    for group in groups_response.data:
        # Get last photo
        last_photo = supabase_client.table("photos").select(
            "created_at, sender_id"
        ).eq("group_id", group["id"]).order(
            "created_at", desc=True
        ).limit(1).execute()
        
        groups_with_status.append({
            **group,
            "has_sent_today": group["id"] in sent_group_ids,
            "last_photo": last_photo.data[0] if last_photo.data else None,
            "member_count": len(group["group_members"])
        })
    
    return groups_with_status

@router.post("/")
async def create_group(
    data: GroupCreate,
    user_id: str = Depends(get_current_user)
):
    """Create new group and invite members"""
    # Check group limit (5 max)
    existing_groups = supabase_client.table("group_members").select(
        "group_id"
    ).eq("user_id", user_id).eq("is_active", True).execute()
    
    if len(existing_groups.data) >= 5:
        raise HTTPException(status_code=400, detail="Maximum 5 groups allowed")
    
    # Create group
    group = supabase_client.table("groups").insert({
        "name": data.name,
        "created_by": user_id
    }).execute()
    
    group_id = group.data[0]["id"]
    
    # Add creator as member
    supabase_client.table("group_members").insert({
        "group_id": group_id,
        "user_id": user_id
    }).execute()
    
    # Process member phone numbers
    # (Invite system will be implemented in Phase 8)
    
    return {"id": group_id, "name": data.name}

@router.put("/{group_id}")
async def update_group(
    group_id: str,
    name: str,
    user_id: str = Depends(get_current_user)
):
    """Update group name"""
    # Verify user is member
    membership = supabase_client.table("group_members").select("*").eq(
        "group_id", group_id
    ).eq("user_id", user_id).eq("is_active", True).execute()
    
    if not membership.data:
        raise HTTPException(status_code=403, detail="Not a member of this group")
    
    # Update group
    result = supabase_client.table("groups").update({
        "name": name
    }).eq("id", group_id).execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Group not found")
    
    return {"success": True}

@router.delete("/{group_id}")
async def leave_group(
    group_id: str,
    user_id: str = Depends(get_current_user)
):
    """Leave a group (soft delete membership)"""
    result = supabase_client.table("group_members").update({
        "is_active": False
    }).eq("group_id", group_id).eq("user_id", user_id).execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Membership not found")
    
    return {"success": True}
```

**Create: `implementation/backend/app/models/schemas.py`** (additions)
```python
class GroupCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    member_phone_numbers: list[str] = []
    
    @validator('name')
    def validate_name(cls, v):
        return v.strip()

class MemberResponse(BaseModel):
    id: str
    first_name: Optional[str]

class LastPhotoResponse(BaseModel):
    created_at: datetime
    sender_id: str

class GroupResponse(BaseModel):
    id: str
    name: str
    created_at: datetime
    member_count: int
    members: list[MemberResponse]
    has_sent_today: bool
    last_photo: Optional[LastPhotoResponse]
```

### Update Main App

Add groups router to `implementation/backend/app/main.py`:
```python
from app.api import auth, groups

# Include groups router
app.include_router(groups.router, prefix="/api/groups", tags=["Groups"])
```

### Contact Picker (Placeholder)

**Create: `implementation/ios/Dayly/Features/Groups/Views/ContactPickerView.swift`**
```swift
// Basic implementation - full contacts integration in Phase 8
struct ContactPickerView: View {
    @Binding var selectedContacts: [Contact]
    @Environment(\.dismiss) var dismiss
    
    // Mock contacts for now
    let mockContacts = [
        Contact(id: "1", firstName: "John", phoneNumber: "+1234567890"),
        Contact(id: "2", firstName: "Jane", phoneNumber: "+0987654321")
    ]
    
    var body: some View {
        NavigationView {
            List(mockContacts) { contact in
                ContactRow(contact: contact, isSelected: selectedContacts.contains(contact))
                    .onTapGesture {
                        if let index = selectedContacts.firstIndex(of: contact) {
                            selectedContacts.remove(at: index)
                        } else {
                            selectedContacts.append(contact)
                        }
                    }
            }
            .navigationTitle("Select Contacts")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}
```

## Testing

1. **Test Group Creation:**
   - Create group with name
   - Verify 5 group limit enforced
   - Check group appears in list

2. **Test Group Display:**
   - Groups show correct member count
   - "Sent today" status updates correctly
   - Last photo time displays

3. **Test Group Management:**
   - Update group name
   - Leave group (soft delete)
   - Groups sync between devices

## Success Criteria
- [ ] Can create groups with names (max 5 groups)
- [ ] Groups display in card format with member info
- [ ] Tap group card to open camera (navigation ready)
- [ ] Long press to view photos (navigation ready)
- [ ] Can rename groups
- [ ] Can leave groups
- [ ] Groups sync with backend
- [ ] Offline support via Core Data
- [ ] Empty state when no groups
- [ ] Loading states during network calls

## Next Phase Preview
Phase 4 will implement the camera capture system with the one-photo-per-day limit.

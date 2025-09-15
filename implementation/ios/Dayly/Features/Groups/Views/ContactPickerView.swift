import SwiftUI

struct ContactPickerView: View {
    @Binding var selectedContacts: [Contact]
    @Environment(\.dismiss) var dismiss
    
    @State private var contacts: [Contact] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showPermissionAlert = false
    @State private var selectedSet = Set<String>()
    
    private let contactService = ContactService.shared
    
    private var maxSelections: Int {
        11 // 12 minus the current user
    }
    
    private var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contactService.searchContacts(query: searchText)
    }
    
    private var groupedContacts: [(key: String, value: [Contact])] {
        let filtered = filteredContacts
        
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
                    EmptyContactsView(showingPermissionDenied: showPermissionAlert)
                } else {
                    VStack(spacing: 0) {
                        // Selected count header
                        if !selectedSet.isEmpty {
                            HStack {
                                Text("\(selectedSet.count) selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Clear All") {
                                    selectedSet.removeAll()
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                        }
                        
                        List {
                            ForEach(groupedContacts, id: \.key) { section in
                                Section(header: Text(section.key)) {
                                    ForEach(section.value) { contact in
                                        ContactRow(
                                            contact: contact,
                                            isSelected: selectedSet.contains(contact.id)
                                        ) {
                                            toggleSelection(contact)
                                        }
                                        .disabled(
                                            !selectedSet.contains(contact.id) &&
                                            selectedSet.count >= maxSelections
                                        )
                                    }
                                }
                            }
                        }
                        .searchable(text: $searchText, prompt: "Search contacts")
                    }
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
                    Button("Done (\(selectedSet.count))") {
                        // Convert selected IDs back to Contact objects
                        selectedContacts = contacts.filter { selectedSet.contains($0.id) }
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(selectedSet.isEmpty)
                }
            }
        }
        .onAppear {
            // Initialize selected set from existing contacts
            selectedSet = Set(selectedContacts.map { $0.id })
        }
        .task {
            await loadContacts()
        }
        .alert("Contacts Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable contact access to invite friends to your group.")
        }
    }
    
    private func loadContacts() async {
        isLoading = true
        
        let hasAccess = await contactService.requestAccess()
        print("🔐 Contact access granted: \(hasAccess)")
        
        if hasAccess {
            contacts = await contactService.fetchContacts()
            print("📱 Loaded \(contacts.count) contacts")
            
            if contacts.isEmpty {
                print("⚠️ No contacts loaded despite having permission")
            }
        } else {
            showPermissionAlert = true
        }
        
        isLoading = false
    }
    
    private func toggleSelection(_ contact: Contact) {
        if selectedSet.contains(contact.id) {
            selectedSet.remove(contact.id)
        } else if selectedSet.count < maxSelections {
            selectedSet.insert(contact.id)
        }
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    let contact: Contact
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
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

// MARK: - Empty Contacts View

struct EmptyContactsView: View {
    let showingPermissionDenied: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: showingPermissionDenied ? "person.crop.circle.badge.exclamationmark" : "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(showingPermissionDenied ? "Permission Denied" : "No Contacts")
                .font(.title2.weight(.semibold))
            
            Text(showingPermissionDenied ? 
                 "Please allow contact access in Settings to invite friends." :
                 "No contacts with phone numbers found.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if showingPermissionDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
    }
}

// MARK: - Preview

struct ContactPickerView_Previews: PreviewProvider {
    @State static var selectedContacts: [Contact] = []
    
    static var previews: some View {
        ContactPickerView(selectedContacts: $selectedContacts)
    }
}
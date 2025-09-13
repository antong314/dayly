import SwiftUI

// Basic implementation - full contacts integration in Phase 8
struct ContactPickerView: View {
    @Binding var selectedContacts: [Contact]
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    // Mock contacts for now - will be replaced with real contacts in Phase 8
    let mockContacts = [
        Contact(id: "1", firstName: "John", phoneNumber: "+1234567890"),
        Contact(id: "2", firstName: "Jane", phoneNumber: "+0987654321"),
        Contact(id: "3", firstName: "Bob", phoneNumber: "+1122334455"),
        Contact(id: "4", firstName: "Alice", phoneNumber: "+5544332211"),
        Contact(id: "5", firstName: "Charlie", phoneNumber: "+9988776655"),
        Contact(id: "6", firstName: "David", phoneNumber: "+1231231234"),
        Contact(id: "7", firstName: "Eve", phoneNumber: "+4564564567"),
        Contact(id: "8", firstName: "Frank", phoneNumber: "+7897897890"),
        Contact(id: "9", firstName: "Grace", phoneNumber: "+3213213210"),
        Contact(id: "10", firstName: "Henry", phoneNumber: "+6546546540")
    ]
    
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return mockContacts
        } else {
            return mockContacts.filter { contact in
                contact.firstName.localizedCaseInsensitiveContains(searchText) ||
                contact.phoneNumber.contains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Selected count header
                if !selectedContacts.isEmpty {
                    HStack {
                        Text("\(selectedContacts.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Clear All") {
                            selectedContacts.removeAll()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                
                List(filteredContacts) { contact in
                    ContactPickerRow(
                        contact: contact,
                        isSelected: selectedContacts.contains(contact),
                        onToggle: {
                            toggleContact(contact)
                        }
                    )
                }
                .searchable(text: $searchText, prompt: "Search contacts")
            }
            .navigationTitle("Select Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func toggleContact(_ contact: Contact) {
        if let index = selectedContacts.firstIndex(of: contact) {
            selectedContacts.remove(at: index)
        } else {
            // Check limit (11 members + creator = 12 total)
            if selectedContacts.count < 11 {
                selectedContacts.append(contact)
            }
        }
    }
}

struct ContactPickerRow: View {
    let contact: Contact
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(contact.firstName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading) {
                    Text(contact.firstName)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(contact.phoneNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContactPickerView_Previews: PreviewProvider {
    @State static var selectedContacts: [Contact] = []
    
    static var previews: some View {
        ContactPickerView(selectedContacts: $selectedContacts)
    }
}

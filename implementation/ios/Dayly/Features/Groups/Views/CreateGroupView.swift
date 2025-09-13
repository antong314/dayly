import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CreateGroupViewModel()
    @State private var groupName = ""
    @State private var showContactPicker = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Group name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.headline)
                    
                    TextField("Family, Friends, etc.", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                    
                    Text("\(groupName.count)/50")
                        .font(.caption)
                        .foregroundColor(groupName.count > 50 ? .red : .secondary)
                }
                .padding(.top)
                
                // Add members section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Members")
                        .font(.headline)
                    
                    Text("You can add up to 11 people to this group")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showContactPicker = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Select from Contacts")
                        }
                        .foregroundColor(.accentColor)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Show selected contacts
                    if !viewModel.selectedContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected (\(viewModel.selectedContacts.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(viewModel.selectedContacts) { contact in
                                ContactRow(contact: contact) {
                                    viewModel.removeContact(contact)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Error message
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            if await viewModel.createGroup(name: groupName.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             viewModel.selectedContacts.isEmpty || 
                             viewModel.isCreating)
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView(selectedContacts: $viewModel.selectedContacts)
            }
            .overlay {
                if viewModel.isCreating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Creating group...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 10)
                        }
                }
            }
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    let onRemove: () -> Void
    
    var body: some View {
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
                Text(contact.phoneNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// Contact model
struct Contact: Identifiable, Equatable {
    let id: String
    let firstName: String
    let phoneNumber: String
}

struct CreateGroupView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGroupView()
    }
}

import SwiftUI

struct NameEntryView: View {
    @Binding var firstName: String
    let onContinue: () -> Void
    
    @FocusState private var isNameFocused: Bool
    
    var isValidName: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("What's your name?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("This is how you'll appear to others")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("First Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("John", text: $firstName)
                    .font(.title2)
                    .textContentType(.givenName)
                    .focused($isNameFocused)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            // Continue button
            Button(action: onContinue) {
                Text("Continue")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValidName ? Color.accentColor : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!isValidName)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
        .onAppear {
            isNameFocused = true
        }
    }
}

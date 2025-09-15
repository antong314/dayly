import SwiftUI
import Combine

struct CodeVerificationView: View {
    let phoneNumber: String
    let onVerifyCode: (String) -> Void
    
    @State private var code = ""
    @State private var codeFields = ["", "", "", "", "", ""]
    @FocusState private var focusedField: Int?
    
    private let codeLength = 6
    
    var formattedPhone: String {
        // Format phone number for display
        let digits = phoneNumber.filter { $0.isNumber }
        guard digits.count == 10 else { return phoneNumber }
        
        let areaCode = String(digits.prefix(3))
        let firstPart = String(digits.dropFirst(3).prefix(3))
        let secondPart = String(digits.dropFirst(6))
        
        return "+1 (\(areaCode)) \(firstPart)-\(secondPart)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter verification code")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("We sent a code to \(formattedPhone)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            // Code input fields
            HStack(spacing: 12) {
                ForEach(0..<codeLength, id: \.self) { index in
                    CodeFieldView(
                        text: $codeFields[index],
                        isActive: focusedField == index,
                        onTextChange: { newValue in
                            handleCodeInput(at: index, value: newValue)
                        }
                    )
                    .focused($focusedField, equals: index)
                }
            }
            .padding(.top, 20)
            
            // Resend button
            Button(action: {
                // TODO: Implement resend
            }) {
                Text("Didn't receive code? Resend")
                    .font(.body)
                    .foregroundColor(.accentColor)
            }
            .padding(.top, 12)
            
            Spacer()
            
            // Verify button
            Button(action: {
                let fullCode = codeFields.joined()
                onVerifyCode(fullCode)
            }) {
                Text("Verify")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(code.count == codeLength ? Color.accentColor : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(code.count != codeLength)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
        .onAppear {
            focusedField = 0
        }
    }
    
    private func handleCodeInput(at index: Int, value: String) {
        // Handle paste
        if value.count > 1 {
            let pastedCode = value.filter { $0.isNumber }.prefix(codeLength)
            for (i, digit) in pastedCode.enumerated() {
                if i < codeLength {
                    codeFields[i] = String(digit)
                }
            }
            code = codeFields.joined()
            
            // Focus last filled field or verify if complete
            let filledCount = codeFields.filter { !$0.isEmpty }.count
            if filledCount == codeLength {
                focusedField = nil
                let fullCode = codeFields.joined()
                onVerifyCode(fullCode)
            } else if filledCount > 0 {
                focusedField = filledCount - 1
            }
            return
        }
        
        // Handle single digit input
        let filtered = value.filter { $0.isNumber }
        codeFields[index] = String(filtered.prefix(1))
        
        // Update full code
        code = codeFields.joined()
        
        // Move focus
        if !filtered.isEmpty && index < codeLength - 1 {
            focusedField = index + 1
        } else if filtered.isEmpty && index > 0 {
            focusedField = index - 1
        }
        
        // Auto-submit when complete
        if code.count == codeLength {
            focusedField = nil
            onVerifyCode(code)
        }
    }
}

// MARK: - Code Field View

struct CodeFieldView: View {
    @Binding var text: String
    let isActive: Bool
    let onTextChange: (String) -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            
            TextField("", text: $text)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .onChange(of: text) { newValue in
                    onTextChange(newValue)
                }
        }
        .frame(width: 50, height: 60)
    }
}

import Contacts
import UIKit

// MARK: - Contact Protocol

protocol ContactServiceProtocol {
    func requestAccess() async -> Bool
    func fetchContacts() async -> [Contact]
    func searchContacts(query: String) -> [Contact]
}

// MARK: - Contact Model

struct Contact: Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    var hasApp: Bool
    
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

// MARK: - Contact Service

@MainActor
class ContactService: ContactServiceProtocol {
    static let shared = ContactService()
    
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
        guard await requestAccess() else { 
            print("❌ Contact access not granted")
            return [] 
        }
        
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactIdentifierKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var fetchedContacts: [Contact] = []
        var totalContactsProcessed = 0
        var contactsWithPhones = 0
        var validContacts = 0
        
        do {
            try contactStore.enumerateContacts(with: request) { cnContact, _ in
                totalContactsProcessed += 1
                
                // Get phone numbers
                if !cnContact.phoneNumbers.isEmpty {
                    contactsWithPhones += 1
                }
                
                for phoneNumber in cnContact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    print("📱 Processing number: \(number)")
                    
                    if let formattedNumber = self.formatPhoneNumber(number) {
                        print("✅ Formatted to: \(formattedNumber)")
                        if self.isValidPhoneNumber(formattedNumber) {
                            validContacts += 1
                            let contact = Contact(
                                id: cnContact.identifier + "_" + formattedNumber,
                                firstName: cnContact.givenName,
                                lastName: cnContact.familyName,
                                phoneNumber: formattedNumber,
                                hasApp: false // Will be checked with backend
                            )
                            fetchedContacts.append(contact)
                        } else {
                            print("❌ Invalid phone number format: \(formattedNumber)")
                        }
                    } else {
                        print("❌ Could not format number: \(number)")
                    }
                }
            }
            
            print("📊 Contact fetch summary:")
            print("   Total contacts processed: \(totalContactsProcessed)")
            print("   Contacts with phone numbers: \(contactsWithPhones)")
            print("   Valid contacts added: \(validContacts)")
            
            // Check which contacts have the app
            // Skip this check if using dev bypass token
            let isDevMode = UserDefaults.standard.string(forKey: "authToken") == "dev-bypass-token"
            
            if !fetchedContacts.isEmpty && !isDevMode {
                do {
                    let phoneNumbers = fetchedContacts.map { $0.phoneNumber }
                    let appUsers = try await checkUsersExist(phoneNumbers: phoneNumbers)
                    
                    // Update hasApp status
                    fetchedContacts = fetchedContacts.map { contact in
                        var updatedContact = contact
                        updatedContact.hasApp = appUsers.contains(contact.phoneNumber)
                        return updatedContact
                    }
                } catch {
                    // If API call fails, show all contacts as not having the app
                    print("Warning: Could not check which contacts have app - \(error)")
                    // Continue with contacts showing hasApp = false
                }
            } else if isDevMode {
                print("📱 Dev mode: Skipping backend check for contacts")
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
    
    private func formatPhoneNumber(_ number: String) -> String? {
        // Remove all non-numeric characters
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle different formats
        if cleaned.isEmpty {
            return nil
        }
        
        // Add country code if missing (assuming US for demo)
        if cleaned.count == 10 {
            return "+1" + cleaned
        } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
            return "+" + cleaned
        } else if cleaned.count > 10 {
            // International number, ensure it has +
            return "+" + cleaned
        }
        
        // Too short
        return nil
    }
    
    private func isValidPhoneNumber(_ number: String) -> Bool {
        // Basic E.164 validation
        let pattern = "^\\+[1-9]\\d{1,14}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: number.utf16.count)
        return regex?.firstMatch(in: number, options: [], range: range) != nil
    }
    
    private func checkUsersExist(phoneNumbers: [String]) async throws -> Set<String> {
        struct CheckUsersRequest: Encodable {
            let phone_numbers: [String]
        }
        
        struct CheckUsersResponse: Decodable {
            struct ExistingUser: Decodable {
                let phone_number: String
                let user_id: String
                let first_name: String?
            }
            
            let existing: [ExistingUser]
            let needs_invite: [String]
        }
        
        let request = CheckUsersRequest(phone_numbers: phoneNumbers)
        let encoder = JSONEncoder()
        let body = try encoder.encode(request)
        
        let response: CheckUsersResponse = try await NetworkService.shared.request(
            endpoint: "/api/invites/check-users",
            method: .post,
            body: body,
            responseType: CheckUsersResponse.self
        )
        
        return Set(response.existing.map { $0.phone_number })
    }
}

// MARK: - Contact Errors

enum ContactError: LocalizedError {
    case permissionDenied
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Contact access denied. Please enable it in Settings."
        case .fetchFailed:
            return "Failed to load contacts. Please try again."
        }
    }
}

# Phase 1: Authentication System Implementation

## Your Mission
Implement the complete phone-based authentication system for the Dayly app using Supabase Auth and FastAPI.

## Context from Previous Phase
- ✅ Supabase project is set up with URL and keys in `.env`
- ✅ FastAPI project structure created at `/backend`
- ✅ iOS project created with Supabase SDK installed
- ✅ Database tables created with RLS policies

## Exact Deliverables

### Backend Files to Create:

1. **`backend/app/api/auth.py`**
   ```python
   # Implement these exact endpoints:
   POST /api/auth/request-verification
   POST /api/auth/verify
   POST /api/auth/refresh
   ```

2. **`backend/app/core/security.py`**
   ```python
   # Implement get_current_user dependency
   # JWT token validation using Supabase
   ```

3. **`backend/app/services/sms_service.py`**
   ```python
   # Twilio SMS integration (optional - Supabase handles this)
   ```

4. **`backend/app/models/schemas.py`**
   ```python
   # Pydantic models for:
   class PhoneVerification(BaseModel):
       phone_number: str
   
   class VerifyCode(BaseModel):
       phone_number: str
       code: str
       first_name: Optional[str] = None
   ```

### iOS Files to Create:

1. **`Dayly/Features/Authentication/Views/PhoneVerificationView.swift`**
   - Phone number input with country code picker
   - Automatic formatting as user types
   - "Send Code" button

2. **`Dayly/Features/Authentication/Views/CodeVerificationView.swift`**
   - 6-digit code input (6 separate boxes)
   - Auto-advance between digits
   - Auto-submit when complete
   - Resend code option

3. **`Dayly/Features/Authentication/Services/AuthenticationService.swift`**
   ```swift
   protocol AuthenticationServiceProtocol {
       func requestVerification(phoneNumber: String) async throws -> VerificationSession
       func confirmVerification(session: VerificationSession, code: String) async throws -> AuthToken
       func logout() async
       var isAuthenticated: Bool { get }
   }
   ```

4. **`Dayly/Core/Storage/KeychainManager.swift`**
   - Secure storage for auth tokens
   - Refresh token management

## Implementation Requirements

### Backend Specifics:
1. Use Supabase's built-in phone auth:
   ```python
   supabase_client.auth.sign_in_with_otp({"phone": phone_number})
   ```

2. Handle rate limiting (3 attempts per hour)

3. Create/update user profile after verification

4. Return consistent error messages

### iOS Specifics:
1. Phone input should:
   - Default to user's country code
   - Format in real-time (e.g., +1 (555) 123-4567)
   - Validate before sending

2. Code input should:
   - Show 6 boxes
   - Auto-focus next box
   - Allow paste from SMS
   - Clear all on error

3. Store tokens securely:
   ```swift
   KeychainManager.shared.store(token, for: .accessToken)
   ```

## Test Cases to Implement

1. **Happy Path**:
   - Enter valid phone → Receive SMS → Enter code → Success

2. **Error Cases**:
   - Invalid phone format
   - Wrong verification code
   - Expired code (after 60 seconds)
   - Rate limit exceeded

3. **Edge Cases**:
   - International phone numbers
   - Network timeout handling
   - Token refresh when expired

## Success Criteria Checklist
- [ ] Phone verification works end-to-end
- [ ] SMS arrives within 10 seconds (Twilio sandbox is fine)
- [ ] Tokens stored securely in iOS Keychain
- [ ] Profile created in database after first login
- [ ] API endpoints return proper status codes
- [ ] UI shows loading states during network calls
- [ ] Errors displayed clearly to user

## NOT in Scope for This Phase
- Social features (groups, contacts)
- Camera functionality  
- Photo upload
- Push notifications

## Questions You Should Answer
1. How do you handle users who change phone numbers?
2. What happens if SMS doesn't arrive?
3. How long should tokens remain valid?

## Handoff to Next Phase
Document in `context/phase_1_complete.md`:
- API endpoint URLs and expected responses
- Token structure and expiration times
- Any decisions or trade-offs made
- Issues encountered and solutions

---

Remember: Focus ONLY on authentication. Resist the urge to implement other features, even if they seem related. The modular approach means other phases will handle those concerns.

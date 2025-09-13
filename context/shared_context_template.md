# Dayly App - Shared Context Document

This document is updated after each phase completion to maintain continuity between different AI agents.

## Project Overview
- **App**: Dayly - One photo. Once a day. To the people who matter.
- **Tech Stack**: iOS (SwiftUI) + Python (FastAPI) + Supabase
- **Current Phase**: 1 of 10

## Environment Setup
```bash
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=xxxxx
SUPABASE_SERVICE_KEY=xxxxx

# Backend API
API_URL=http://localhost:8000  # Local
API_URL=https://daily-api.ondigitalocean.app  # Production
```

## Completed Phases

### ✅ Phase 0: Project Setup (Completed: Date)
**What Was Built:**
- iOS project at `/ios/Dayly`
- Backend at `/backend` with FastAPI structure
- Supabase project with initial schema

**Key Decisions:**
- Using Supabase phone auth instead of custom JWT
- Minimum iOS 15.0 for async/await support
- Python 3.11 for latest FastAPI features

**File Locations:**
```
/ios/Dayly/Dayly.xcodeproj
/backend/app/main.py
/backend/requirements.txt
/database/schema.sql
```

### ✅ Phase 1: Authentication (Completed: Date)
**What Was Built:**
- Phone verification flow working end-to-end
- Tokens stored in iOS Keychain
- User profiles created on first login

**API Endpoints:**
```
POST /api/auth/request-verification
  Body: { "phone_number": "+1234567890" }
  Response: { "message": "Code sent" }

POST /api/auth/verify
  Body: { "phone_number": "+1234567890", "code": "123456" }
  Response: { "access_token": "...", "refresh_token": "...", "user": {...} }
```

**Key Classes/Protocols:**
```swift
// iOS
AuthenticationService: AuthenticationServiceProtocol
KeychainManager.shared

// Backend
get_current_user() -> str  # Dependency for protected routes
```

**Integration Points for Next Phases:**
- All API calls need `Authorization: Bearer {token}` header
- User ID available via `get_current_user()` dependency
- Refresh token logic implemented in `AuthenticationService`

---

## Pending Phases

### ⏳ Phase 2: Data Layer & Local Storage
**Waiting On:** Phase 1 completion
**Key Interfaces Needed:** User ID from auth

### ⏳ Phase 3: Groups Management  
**Waiting On:** Phase 2 Core Data models
**Key Interfaces Needed:** Group data model, User repository

---

## Technical Decisions Log

### Why Supabase Auth?
- Built-in phone verification
- No need to manage sessions
- RLS policies work automatically

### Why DigitalOcean App Platform?
- Simple Python deployment
- Auto-scaling capabilities
- GitHub integration

### Why 5 Groups Maximum?
- Maintains intimacy
- Simplifies UI
- Reduces complexity

---

## Known Issues / Tech Debt

1. **SMS Delivery**: Using Twilio sandbox (10-second delay)
   - TODO: Production Twilio account before launch

2. **Token Refresh**: Currently manual
   - TODO: Implement auto-refresh interceptor

---

## Testing Accounts

For development:
- Test Phone 1: +1 555-0100 (code: 123456)
- Test Phone 2: +1 555-0101 (code: 123456)

---

## Questions for Future Phases

1. Should we pre-create common group names? ("Family", "Friends", etc.)
2. How to handle users in different timezones for "daily" limit?
3. Should deleted photos remain visible for full 48 hours?

---

Last Updated: [Date]
Updated By: [Phase X Agent]

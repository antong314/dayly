# Phase 1: Authentication System

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
Phase 0 is complete with:
- iOS project created at `implementation/ios/Dayly` with folder structure
- Backend FastAPI project at `implementation/backend` 
- Database schema deployed to Supabase
- Basic health check endpoints working

## Your Task: Phase 1 - Authentication System

Implement complete phone-based authentication using Supabase Auth.

### iOS Authentication Module

**Core Protocol to Implement:**
```swift
protocol AuthenticationServiceProtocol {
    func requestVerification(phoneNumber: String) async throws -> VerificationSession
    func confirmVerification(session: VerificationSession, code: String) async throws -> AuthToken
    func logout() async
    var isAuthenticated: Bool { get }
}

struct VerificationSession {
    let sessionId: String
    let phoneNumber: String
    let expiresAt: Date
}

struct AuthToken {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}
```

**Create These Files:**

1. **`implementation/ios/Dayly/Features/Authentication/Views/PhoneVerificationView.swift`**
   - Phone number input with country code picker
   - Real-time formatting as user types
   - Validate phone number format
   - "Send Code" button with loading state
   - Error message display

2. **`implementation/ios/Dayly/Features/Authentication/Views/CodeVerificationView.swift`**
   - 6 separate text fields for code digits
   - Auto-advance to next field on input
   - Auto-submit when all 6 digits entered
   - Paste support from SMS
   - "Resend Code" button (with cooldown timer)
   - Back button to change phone number

3. **`implementation/ios/Dayly/Features/Authentication/Services/AuthenticationService.swift`**
   - Implement AuthenticationServiceProtocol
   - Integrate with Supabase Swift SDK
   - Handle all error cases
   - Token refresh logic

4. **`implementation/ios/Dayly/Core/Storage/KeychainManager.swift`**
   - Secure storage for auth tokens
   - Methods: store, retrieve, delete
   - Handle keychain errors gracefully

### Backend Authentication with Supabase

**Create These Files:**

1. **`implementation/backend/app/api/auth.py`**
```python
from fastapi import APIRouter, HTTPException
from app.core.supabase import supabase_client
from app.models.schemas import PhoneVerification, VerifyCode

router = APIRouter()

@router.post("/request-verification")
async def request_verification(data: PhoneVerification):
    """Send OTP to phone number via Supabase Auth"""
    try:
        response = supabase_client.auth.sign_in_with_otp({
            "phone": data.phone_number
        })
        return {"message": "Verification code sent", "expires_in": 300}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/verify")
async def verify_code(data: VerifyCode):
    """Verify OTP and return session"""
    try:
        response = supabase_client.auth.verify_otp({
            "phone": data.phone_number,
            "token": data.code,
            "type": "sms"
        })
        
        # Create/update profile
        profile_data = {"first_name": data.first_name} if data.first_name else {}
        supabase_client.table("profiles").upsert({
            "id": response.user.id,
            **profile_data
        }).execute()
        
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "user": {
                "id": response.user.id,
                "phone": response.user.phone
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/refresh")
async def refresh_token(refresh_token: str):
    """Refresh access token using Supabase"""
    try:
        response = supabase_client.auth.refresh_session(refresh_token)
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token
        }
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
```

2. **`implementation/backend/app/core/supabase.py`**
```python
from supabase import create_client, Client
from app.core.config import settings

supabase_client: Client = None

def init_supabase():
    global supabase_client
    supabase_client = create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_KEY
    )
    return supabase_client

def get_supabase() -> Client:
    return supabase_client
```

3. **`implementation/backend/app/core/security.py`**
```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.supabase import get_supabase

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    supabase = Depends(get_supabase)
) -> str:
    """Validate JWT token and return user ID"""
    token = credentials.credentials
    
    try:
        # Verify token with Supabase
        user = supabase.auth.get_user(token)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token"
            )
        return user.user.id
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token"
        )
```

4. **`implementation/backend/app/models/schemas.py`**
```python
from pydantic import BaseModel, validator
from typing import Optional
import re

class PhoneVerification(BaseModel):
    phone_number: str
    
    @validator('phone_number')
    def validate_phone(cls, v):
        # Basic phone validation
        if not re.match(r'^\+[1-9]\d{1,14}$', v):
            raise ValueError('Invalid phone number format')
        return v

class VerifyCode(BaseModel):
    phone_number: str
    code: str
    first_name: Optional[str] = None
    
    @validator('code')
    def validate_code(cls, v):
        if not re.match(r'^\d{6}$', v):
            raise ValueError('Code must be 6 digits')
        return v
```

5. **`implementation/backend/app/core/config.py`**
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str
    SUPABASE_ANON_KEY: str
    
    # App
    ENVIRONMENT: str = "development"
    
    class Config:
        env_file = ".env"

settings = Settings()
```

### Update Main App

Update `implementation/backend/app/main.py` to include auth routes:
```python
from app.api import auth
from app.core.supabase import init_supabase

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_supabase()
    yield
    # Shutdown

app = FastAPI(title="Dayly API", version="1.0.0", lifespan=lifespan)

# Include auth router
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
```

### Supabase Configuration

In Supabase Dashboard:
1. Enable Phone Auth provider
2. Configure SMS template: "Your Dayly verification code is: {{.Code}}"
3. Set OTP expiry to 5 minutes

### Testing

1. **Test phone verification:**
```bash
curl -X POST http://localhost:8000/api/auth/request-verification \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890"}'
```

2. **Test code verification:**
```bash
curl -X POST http://localhost:8000/api/auth/verify \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890", "code": "123456"}'
```

## Success Criteria
- [ ] User can enter phone number and receive SMS code
- [ ] Code verification returns valid tokens
- [ ] Tokens are stored securely in iOS Keychain
- [ ] Profile is created in database after first login
- [ ] Token refresh works when access token expires
- [ ] All error cases show appropriate messages
- [ ] Loading states shown during network requests

## Next Phase Preview
Phase 2 will implement the local data layer using Core Data to cache groups and photos for offline access.

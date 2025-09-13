# Dayly Backend

## Phase 1: Authentication System

The authentication system is now implemented using Supabase Auth with phone number verification.

### Setup

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure Supabase:**
   - Create a Supabase project at https://supabase.com
   - In the Supabase Dashboard:
     - Enable Phone Auth provider
     - Configure SMS template: "Your Dayly verification code is: {{.Code}}"
     - Set OTP expiry to 5 minutes
   - Copy your project URL and keys

3. **Set up environment variables:**
   ```bash
   cp env.example .env
   # Edit .env with your Supabase credentials
   ```

4. **Run the database schema:**
   - Go to Supabase SQL Editor
   - Run the schema from `implementation/database/schema.sql`

### Running the Server

```bash
uvicorn app.main:app --reload
```

The server will start at http://localhost:8000

### Authentication Endpoints

#### 1. Request Verification Code
```bash
POST /api/auth/request-verification
Content-Type: application/json

{
  "phone_number": "+1234567890"
}
```

Response:
```json
{
  "message": "Verification code sent",
  "expires_in": 300
}
```

#### 2. Verify Code
```bash
POST /api/auth/verify
Content-Type: application/json

{
  "phone_number": "+1234567890",
  "code": "123456",
  "first_name": "John"  // Optional
}
```

Response:
```json
{
  "access_token": "...",
  "refresh_token": "...",
  "user": {
    "id": "uuid",
    "phone": "+1234567890"
  }
}
```

#### 3. Refresh Token
```bash
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "..."
}
```

### Testing

Run the test script to verify endpoints are working:

```bash
python test_auth.py
```

This will test:
- Server connectivity
- Endpoint availability
- Request/response formats
- Validation rules

### Using Protected Endpoints

Once you have an access token, use it in the Authorization header:

```bash
Authorization: Bearer <access_token>
```

Example with the get_current_user dependency:
```python
from app.core.security import get_current_user

@router.get("/protected")
async def protected_route(user_id: str = Depends(get_current_user)):
    return {"user_id": user_id}
```

### Troubleshooting

1. **"Server is not running" error:**
   - Make sure you started the server with `uvicorn app.main:app --reload`

2. **"Invalid phone number format" error:**
   - Phone numbers must include country code with + prefix (e.g., +1234567890)

3. **Supabase connection errors:**
   - Verify your SUPABASE_URL and keys in .env
   - Ensure your Supabase project has Phone Auth enabled

4. **"Code must be 6 digits" error:**
   - OTP codes are always 6 digits

### Next Steps

Phase 2 will implement the local data layer using Core Data for offline access.

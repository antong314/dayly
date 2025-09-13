# Phase 0: Project Setup & Infrastructure

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

## Your Task: Phase 0 - Project Setup

Create the foundational project structure and database schema.

### iOS Project Setup
Create a new iOS project at `implementation/ios/Dayly` with:

**Project Structure:**
```
Dayly/
├── App/
│   ├── DaylyApp.swift
│   └── Info.plist
├── Core/
│   ├── Network/
│   ├── Storage/
│   ├── Extensions/
│   └── Constants/
├── Features/
│   ├── Authentication/
│   ├── Groups/
│   ├── Camera/
│   └── Photos/
├── Resources/
│   └── Assets.xcassets
└── Tests/
```

**Configuration:**
- SwiftUI project
- Minimum iOS 15.0
- Add Supabase Swift SDK via Swift Package Manager
- Bundle identifier: com.yourcompany.dayly

### Backend Project Setup
Create a FastAPI project at `implementation/backend` with:

**Project Structure:**
```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── groups.py
│   │   ├── photos.py
│   │   └── invites.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── security.py
│   │   └── supabase.py
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py
│   └── services/
│       ├── __init__.py
│       ├── sms_service.py
│       └── storage_service.py
├── tests/
│   └── __init__.py
├── requirements.txt
├── .env.example
└── Dockerfile
```

**Main App (app/main.py):**
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Dayly API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Dayly API", "status": "healthy"}

@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0"}
```

**Requirements.txt:**
```
fastapi==0.104.1
uvicorn[standard]==0.24.0
supabase==2.0.2
pydantic==2.5.0
python-dotenv==1.0.0
python-jose[cryptography]==3.3.0
twilio==8.10.1
httpx==0.25.2
```

**.env.example:**
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_KEY=your_service_key
ENVIRONMENT=development
```

### Database Schema
Create `implementation/database/schema.sql` with:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User profiles (extends Supabase auth.users)
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    first_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active TIMESTAMP
);

-- Groups table
CREATE TABLE groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Group members
CREATE TABLE group_members (
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (group_id, user_id)
);

-- Photos table with automatic expiration
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id),
    storage_path VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '48 hours')
);

-- Track daily sends
CREATE TABLE daily_sends (
    user_id UUID REFERENCES auth.users(id),
    group_id UUID REFERENCES groups(id),
    sent_date DATE DEFAULT CURRENT_DATE,
    PRIMARY KEY (user_id, group_id, sent_date)
);

-- Invites
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(6) UNIQUE NOT NULL,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    invited_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    used_by UUID REFERENCES auth.users(id)
);

-- Push notification tokens
CREATE TABLE user_devices (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) DEFAULT 'ios',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, device_token)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_sends ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can view groups they belong to"
    ON groups FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = groups.id
            AND group_members.user_id = auth.uid()
            AND group_members.is_active = true
        )
    );
```

### Deployment Configuration
Create `implementation/backend/Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

## Success Criteria
- [ ] iOS project builds and runs in Xcode
- [ ] Backend starts with `uvicorn app.main:app --reload`
- [ ] Health endpoint returns 200 OK at http://localhost:8000/api/health
- [ ] Database schema file is complete and ready to run in Supabase
- [ ] All project folders follow the specified structure

## Next Phase Preview
Phase 1 will implement phone authentication using the structure you create here.

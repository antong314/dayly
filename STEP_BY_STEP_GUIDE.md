# Dayly App - Step-by-Step Implementation Guide

## What You'll Do
Execute 10 phases sequentially, giving each phase to an AI coding agent (like Claude, Cursor, or GitHub Copilot).

## Preparation Steps

### 1. Create Your Workspace
```bash
cd /Users/antongorshkov/Documents/github-antong314/dayly
mkdir -p implementation/ios
mkdir -p implementation/backend
mkdir -p context/completed
```

### 2. Set Up Supabase (Manual Step)
1. Go to https://supabase.com
2. Create new project called "daily-app"
3. Save your credentials:
```bash
# Create .env file in implementation/backend/
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_KEY=your_service_key
```

## Phase-by-Phase Execution

### 📍 PHASE 0: Project Setup (Day 1)

**Step 1: Read the phase requirements**
```bash
# Open and read:
/Users/antongorshkov/Documents/github-antong314/dayly/Implementation_Plan.md
# Read lines 22-127 (Phase 0 section)
```

**Step 2: Create the agent prompt**
Create a new file: `prompts/phase_0_setup.md`
```markdown
You are setting up the foundation for the Dayly app - a photo sharing app where users share one photo per day with small groups.

## Your Task: Create Project Structure and Database Schema

Please create:

1. iOS SwiftUI project at `implementation/ios/Dayly`
   - Minimum iOS 15.0
   - Add Supabase Swift SDK via SPM
   - Create folder structure as specified

2. Python FastAPI backend at `implementation/backend`
   - Create the structure shown in Implementation_Plan.md lines 89-113
   - Create requirements.txt with dependencies from backend_requirements.txt
   - Set up basic FastAPI app with health check endpoint

3. Supabase database schema
   - Create file: `implementation/database/schema.sql`
   - Include all tables from Implementation_Plan.md lines 57-111
   - Include RLS policies

4. Basic deployment config
   - Create `implementation/backend/Dockerfile`
   - Create `implementation/backend/.env.example`

Use the exact specifications from the Implementation Plan Phase 0 section.
```

**Step 3: Give to AI agent**
- Copy the prompt content
- Paste into your AI coding assistant
- Let it create all the files

**Step 4: Verify**
Check that these exist:
- [ ] `implementation/ios/Dayly/Dayly.xcodeproj`
- [ ] `implementation/backend/app/main.py`
- [ ] `implementation/backend/requirements.txt`
- [ ] `implementation/database/schema.sql`

**Step 5: Run the schema in Supabase**
1. Go to Supabase SQL Editor
2. Copy contents of `schema.sql`
3. Run it

**Step 6: Document completion**
Create: `context/completed/phase_0.md`
```markdown
# Phase 0 Completed - [Date]

## What Was Built
- iOS project with Supabase SDK
- FastAPI backend structure  
- Database schema deployed

## Key Files
- iOS: implementation/ios/Dayly/
- Backend: implementation/backend/
- Schema: implementation/database/schema.sql

## Ready for Next Phase
- Supabase credentials in .env
- Basic project structure ready
- Database tables created
```

---

### 📍 PHASE 1: Authentication (Day 2-3)

**Step 1: Read requirements**
```bash
# Open Implementation_Plan.md
# Read lines 130-242 (Phase 1 section)
```

**Step 2: Create prompt with context**
Create: `prompts/phase_1_auth.md`
```markdown
You are implementing authentication for the Dayly app using the existing project structure.

## Context from Phase 0
- iOS project at: implementation/ios/Dayly
- Backend at: implementation/backend  
- Supabase configured with tables
- Database has profiles, groups, etc.

## Your Task: Implement Phone Authentication

### Backend (Python/FastAPI)
Create these files:

1. `implementation/backend/app/api/auth.py`
   - Copy the code from Implementation_Plan.md lines 169-227
   - Implement all three endpoints

2. `implementation/backend/app/core/security.py`
   - Create get_current_user dependency
   - JWT validation using Supabase

3. `implementation/backend/app/models/schemas.py`
   - PhoneVerification model
   - VerifyCode model
   - User response model

### iOS (SwiftUI)
Create these files:

1. `implementation/ios/Dayly/Features/Authentication/Views/PhoneVerificationView.swift`
   - Phone number input with formatting
   - Country code picker
   - Send code button

2. `implementation/ios/Dayly/Features/Authentication/Views/CodeVerificationView.swift`
   - 6 boxes for code input
   - Auto-advance between boxes
   - Resend option

3. `implementation/ios/Dayly/Features/Authentication/Services/AuthenticationService.swift`
   - Implement the protocol from lines 144-152
   - Keychain storage for tokens

### Testing
Include a simple test to verify phone auth works end-to-end.

Use Supabase phone auth - do not implement custom SMS.
```

**Step 3: Execute with AI**
Give prompt to your AI assistant

**Step 4: Test the authentication**
```bash
# Start backend
cd implementation/backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Test with curl
curl -X POST http://localhost:8000/api/auth/request-verification \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890"}'
```

**Step 5: Document**
Create: `context/completed/phase_1.md`

---

### 📍 PHASE 2-9: Continue Pattern

For each subsequent phase:

1. **Read** the phase section in Implementation_Plan.md
2. **Create** a focused prompt including:
   - Context from completed phases
   - Specific files to create
   - Exact requirements from plan
3. **Execute** with AI agent
4. **Test** the implementation
5. **Document** in context/completed/

---

## Quick Reference: What to Read for Each Phase

| Phase | Read Lines | Key Focus |
|-------|------------|-----------|
| 0 | 22-127 | Project setup, database |
| 1 | 130-242 | Authentication |
| 2 | 245-371 | Data models, Core Data |
| 3 | 374-522 | Groups management |
| 4 | 525-583 | Camera implementation |
| 5 | 586-743 | Photo upload system |
| 6 | 746-803 | Photo viewer UI |
| 7 | 806-926 | Push notifications |
| 8 | 929-1123 | Invites system |
| 9 | 1126-1209 | Polish & cleanup |

## Pro Tips

### ✅ DO:
1. **Test after each phase** - Don't move forward with broken code
2. **Update context** - Document what actually got built
3. **Use focused prompts** - One phase at a time
4. **Include error handling** - Ask AI to handle edge cases

### ❌ DON'T:
1. **Skip phases** - They build on each other
2. **Combine phases** - Keep them separate for clarity
3. **Forget testing** - Verify each phase works
4. **Rush** - Better to do it right than redo it

## Parallel Execution (Advanced)

Once comfortable, you can run some phases in parallel:

**Parallel Group 1:**
- Phase 0: Setup (Agent 1)
- Read app_concept.md thoroughly (You)

**Parallel Group 2:**  
- Phase 1: Backend Auth (Agent 1)
- Phase 2: iOS Data Layer (Agent 2)

**Parallel Group 3:**
- Phase 3: Groups API (Agent 1)  
- Phase 4: Camera UI (Agent 2)

## Success Checklist

After all phases:
- [ ] Can create account with phone
- [ ] Can create/join groups
- [ ] Can take and send photos
- [ ] Photos visible to group members
- [ ] Photos expire after 48 hours
- [ ] Push notifications work
- [ ] Can invite via SMS

## Troubleshooting

**Issue: Import errors**
- Run `pip install -r requirements.txt`
- Check PYTHONPATH includes project root

**Issue: Supabase connection fails**
- Verify .env has correct credentials
- Check Supabase project is running

**Issue: iOS won't build**
- Update Package dependencies in Xcode
- Clean build folder

## Next Steps After Completion

1. Deploy backend to DigitalOcean App Platform
2. Test with real phones (TestFlight)
3. Set up production Twilio account
4. Configure push notification certificates
5. Submit to App Store

---

Remember: Each phase should take 0.5-1 day with an AI assistant. Total project: 7-10 days of focused work.

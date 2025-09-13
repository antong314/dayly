# Dayly App - AI Agent Implementation Strategy

## Overview
This document outlines the optimal strategy for implementing the Dayly app using AI coding agents. The project is broken into 10 independent phases, each with its own focused prompt and deliverables.

## Key Principles

### 1. Phase Independence
Each phase should be implementable by a different agent without requiring deep knowledge of other phases. The interfaces between phases are clearly defined.

### 2. Context Preservation
Use a shared context document that gets updated after each phase with:
- What was built
- Key decisions made
- Interface definitions
- File locations

### 3. Incremental Verification
After each phase:
- Test the deliverables
- Update the context document
- Verify interfaces before moving forward

## Implementation Structure

```
dayly/
├── prompts/
│   ├── phase_0_setup.md
│   ├── phase_1_auth.md
│   ├── phase_2_data.md
│   ├── phase_3_groups.md
│   ├── phase_4_camera.md
│   ├── phase_5_upload.md
│   ├── phase_6_viewer.md
│   ├── phase_7_notifications.md
│   ├── phase_8_invites.md
│   └── phase_9_polish.md
├── context/
│   ├── shared_context.md      # Updated after each phase
│   ├── api_contracts.md       # API specifications
│   └── completed_phases.md    # Track what's done
└── implementation/
    ├── ios/                   # iOS project
    └── backend/              # Python/FastAPI project
```

## Phase Execution Strategy

### For Each Phase:

1. **Prepare the Prompt**
   - Include relevant context from previous phases
   - Specify exact deliverables
   - Define success criteria
   - Provide code interfaces to implement

2. **Agent Instructions Template**
   ```markdown
   You are implementing Phase X of the Dayly app. 
   
   Previous phases have completed:
   - [List completed items]
   
   Your specific tasks:
   - [Detailed task list]
   
   Interfaces to implement:
   - [Code interfaces]
   
   Deliverables:
   - [Specific files to create/modify]
   
   Testing requirements:
   - [How to verify success]
   ```

3. **Post-Phase Verification**
   - Run tests
   - Update shared context
   - Document any deviations
   - Prepare handoff for next phase

## Optimal Agent Assignment

### Backend Phases (Python/FastAPI Expert)
- Phase 0: Infrastructure setup
- Phase 1: Authentication (Supabase integration)
- Phase 3: Groups API
- Phase 5: Upload system
- Phase 7: Push notifications
- Phase 8: Invites system

### iOS Phases (SwiftUI/iOS Expert)
- Phase 2: Core Data models
- Phase 4: Camera implementation
- Phase 6: Photo viewer
- Phase 9: Polish and UI

### Parallel Execution
Some phases can run in parallel:
- Backend API (Phase 1) + iOS setup (Phase 0)
- Groups backend (Phase 3) + Camera UI (Phase 4)
- Upload backend (Phase 5) + Photo viewer UI (Phase 6)

## Sample Phase Prompt Structure

### Example: Phase 1 - Authentication System

```markdown
# Task: Implement Authentication System for Dayly App

## Context
You are building the authentication system for Dayly, a photo-sharing app. The app uses phone number verification via SMS.

## Previous Work Completed
- Supabase project created with credentials in .env
- Database schema implemented (see schema.sql)
- FastAPI project structure set up

## Your Implementation Tasks

### 1. Backend (Python/FastAPI)
Create the following files:

`app/api/auth.py`:
- POST /request-verification endpoint
- POST /verify endpoint  
- POST /refresh endpoint

`app/core/security.py`:
- get_current_user dependency
- Token validation

`app/services/sms_service.py`:
- Twilio integration for SMS

### 2. iOS (SwiftUI)
Create the following:

`Authentication/PhoneVerificationView.swift`:
- Phone input with country picker
- Auto-advance code input

`Authentication/AuthenticationService.swift`:
- Implement AuthenticationServiceProtocol
- Keychain storage for tokens

## Interfaces to Implement
[Include exact protocol/class definitions from plan]

## Success Criteria
- [ ] User can enter phone number and receive SMS
- [ ] 6-digit code verifies successfully
- [ ] Tokens stored securely in Keychain
- [ ] Protected endpoints require valid token

## Testing
1. Use Twilio test credentials
2. Verify SMS delivery
3. Test token refresh flow
4. Verify Keychain persistence
```

## Benefits of This Approach

1. **Focused Implementation**: Each agent works on a clearly defined scope
2. **Quality Control**: Easier to verify each phase works correctly
3. **Parallel Development**: Multiple agents can work simultaneously
4. **Easy Debugging**: Problems are isolated to specific phases
5. **Knowledge Transfer**: Clear documentation between phases
6. **Flexibility**: Can adjust plan based on discoveries in earlier phases

## Common Pitfalls to Avoid

1. **Don't Skip Context**: Always include relevant prior work
2. **Define Clear Interfaces**: Be explicit about function signatures
3. **Include Error Handling**: Specify expected error cases
4. **Test Incrementally**: Verify each phase before moving on
5. **Document Decisions**: Record why choices were made

## Recommended Workflow

1. Start with Phase 0 (Setup) - Critical foundation
2. Implement Phase 1 (Auth) - Test end-to-end
3. Build Phase 2 & 3 in parallel (Data + Groups)
4. Continue with remaining phases
5. Integration testing after Phase 6
6. Polish and optimization in final phases

This approach typically results in:
- Higher quality code
- Fewer integration issues
- Better documentation
- Easier maintenance
- More predictable timeline

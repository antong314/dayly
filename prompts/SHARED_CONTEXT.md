# Dayly App - Shared Context for All Phases

## What is Dayly?
Dayly is a minimalist photo-sharing app with a simple premise: share one photo per day with the people who matter. It's the antithesis of endless social media scrolling - intentional, meaningful, and ephemeral.

### Core Concepts:
- **One photo per day per group**: Makes each photo intentional
- **Small groups only**: Maximum 12 people for intimacy
- **48-hour expiration**: Photos disappear, keeping things light
- **No social features**: No likes, comments, or vanity metrics
- **Phone-based**: Simple SMS authentication, contact-based invites

### User Journey:
1. Download app → Verify phone number → Ready to use (30 seconds)
2. Create or join groups with close friends/family
3. Tap a group → Camera opens → Take photo → Auto-sends
4. Long-press group → See today's photos from members
5. Get one notification per day when group has new photos

## Technical Architecture

### Tech Stack:
- **iOS App**: SwiftUI, iOS 15.0+
- **Backend**: Python 3.11 with FastAPI
- **Database & Auth**: Supabase (PostgreSQL)
- **Storage**: Supabase Storage (photos)
- **SMS**: Twilio (via Supabase)
- **Deployment**: DigitalOcean App Platform

### Key Design Decisions:
1. **Supabase for Everything**: Leverages built-in auth, storage, realtime
2. **Phone Auth Only**: No usernames, emails, or passwords
3. **Ephemeral by Design**: 48-hour photo lifecycle built into database
4. **RLS for Security**: Row Level Security policies handle all access control
5. **Minimal Backend**: Thin API layer, most logic in database/client

### Project Structure:
```
implementation/
├── ios/Dayly/          # SwiftUI iOS app
├── backend/            # Python FastAPI
└── database/           # SQL schemas
```

## Implementation Phases Overview

1. **Phase 0**: Project setup, database schema
2. **Phase 1**: Phone authentication system
3. **Phase 2**: Local data layer (Core Data)
4. **Phase 3**: Groups management
5. **Phase 4**: Camera implementation
6. **Phase 5**: Photo upload system
7. **Phase 6**: Photo viewing experience
8. **Phase 7**: Push notifications
9. **Phase 8**: Invite system
10. **Phase 9**: Polish and edge cases

## API Design Patterns

All APIs follow RESTful conventions:
- Authentication via Bearer token
- JSON request/response bodies
- Standard HTTP status codes
- Consistent error format: `{"detail": "Error message"}`

## Database Design Patterns

- UUIDs for all IDs
- Automatic timestamps (created_at)
- Soft deletes where appropriate (is_active flags)
- Automatic expiration for photos
- RLS policies for all data access

## iOS Design Patterns

- MVVM architecture
- Async/await for all network calls
- SwiftUI + Combine
- Keychain for secure storage
- Repository pattern for data access

## Current Phase Context
- Phase 0-8 Complete ✅
- Full authentication system working
- Groups management with UI
- Camera capture with daily limits
- Photo upload with progress tracking
- Background uploads and retry logic
- Photo sync across devices
- Beautiful photo viewing with swipe navigation
- Push notifications with deep linking
- Contact integration and SMS invites
- Complete onboarding flow

---

Remember: Keep it simple. If a feature isn't explicitly required, don't build it. The beauty of Dayly is in what it doesn't do.

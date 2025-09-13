Architecture Overview
iOS App Components
Core Modules:

Authentication Module

Phone number verification via SMS
Token management (JWT)
Keychain storage for auth tokens
No user profile management needed


Groups Module

Local SQLite/Core Data for group metadata
Group membership sync
Invite link generation


Camera Module

AVFoundation for camera capture
Simple photo capture (no filters/editing)
HEIC to JPEG conversion for compatibility


Photo Sync Module

Upload queue with retry logic
Background upload support
Local cache management (48-hour cleanup)


Notification Handler

APNS registration
Notification grouping by daily batch
Deep linking to groups



Local Storage:

Core Data for: Groups, Members, Photo metadata
File system for: Cached photos (48 hours)
Keychain for: Auth tokens, encryption keys

Backend Architecture (Simple & Scalable)
Core Services Needed:

API Server (Node.js/Express or Go)

RESTful endpoints (keep it simple, no GraphQL)
Stateless design for easy scaling
JWT authentication


Database (PostgreSQL)

   Tables:
   - users (phone_number, id, created_at)
   - groups (id, name, created_at)
   - group_members (group_id, user_id, joined_at)
   - photos (id, group_id, sender_id, s3_key, created_at, expires_at)
   - daily_sends (user_id, group_id, date) - enforce one per day

Object Storage (S3 or DigitalOcean Spaces)

Store photos with unique keys
Set 48-hour lifecycle policy for auto-deletion
CDN for fast global delivery


SMS Service (Twilio)

Phone verification
Invite links via SMS


Push Notifications (APNS via provider)

Use service like Pusher Beams or OneSignal
Or direct APNS with Node.js



Simplified Infrastructure Stack
Option 1: DigitalOcean (Your Comfort Zone)

Droplet: $12/mo for API server (2GB RAM)
Managed PostgreSQL: $15/mo starter
Spaces: $5/mo (250GB storage + CDN)
Total: ~$32/mo starting cost

Option 2: Even Simpler with Firebase

Authentication: Phone auth built-in
Firestore: NoSQL database
Cloud Storage: For photos
Cloud Functions: For API logic
FCM: Push notifications
Total: Pay-as-you-go, likely free tier initially

API Endpoints (Minimal Set)
POST   /auth/verify-phone
POST   /auth/confirm-code

GET    /groups
POST   /groups
POST   /groups/:id/invite

POST   /photos/upload-url (returns signed S3 URL)
POST   /photos/confirm-upload
GET    /groups/:id/today-photos

POST   /devices/register-push-token
Implementation Plan (6-8 weeks)
Week 1-2: Foundation

Set up iOS project structure
Implement phone auth flow
Set up backend API + database
Deploy basic infrastructure

Week 3-4: Core Flow

Camera capture + preview
Photo upload to S3/Spaces
Group creation and management
Basic Core Data models

Week 5-6: Photo Viewing

Today's photos viewer
48-hour auto-cleanup
Push notifications
Dayly send limit enforcement

Week 7-8: Polish

Invite flow via SMS
Error handling/retry logic
Background uploads
App Store assets prep

Key Technical Decisions for Simplicity
Why These Choices:

Native iOS (Swift/SwiftUI)

No React Native complexity
Better camera performance
Simpler than maintaining cross-platform


RESTful API over GraphQL

Simpler to implement
Less client complexity
Easier caching


PostgreSQL over NoSQL

ACID compliance for group membership
Simple relational queries
One database for everything


S3/Spaces over custom storage

Automatic scaling
Built-in CDN
Lifecycle policies for cleanup


JWT over sessions

Stateless backend
Easy horizontal scaling
Simple implementation



Security Considerations (Keep Simple)

Photo Access

Generate signed URLs (5-minute expiry)
Photos accessible only to group members
No public URLs


Encryption

TLS for all API calls
Photos encrypted at rest in S3/Spaces
Optional: Client-side encryption (adds complexity)


Rate Limiting

Built into daily send limit
API rate limiting (100 requests/minute)
Prevent spam invites



Monitoring (Minimal)

Sentry for error tracking (free tier)
DigitalOcean metrics for server health
Simple analytics: Dayly active users, photos sent

Cost Projections
At Launch (100 users):

~$32/month infrastructure
~$10/month Twilio (SMS verifications)

At 10,000 users:

~$200/month (mainly storage + bandwidth)
Consider CDN optimization

Scaling Triggers:



5000 DAU: Add Redis cache




10000 DAU: Multiple API servers + load balancer




50000 DAU: Consider managed Kubernetes



What We're NOT Building

User authentication service (just phone + token)
Complex media pipeline (just store + serve)
Analytics dashboard (use free tiers)
Admin panel (direct DB queries when needed)
Microservices (monolithic API is fine)

This architecture prioritizes your goal of simplicity while being production-ready from day one. The entire backend could be 500-1000 lines of code, and the infrastructure can be set up in an afternoon.
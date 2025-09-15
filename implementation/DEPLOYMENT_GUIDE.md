# Dayly App - Deployment & Testing Guide

## Prerequisites

### 1. Apple Developer Account
- Required for running on physical device
- Sign up at: https://developer.apple.com ($99/year)
- Free account allows device testing but not TestFlight

### 2. Xcode Setup
1. Open Xcode
2. Sign in with Apple ID: Xcode → Settings → Accounts
3. Download iOS platform support if needed

### 3. Supabase Project
- Create project at: https://supabase.com
- Note your project URL and anon key

## Quick Start: Run on Your iPhone

### Step 1: Configure Backend

1. **Update Supabase credentials:**
```bash
cd ~/Documents/github-antong314/dayly/implementation/backend

# Create .env file
cat > .env << EOF
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
ENVIRONMENT=development
EOF
```

2. **Apply database migrations:**
```bash
cd ~/Documents/github-antong314/dayly/implementation/supabase

# Push all migrations to Supabase
supabase db push
```

3. **Start backend locally:**
```bash
cd ~/Documents/github-antong314/dayly/implementation/backend
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Step 2: Configure iOS App

1. **Create Xcode project:**
```bash
cd ~/Documents/github-antong314/dayly/implementation/ios

# Open in Xcode
open -a Xcode .
```

2. **In Xcode:**
   - File → New → Project
   - Choose: iOS → App
   - Product Name: Dayly
   - Team: Select your developer account
   - Organization Identifier: com.yourname
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: Yes
   - Include Tests: Yes

3. **Configure signing:**
   - Select project in navigator
   - Signing & Capabilities tab
   - Team: Your developer account
   - Bundle Identifier: com.yourname.dayly
   - Signing Certificate: Development

4. **Add capabilities:**
   - Click + Capability
   - Add: Push Notifications
   - Add: Background Modes
     - Check: Background fetch
     - Check: Remote notifications

5. **Copy source files:**
   - Delete default ContentView.swift
   - Drag all files from implementation/ios/Dayly/* into Xcode
   - Choose: Copy items if needed
   - Target: Dayly (checked)

6. **Update Info.plist:**
   - Already configured with all permissions
   - Verify all usage descriptions are present

7. **Configure API endpoint:**
```swift
// In NetworkService.swift, update baseURL:
// For local testing with your Mac's IP:
init(baseURL: String = "http://YOUR_MAC_IP:8000") {
    // Find your Mac's IP: System Settings → Network → Wi-Fi → Details
}
```

### Step 3: Run on Your iPhone

1. **Connect iPhone to Mac via USB**

2. **Trust computer on iPhone:**
   - Unlock iPhone
   - Tap "Trust" when prompted

3. **Select device in Xcode:**
   - Top bar: Select your iPhone from device list

4. **Build and run:**
   - Press ⌘R or click Play button
   - First run will take longer (provisioning)

5. **Trust developer on iPhone:**
   - Settings → General → VPN & Device Management
   - Developer App → Trust

## TestFlight Distribution

### Step 1: Prepare for Release

1. **Update build settings:**
   - Select project → Dayly target
   - Build Settings → Deployment
   - iOS Deployment Target: 15.0
   - Build Configuration: Release

2. **Archive app:**
   - Select: Any iOS Device (arm64)
   - Product → Archive
   - Wait for build to complete

3. **Upload to App Store Connect:**
   - In Organizer window
   - Distribute App → App Store Connect → Upload
   - Select options:
     - Include bitcode: No
     - Upload symbols: Yes

### Step 2: Configure TestFlight

1. **Go to App Store Connect:**
   - https://appstoreconnect.apple.com
   - My Apps → Dayly

2. **TestFlight tab:**
   - Wait for processing (10-30 min)
   - Build appears under "iOS Builds"

3. **Add test information:**
   - What to Test: "Daily photo sharing with groups"
   - Test Information → Save

4. **Create test group:**
   - Internal Testing → Create Group
   - Add testers (up to 100 internal)

5. **Add external testers:**
   - External Testing → Add Group
   - Public Link or Email invites
   - Up to 10,000 testers

### Step 3: Backend Deployment

For TestFlight, deploy backend to DigitalOcean:

1. **Create App Platform app:**
```bash
doctl apps create --spec implementation/backend/app.yaml
```

2. **Update iOS app to use production URL:**
```swift
init(baseURL: String = "https://dayly-api-xxxxx.ondigitalocean.app") {
```

3. **Configure environment variables in DigitalOcean:**
   - SUPABASE_URL
   - SUPABASE_KEY
   - SUPABASE_SERVICE_KEY
   - TWILIO_* (if using SMS)

## Testing Checklist

### Core Features
- [ ] Phone authentication (needs Twilio configured)
- [ ] Create group
- [ ] Take photo (one per day limit)
- [ ] View photos in group
- [ ] Photos expire after 48 hours
- [ ] Push notifications (needs APNS certificates)
- [ ] Invite contacts (needs Contacts permission)

### Test Accounts
Without Twilio configured, you'll need to:
1. Create test users directly in Supabase Auth
2. Use the Supabase dashboard to manage test data

### Debug Mode Features
The app includes debug helpers:
- Supabase Studio for data inspection
- Backend API docs at: http://localhost:8000/docs
- Xcode console for iOS logs

## Troubleshooting

### Common Issues

1. **"Unable to install" on device:**
   - Check provisioning profile
   - Ensure device is registered
   - Clean build folder (⇧⌘K)

2. **Network errors:**
   - Verify Mac and iPhone on same Wi-Fi
   - Check firewall settings
   - Use Mac's IP, not localhost

3. **Blank screen:**
   - Check Xcode console for errors
   - Verify Core Data model loaded
   - Check API connectivity

4. **Push notifications not working:**
   - Needs APNS certificates
   - Check device token registration
   - Verify notification permissions

### Quick Fixes

```bash
# Reset iOS Simulator
xcrun simctl erase all

# Clean Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData

# Restart backend
lsof -ti:8000 | xargs kill -9
uvicorn app.main:app --reload
```

## Next Steps

1. **Configure Twilio** for SMS authentication
2. **Set up APNS** for push notifications  
3. **Deploy backend** to DigitalOcean
4. **Submit to App Store** (requires screenshots, description, etc.)

---

For development, running locally with your iPhone connected via USB is fastest. For beta testing with others, use TestFlight!

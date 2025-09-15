# Create Xcode Project for Dayly - Manual Steps

Since the automated script isn't working with newer Xcode versions, here's how to create the project manually:

## Quick Steps (5 minutes)

### 1. Create New iOS App in Xcode
1. Open Xcode
2. File → New → Project
3. Choose "iOS" → "App" → Next
4. Configure:
   - Product Name: **Dayly**
   - Team: Your Apple ID (or "Add Account..." if needed)
   - Organization Identifier: **com.yourname** (replace with your name)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Use Core Data: **YES** ✅
   - Include Tests: **YES** ✅
5. Save to: `/Users/antongorshkov/Documents/github-antong314/dayly/implementation/ios/`
6. Create folder: **UNCHECK** (we already have the folder)

### 2. Delete Default Files
In Xcode, delete these files (Move to Trash):
- ContentView.swift
- Persistence.swift
- Dayly.xcdatamodeld (we'll replace with ours)

### 3. Add Our Files
1. In Xcode, right-click on "Dayly" folder → "Add Files to Dayly..."
2. Navigate to `/Users/antongorshkov/Documents/github-antong314/dayly/implementation/ios/Dayly/`
3. Select ALL folders (App, Core, Features, Models, Resources)
4. Options:
   - ✅ Copy items if needed: **UNCHECKED**
   - ✅ Create groups
   - ✅ Add to targets: Dayly
5. Click "Add"

### 4. Configure Info.plist
1. In Xcode navigator, find `Dayly/App/Info.plist`
2. Right-click → "Open As" → "Source Code"
3. It should already have the camera permissions configured

### 5. Add Dependencies
1. File → Add Package Dependencies...
2. Search for: `https://github.com/supabase-community/supabase-swift.git`
3. Dependency Rule: Up to Next Major Version: **1.0.0**
4. Add to Project: Dayly
5. Click "Add Package"
6. Choose products: **Supabase** → Add to Dayly target

### 6. Update Network Configuration
1. Open `Core/Network/NetworkService.swift`
2. Find line ~77: `init(baseURL: String = "http://localhost:8000")`
3. Change to your Mac's IP: `init(baseURL: String = "http://YOUR_MAC_IP:8000")`
   - Get your IP: Option+Click WiFi icon in menu bar

### 7. Build Settings
1. Click "Dayly" project in navigator
2. Select "Dayly" target
3. General tab:
   - Deployment Target: iOS 15.0
   - Device Orientation: Portrait only
4. Signing & Capabilities:
   - Team: Select your team
   - Bundle Identifier: Will auto-update

### 8. Run the App!
1. Connect your iPhone via USB
2. Select your iPhone from the device dropdown (top bar)
3. Press Play button (⌘R)
4. First time: On iPhone go to Settings → General → VPN & Device Management → Trust

## Troubleshooting

### "No such module 'Supabase'" error
- Make sure you added the package dependency (Step 5)
- Try: File → Packages → Resolve Package Versions

### Build errors with Core Data
- Make sure Dayly.xcdatamodeld is added to the target
- Clean build: Product → Clean Build Folder (⌘⇧K)

### Can't connect to backend
- Make sure backend is running: `uvicorn app.main:app --reload --host 0.0.0.0`
- Verify your Mac's IP is correct in NetworkService.swift
- Ensure iPhone and Mac are on same WiFi network

## Success! 🎉
Once running, you'll see:
- Welcome screen with phone authentication
- Camera interface
- Groups list
- Photo viewer

Note: Without backend services configured, some features will show as "coming soon".

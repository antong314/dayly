# Dayly App - Quick Start Guide 🚀

## Run on Your iPhone in 10 Minutes

### Prerequisites
- Mac with Xcode installed
- iPhone with USB cable
- Apple ID (free is OK for device testing)

### Step 1: Start the Backend (2 min)

```bash
# In Terminal:
cd ~/Documents/github-antong314/dayly/implementation/backend

# Install dependencies (first time only)
pip install -r requirements.txt

# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

✅ Backend is ready when you see: `Uvicorn running on http://0.0.0.0:8000`

### Step 2: Find Your Mac's IP Address (1 min)

1. **Option A:** Hold Option key → Click Wi-Fi icon → See IP address
2. **Option B:** System Settings → Network → Wi-Fi → Details → IP address

Example: `192.168.1.123`

### Step 3: Create iOS Project (3 min)

```bash
cd ~/Documents/github-antong314/dayly/implementation/ios

# Run the setup script
chmod +x create_xcode_project.sh
./create_xcode_project.sh
```

This script will:
- Create an Xcode project
- Copy all source files
- Set up Core Data model
- Configure Info.plist

### Step 4: Configure Xcode (2 min)

1. **Open project:** The script should open Xcode automatically

2. **Update API endpoint:**
   - Open `Core/Network/NetworkService.swift`
   - Change line 77:
   ```swift
   init(baseURL: String = "http://192.168.1.123:8000") {
   // Replace with YOUR Mac's IP address
   ```

3. **Select your team:**
   - Click on "Dayly" project in navigator
   - Signing & Capabilities tab
   - Team: Select your Apple ID
   - Bundle ID: Change to `com.YOURNAME.dayly`

### Step 5: Run on iPhone (2 min)

1. **Connect iPhone** via USB cable
2. **Unlock iPhone** and tap "Trust This Computer"
3. **Select your iPhone** from device dropdown (next to Play button)
4. **Press Play button** (⌘R)

First run will:
- Install provisioning profile
- Build the app
- Install on your device

5. **Trust the app on iPhone:**
   - Settings → General → VPN & Device Management
   - Developer App → [Your Name] → Trust

## 🎉 That's It! The App is Running!

### What Works Without Additional Setup

✅ **These features work immediately:**
- Create groups
- Browse groups interface
- Camera (take photos)
- Photo viewing UI
- Local data storage
- All UI/UX flows

❌ **These need configuration:**
- Phone authentication (needs Supabase + Twilio)
- Actual photo storage (needs Supabase Storage)
- Push notifications (needs APNS certificates)
- SMS invites (needs Twilio)

### Quick Test Flow

1. **Launch app** → See welcome screen
2. **Phone auth** → Won't work yet (shows error)
3. **For testing:** Tap around to see the UI

### Next: Enable Full Features

To get authentication and storage working:

1. **Create free Supabase project:**
   - Go to https://supabase.com
   - Create new project
   - Copy URL and anon key

2. **Update backend `.env`:**
```bash
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
```

3. **Apply database schema:**
```bash
cd implementation/supabase
supabase link --project-ref YOUR_PROJECT_ID
supabase db push
```

### TestFlight (For Beta Testing)

Once working locally, distribute via TestFlight:

1. **Archive:** Product → Archive
2. **Upload:** to App Store Connect
3. **TestFlight:** Add testers
4. **Share link:** Testers install via TestFlight app

### Troubleshooting

**"Could not launch Dayly"**
- Ensure iPhone is unlocked
- Check USB connection
- Restart Xcode

**"Unable to install"**
- Check bundle ID is unique
- Verify Apple ID has development enabled

**Network errors**
- Verify Mac IP is correct
- Ensure iPhone and Mac on same Wi-Fi
- Check Mac firewall settings

**Blank screen**
- Check Xcode console for errors
- Verify backend is running
- Pull to refresh

---

💡 **Pro Tip:** For quick iterations, use Simulator (no USB needed) but camera won't work.

📱 **Device Testing:** Best for camera, performance, and real feel.

🚀 **TestFlight:** When ready to share with friends!

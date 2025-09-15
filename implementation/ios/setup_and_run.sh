#!/bin/bash

# Dayly iOS Project Setup and Run Script

echo "🚀 Dayly iOS Project Setup"
echo "========================="

# Get the directory where script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/Dayly"

# Step 1: Get Mac's IP address
echo ""
echo "📡 Finding your Mac's IP address..."
MAC_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
if [ -z "$MAC_IP" ]; then
    echo "⚠️  Could not detect IP automatically. Please find manually:"
    echo "   Hold Option → Click WiFi icon → Note your IP"
    read -p "   Enter your Mac's IP address: " MAC_IP
fi
echo "   Your IP: $MAC_IP"

# Step 2: Update NetworkService.swift with the IP
echo ""
echo "📝 Updating NetworkService with your IP..."
NETWORK_FILE="$PROJECT_DIR/Core/Network/NetworkService.swift"
if [ -f "$NETWORK_FILE" ]; then
    # Use sed to update the baseURL
    sed -i '' "s|http://localhost:8000|http://$MAC_IP:8000|g" "$NETWORK_FILE"
    echo "   ✅ NetworkService updated with IP: http://$MAC_IP:8000"
else
    echo "   ⚠️  NetworkService.swift not found"
fi

# Step 3: Open the project
echo ""
echo "🎯 Opening Xcode project..."
open "$PROJECT_DIR/Dayly.xcodeproj"

echo ""
echo "📋 FINAL STEPS IN XCODE:"
echo "========================"
echo ""
echo "1️⃣  Add Swift Packages (File → Add Package Dependencies...):"
echo "   • Supabase: https://github.com/supabase-community/supabase-swift"
echo "   • KeychainAccess: https://github.com/kishikawakatsumi/KeychainAccess"
echo ""
echo "2️⃣  Configure Signing (Click Dayly project → Signing & Capabilities):"
echo "   • Team: Select your Apple ID"
echo "   • Bundle ID will auto-update"
echo ""
echo "3️⃣  Run on your iPhone:"
echo "   • Connect iPhone via USB"
echo "   • Select your iPhone from device dropdown"
echo "   • Press Play (⌘R)"
echo ""
echo "🚀 Backend Server Command:"
echo "   cd $SCRIPT_DIR/backend"
echo "   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "✅ Setup complete! Follow the steps above in Xcode."

#!/bin/bash

# Script to create Xcode project for Dayly app with Core Data

echo "Creating Xcode project for Dayly..."

cd "$(dirname "$0")"

# Create the project using xcodegen or xcodeproj tools if available
if command -v xcodegen &> /dev/null; then
    echo "Using xcodegen to create project..."
    # Create project spec for xcodegen
    cat > project.yml << EOF
name: Dayly
options:
  bundleIdPrefix: com.dayly
  deploymentTarget:
    iOS: 15.0
settings:
  MARKETING_VERSION: 1.0.0
  CURRENT_PROJECT_VERSION: 1
  DEVELOPMENT_TEAM: YOUR_TEAM_ID
targets:
  Dayly:
    type: application
    platform: iOS
    deploymentTarget: 15.0
    sources:
      - Dayly
    resources:
      - Dayly/Resources
      - Dayly/Core/Storage/Dayly.xcdatamodeld
    settings:
      INFOPLIST_FILE: Dayly/App/Info.plist
      PRODUCT_BUNDLE_IDENTIFIER: com.dayly.app
    dependencies:
      - package: Supabase
        product: Supabase
packages:
  Supabase:
    url: https://github.com/supabase-community/supabase-swift.git
    from: 1.0.0
EOF
    xcodegen generate
else
    echo "xcodegen not found. Creating project manually..."
    
    # Use swift package to generate xcodeproj
    cd Dayly
    swift package generate-xcodeproj
    
    echo ""
    echo "⚠️  IMPORTANT: The generated project needs manual configuration:"
    echo "1. Open Dayly.xcodeproj in Xcode"
    echo "2. Add the Dayly.xcdatamodeld to the project:"
    echo "   - Right-click on the Storage folder"
    echo "   - Choose 'Add Files to Dayly...'"
    echo "   - Select Core/Storage/Dayly.xcdatamodeld"
    echo "   - Make sure 'Copy items if needed' is unchecked"
    echo "   - Make sure the target 'Dayly' is checked"
    echo "3. Set the deployment target to iOS 15.0"
    echo "4. Add Supabase package dependency if needed"
fi

echo ""
echo "✅ Core Data model has been created at:"
echo "   Dayly/Core/Storage/Dayly.xcdatamodeld"
echo ""
echo "The model includes these entities:"
echo "   - User (id, phoneNumber, firstName)"
echo "   - Group (id, name, createdAt, lastPhotoDate, hasSentToday)"
echo "   - GroupMember (userId, firstName, joinedAt)"
echo "   - Photo (id, groupId, senderId, senderName, localPath, remoteUrl, createdAt, expiresAt)"

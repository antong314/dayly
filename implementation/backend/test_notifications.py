#!/usr/bin/env python3
"""
Test script for Push Notifications
"""
import asyncio
import httpx

# Test configuration
BASE_URL = "http://localhost:8000"

async def test_register_device(token: str, device_token: str):
    """Test device registration"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BASE_URL}/api/devices/register",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "device_token": device_token,
                "platform": "ios"
            }
        )
        
        print(f"📱 Register Device: {response.status_code}")
        if response.status_code == 200:
            print("✅ Device registered successfully")
        else:
            print(f"❌ Error: {response.text}")
        
        return response.status_code == 200

async def test_get_devices(token: str):
    """Test getting user's registered devices"""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{BASE_URL}/api/devices/",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        print(f"\n📱 Get Devices: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            devices = data.get("devices", [])
            print(f"Found {len(devices)} registered devices")
            for device in devices:
                print(f"  - Token: {device['device_token'][:8]}...")
                print(f"    Platform: {device['platform']}")
                print(f"    Updated: {device.get('updated_at', 'Unknown')}")
        else:
            print(f"Error: {response.text}")

async def test_notification_trigger(token: str, group_id: str):
    """Test that uploading a photo triggers notifications"""
    print(f"\n🔔 Testing Notification Trigger")
    print("Upload a photo to the group and check server logs for:")
    print("  - 'Would send APNS notification to...'")
    print("  - Notification payload details")
    print(f"\nGroup ID: {group_id}")
    print("\nIn production, this would send actual push notifications.")

async def simulate_notification_scenario():
    """Simulate a complete notification scenario"""
    print("\n📱 Notification Flow Simulation:")
    print("1. User A uploads photo to 'Family' group")
    print("2. Backend checks if first photo of the day ✓")
    print("3. Backend gets all group members except sender")
    print("4. Backend fetches device tokens for members")
    print("5. Backend sends push notification:")
    print("   - Title: 'Dayly'")
    print("   - Body: 'Family has new photos'")
    print("   - Thread ID: group_id (for grouping)")
    print("   - Custom data: {group_id, type: 'new_photos'}")
    print("6. iOS receives notification")
    print("7. User taps notification → Opens photo viewer for 'Family'")

async def test_unregister_device(token: str, device_token: str):
    """Test device unregistration"""
    async with httpx.AsyncClient() as client:
        response = await client.delete(
            f"{BASE_URL}/api/devices/unregister?device_token={device_token}",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        print(f"\n🗑️  Unregister Device: {response.status_code}")
        if response.status_code == 200:
            print("✅ Device unregistered successfully")
        else:
            print(f"❌ Error: {response.text}")

async def main():
    """Run notification tests"""
    print("🧪 Testing Push Notification System\n")
    
    # Get test credentials
    print("Please provide test credentials:")
    token = input("Auth token: ").strip()
    
    if not token:
        print("❌ Auth token is required")
        return
    
    # Test device token (64 hex characters)
    # In real app, this comes from iOS
    test_device_token = "a" * 64  # Mock token for testing
    
    print(f"\nUsing mock device token: {test_device_token[:8]}...")
    
    # Run tests
    if await test_register_device(token, test_device_token):
        await test_get_devices(token)
        
        # Get group ID for notification test
        group_id = input("\nGroup ID for notification test (optional): ").strip()
        if group_id:
            await test_notification_trigger(token, group_id)
        
        # Simulate the flow
        await simulate_notification_scenario()
        
        # Optionally unregister
        unregister = input("\nUnregister device? (y/n): ").strip().lower()
        if unregister == 'y':
            await test_unregister_device(token, test_device_token)
    
    print("\n✅ Notification tests complete!")
    print("\nNote: In production, you'll need:")
    print("  - Apple Push Notification Service (APNS) certificates")
    print("  - Real device tokens from iOS devices")
    print("  - APNS library (like aioapns) configured")

if __name__ == "__main__":
    asyncio.run(main())

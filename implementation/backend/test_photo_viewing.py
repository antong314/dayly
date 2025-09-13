#!/usr/bin/env python3
"""
Test script for Photo Viewing API
"""
import httpx
import asyncio
from datetime import datetime

# Test configuration
BASE_URL = "http://localhost:8000"

async def test_get_photos_for_group(token: str, group_id: str):
    """Test getting photos for a specific group"""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{BASE_URL}/api/photos/{group_id}/today",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        print(f"📸 Get Photos for Group: {response.status_code}")
        
        if response.status_code == 200:
            photos = response.json()
            
            # Handle both list and dict response formats
            if isinstance(photos, dict) and 'photos' in photos:
                photos = photos['photos']
            
            print(f"✅ Found {len(photos)} photos")
            
            for idx, photo in enumerate(photos, 1):
                print(f"\n  Photo {idx}:")
                print(f"    ID: {photo.get('id', 'N/A')}")
                print(f"    Sender: {photo.get('sender_name', 'Unknown')}")
                print(f"    Created: {photo.get('created_at', photo.get('timestamp', 'Unknown'))}")
                print(f"    Expires: {photo.get('expires_at', 'N/A')}")
                
                # Check if URL is valid
                url = photo.get('url')
                if url:
                    print(f"    URL: {url[:50]}..." if len(url) > 50 else f"    URL: {url}")
                    
                    # Try to verify the URL is accessible
                    try:
                        head_response = await client.head(url)
                        if head_response.status_code == 200:
                            print("    ✓ URL is accessible")
                        else:
                            print(f"    ✗ URL returned status {head_response.status_code}")
                    except:
                        print("    ✗ Could not verify URL")
                else:
                    print("    ✗ No URL provided")
                    
            return photos
        else:
            print(f"❌ Error: {response.text}")
            return []

async def test_photo_expiry(photos):
    """Check photo expiry times"""
    print("\n⏰ Photo Expiry Status:")
    
    now = datetime.utcnow()
    
    for photo in photos:
        expires_at_str = photo.get('expires_at')
        if expires_at_str:
            try:
                # Parse ISO format datetime
                expires_at = datetime.fromisoformat(expires_at_str.replace('Z', '+00:00'))
                time_remaining = expires_at - now
                
                hours = int(time_remaining.total_seconds() / 3600)
                minutes = int((time_remaining.total_seconds() % 3600) / 60)
                
                sender = photo.get('sender_name', 'Unknown')
                if time_remaining.total_seconds() > 0:
                    print(f"  • Photo from {sender}: expires in {hours}h {minutes}m")
                else:
                    print(f"  • Photo from {sender}: EXPIRED")
            except Exception as e:
                print(f"  • Error parsing expiry for photo: {e}")

async def main():
    """Run photo viewing tests"""
    print("🧪 Testing Photo Viewing API\n")
    
    # Get credentials
    print("Please provide test credentials:")
    token = input("Auth token: ").strip()
    group_id = input("Group ID: ").strip()
    
    if not token or not group_id:
        print("❌ Token and Group ID are required")
        return
    
    # Test getting photos
    photos = await test_get_photos_for_group(token, group_id)
    
    # Test photo expiry
    if photos:
        await test_photo_expiry(photos)
    
    print("\n✅ Photo viewing tests complete!")

if __name__ == "__main__":
    asyncio.run(main())

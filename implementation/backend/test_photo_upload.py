#!/usr/bin/env python3
"""
Test script for Photo Upload API
"""
import httpx
import asyncio
from pathlib import Path
import io
from PIL import Image
import uuid

# Test configuration
BASE_URL = "http://localhost:8000"

async def create_test_image():
    """Create a test image in memory"""
    # Create a simple test image
    img = Image.new('RGB', (100, 100), color='red')
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    img_byte_arr.seek(0)
    return img_byte_arr.getvalue()

async def test_upload_photo(token: str, group_id: str):
    """Test the photo upload endpoint"""
    async with httpx.AsyncClient() as client:
        # Create test image
        image_data = await create_test_image()
        
        # Prepare multipart form data
        files = {
            'file': ('test_photo.jpg', image_data, 'image/jpeg')
        }
        data = {
            'group_id': group_id
        }
        
        # Upload photo
        response = await client.post(
            f"{BASE_URL}/api/photos/upload",
            headers={"Authorization": f"Bearer {token}"},
            files=files,
            data=data
        )
        
        print(f"Upload Photo: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Photo uploaded successfully!")
            print(f"   Photo ID: {result['photo_id']}")
            print(f"   Expires at: {result['expires_at']}")
        else:
            print(f"❌ Upload failed: {response.text}")
        
        return response.status_code == 200

async def test_get_todays_photos(token: str, group_id: str):
    """Test getting today's photos"""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{BASE_URL}/api/photos/{group_id}/today",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        print(f"\n📸 Today's Photos: {response.status_code}")
        if response.status_code == 200:
            photos = response.json()
            if isinstance(photos, dict) and 'photos' in photos:
                photos = photos['photos']
            print(f"Found {len(photos)} photos")
            for photo in photos:
                print(f"  - Photo from {photo.get('sender_name', 'Unknown')}")
                print(f"    ID: {photo['id']}")
                print(f"    Created: {photo.get('timestamp', photo.get('created_at', 'Unknown'))}")
        else:
            print(f"Error: {response.text}")

async def test_duplicate_upload(token: str, group_id: str):
    """Test that duplicate uploads are rejected"""
    async with httpx.AsyncClient() as client:
        # Create test image
        image_data = await create_test_image()
        
        # Try to upload again
        files = {
            'file': ('test_photo2.jpg', image_data, 'image/jpeg')
        }
        data = {
            'group_id': group_id
        }
        
        response = await client.post(
            f"{BASE_URL}/api/photos/upload",
            headers={"Authorization": f"Bearer {token}"},
            files=files,
            data=data
        )
        
        print(f"\n🔄 Duplicate Upload Test: {response.status_code}")
        if response.status_code == 400:
            print("✅ Correctly rejected duplicate upload")
            print(f"   Message: {response.json()['detail']}")
        else:
            print(f"❌ Unexpected response: {response.text}")

async def main():
    """Run all photo upload tests"""
    print("🧪 Testing Photo Upload API\n")
    
    # You'll need to provide these from a previous auth test
    print("Please provide test credentials:")
    token = input("Auth token: ").strip()
    group_id = input("Group ID: ").strip()
    
    if not token or not group_id:
        print("❌ Token and Group ID are required")
        return
    
    # Run tests
    success = await test_upload_photo(token, group_id)
    
    if success:
        # Test getting photos
        await test_get_todays_photos(token, group_id)
        
        # Test duplicate upload rejection
        await test_duplicate_upload(token, group_id)
    
    print("\n✅ Photo upload tests complete!")

if __name__ == "__main__":
    # Install required package if not present
    try:
        from PIL import Image
    except ImportError:
        print("Installing Pillow...")
        import subprocess
        subprocess.check_call(["pip", "install", "Pillow"])
        from PIL import Image
    
    asyncio.run(main())

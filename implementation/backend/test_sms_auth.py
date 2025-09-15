#!/usr/bin/env python3
import requests
import json
import sys

BASE_URL = "http://localhost:8000"

def test_whatsapp_verification():
    print("\n🔐 Dayly Authentication Test (SMS)")
    print("=" * 50)
    
    # Hardcoded phone number for testing
    phone = "+16467338252"
    print(f"\nUsing test phone number: {phone}")
    
    # Optional: Allow override
    custom = input("Press Enter to use this number, or type a different one: ").strip()
    if custom:
        phone = custom
        if not phone.startswith('+'):
            print("❌ Phone number must start with + and country code")
            return
    
    # Step 1: Request verification code
    print(f"\n📱 Sending SMS verification code to {phone}...")
    
    response = requests.post(
        f"{BASE_URL}/api/auth/verify",
        json={"phone_number": phone}
    )
    
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code != 200:
        print("\n❌ Failed to send verification code")
        print("Check that:")
        print("1. Your Twilio SMS service is properly configured")
        print("2. The phone number is valid")
        print("3. Supabase has the correct Twilio credentials")
        return
    
    # Step 2: Enter verification code
    code = input("\n✉️  Enter the 6-digit code from SMS: ")
    
    # Optional: Get first name
    first_name = input("Enter your first name (optional, press Enter to skip): ")
    
    # Step 3: Verify code
    print(f"\n🔓 Verifying code...")
    
    verify_data = {
        "phone_number": phone,
        "code": code
    }
    if first_name:
        verify_data["first_name"] = first_name
    
    response = requests.post(
        f"{BASE_URL}/api/auth/verify/confirm",
        json=verify_data
    )
    
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        print("\n✅ Authentication successful!")
        data = response.json()
        print(f"User ID: {data['user']['id']}")
        print(f"Access Token: {data['access_token'][:20]}...")
    else:
        print("\n❌ Authentication failed")

if __name__ == "__main__":
    try:
        test_whatsapp_verification()
    except KeyboardInterrupt:
        print("\n\nTest cancelled")
    except Exception as e:
        print(f"\n❌ Error: {e}")

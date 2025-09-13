#!/usr/bin/env python3
"""
Direct Supabase Phone Auth Test
This tests phone auth directly with Supabase API
"""

import requests
import json

# Your Supabase credentials
SUPABASE_URL = "https://your-project.supabase.co"  # Replace with your Supabase URL
ANON_KEY = "your-anon-key-here"  # Replace with your Supabase anon key

def test_send_otp(phone_number):
    """Send OTP directly to Supabase"""
    url = f"{SUPABASE_URL}/auth/v1/otp"
    headers = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json"
    }
    data = {
        "phone": phone_number
    }
    
    print(f"Sending OTP to {phone_number}...")
    response = requests.post(url, headers=headers, json=data)
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        print("\n✅ Success! Check your phone for the OTP code.")
        print("You should receive an SMS with your verification code.")
    else:
        print("\n❌ Failed to send OTP")
    
    return response.status_code == 200

def test_verify_otp(phone_number, otp_code):
    """Verify OTP with Supabase"""
    url = f"{SUPABASE_URL}/auth/v1/verify"
    headers = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json"
    }
    data = {
        "phone": phone_number,
        "token": otp_code,
        "type": "sms"
    }
    
    print(f"\nVerifying OTP {otp_code} for {phone_number}...")
    response = requests.post(url, headers=headers, json=data)
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        print("\n✅ Success! Phone number verified.")
        data = response.json()
        if 'access_token' in data:
            print(f"Access Token: {data['access_token'][:50]}...")
        if 'user' in data:
            print(f"User ID: {data['user']['id']}")
    else:
        print("\n❌ Failed to verify OTP")
    
    return response.status_code == 200

if __name__ == "__main__":
    print("Supabase Direct Phone Authentication Test")
    print("=" * 50)
    
    # Test configuration
    print(f"Supabase URL: {SUPABASE_URL}")
    print(f"Using Anon Key: {ANON_KEY[:50]}...")
    
    while True:
        print("\n\nOptions:")
        print("1. Send OTP to phone number")
        print("2. Verify OTP code")
        print("3. Exit")
        
        choice = input("\nEnter your choice (1-3): ")
        
        if choice == "1":
            phone = input("Enter phone number (with country code, e.g., +1234567890): ")
            if phone.startswith("+"):
                test_send_otp(phone)
            else:
                print("❌ Phone number must start with + and include country code")
                
        elif choice == "2":
            phone = input("Enter phone number: ")
            code = input("Enter 6-digit OTP code: ")
            if phone.startswith("+") and len(code) == 6 and code.isdigit():
                test_verify_otp(phone, code)
            else:
                print("❌ Invalid phone number or OTP format")
                
        elif choice == "3":
            print("Exiting...")
            break
        else:
            print("Invalid choice. Please try again.")
    
    print("\nNote: If SMS sending fails, check:")
    print("1. Twilio is properly configured in Supabase")
    print("2. Phone auth is enabled in Supabase")
    print("3. The phone number is valid and can receive SMS")
    print("4. Check Supabase Logs → Auth Logs for details")

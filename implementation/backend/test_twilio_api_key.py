#!/usr/bin/env python3
"""
Test Twilio with API Key instead of Auth Token
"""

from twilio.rest import Client
import sys

# Your main account SID (same as before)
ACCOUNT_SID = "AC..."  # Replace with your Account SID

# API Key credentials (you'll need to fill these)
API_KEY_SID = "SK..."  # Starts with SK
API_KEY_SECRET = "your-api-key-secret"

if API_KEY_SID == "SK...":
    print("Please edit this file and add your API Key SID and Secret")
    print("\nTo create an API Key:")
    print("1. Go to Twilio Console → Account → API keys & tokens")
    print("2. Click 'Create API Key'")
    print("3. Copy the SID (starts with SK) and Secret")
    sys.exit(1)

print(f"Testing with API Key...")
print(f"Account SID: {ACCOUNT_SID}")
print(f"API Key SID: {API_KEY_SID}")

try:
    # Use API Key instead of Auth Token
    client = Client(API_KEY_SID, API_KEY_SECRET, ACCOUNT_SID)
    
    # Test account access
    account = client.api.accounts(ACCOUNT_SID).fetch()
    print(f"\n✅ Success! Connected to Twilio")
    print(f"Account Name: {account.friendly_name}")
    print(f"Account Status: {account.status}")
    print(f"Account Type: {account.type}")
    
    # Test messaging service
    print(f"\nTesting Messaging Service...")
    service = client.messaging.services("MG48114f29890bf47311506150def68d4c").fetch()
    print(f"✅ Messaging Service: {service.friendly_name}")
    
except Exception as e:
    print(f"\n❌ Error: {e}")

print("\nIf this works, we'll need to update Supabase to use API Keys somehow.")

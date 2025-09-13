#!/usr/bin/env python3
"""
Direct Twilio Test - Tests if Twilio credentials are working
"""

from twilio.rest import Client
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# You'll need to add these to your .env file
TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', 'your-account-sid')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', 'your-auth-token')
TWILIO_MESSAGING_SERVICE_SID = os.getenv('TWILIO_MESSAGING_SERVICE_SID', 'your-messaging-service-sid')

def test_twilio_connection():
    """Test if we can connect to Twilio"""
    try:
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        
        # Try to fetch account details
        account = client.api.accounts(TWILIO_ACCOUNT_SID).fetch()
        print(f"✅ Connected to Twilio!")
        print(f"Account Name: {account.friendly_name}")
        print(f"Account Status: {account.status}")
        print(f"Account Type: {account.type}")
        
        # Check messaging service
        try:
            service = client.messaging.services(TWILIO_MESSAGING_SERVICE_SID).fetch()
            print(f"\n✅ Messaging Service Found!")
            print(f"Service Name: {service.friendly_name}")
            print(f"Service SID: {service.sid}")
        except Exception as e:
            print(f"\n❌ Error fetching messaging service: {e}")
        
        return True
    except Exception as e:
        print(f"❌ Failed to connect to Twilio: {e}")
        return False

def send_test_sms(to_number):
    """Send a test SMS"""
    try:
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        
        message = client.messages.create(
            messaging_service_sid=TWILIO_MESSAGING_SERVICE_SID,
            to=to_number,
            body="Test message from Dayly app setup"
        )
        
        print(f"\n✅ SMS sent successfully!")
        print(f"Message SID: {message.sid}")
        print(f"Status: {message.status}")
        return True
    except Exception as e:
        print(f"\n❌ Failed to send SMS: {e}")
        return False

if __name__ == "__main__":
    print("Twilio Direct Test")
    print("=" * 50)
    
    print("\nNote: Add these to your .env file:")
    print("TWILIO_ACCOUNT_SID=your-account-sid")
    print("TWILIO_AUTH_TOKEN=your-auth-token")
    print("TWILIO_MESSAGING_SERVICE_SID=your-messaging-service-sid")
    
    if TWILIO_ACCOUNT_SID == 'your-account-sid':
        print("\n❌ Please configure your Twilio credentials in .env file first!")
        exit(1)
    
    print(f"\nUsing Account SID: {TWILIO_ACCOUNT_SID}")
    print(f"Using Messaging Service: {TWILIO_MESSAGING_SERVICE_SID}")
    
    # Test connection
    if test_twilio_connection():
        choice = input("\nDo you want to send a test SMS? (y/n): ")
        if choice.lower() == 'y':
            phone = input("Enter phone number (with country code, e.g., +1234567890): ")
            if phone.startswith("+"):
                send_test_sms(phone)
            else:
                print("❌ Phone number must start with + and include country code")
    
    print("\n" + "=" * 50)
    print("If this test works but Supabase doesn't, check:")
    print("1. The exact same credentials are in Supabase")
    print("2. No extra spaces or characters in Supabase fields")
    print("3. The Messaging Service SID (not just phone number) is configured")

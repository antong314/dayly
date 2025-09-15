#!/usr/bin/env python3
"""
Direct WhatsApp test using Twilio API
This bypasses Supabase to test if WhatsApp messaging works
"""
import os
from twilio.rest import Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv('env.local')

# Get credentials from environment
ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', 'your_account_sid')
AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', 'your_auth_token')
MESSAGING_SERVICE_SID = os.getenv('TWILIO_MESSAGING_SERVICE_SID', 'MG48114f29890bf47311506150def68d4c')

def test_whatsapp_direct():
    print("\n🔧 Direct Twilio WhatsApp Test")
    print("=" * 50)
    
    # Get credentials
    if ACCOUNT_SID == 'your_account_sid':
        print("\n⚠️  Please set your Twilio credentials:")
        print("export TWILIO_ACCOUNT_SID='your_actual_sid'")
        print("export TWILIO_AUTH_TOKEN='your_actual_token'")
        return
    
    client = Client(ACCOUNT_SID, AUTH_TOKEN)
    
    phone = "+16467338252"
    print(f"\n📱 Sending WhatsApp message to {phone}")
    
    try:
        # For WhatsApp, we need to use a template for the initial message
        # This uses Twilio's default verification template
        message = client.messages.create(
            # Using Twilio's default OTP template
            body='Your verification code is: 123456',
            messaging_service_sid=MESSAGING_SERVICE_SID,
            to=f'whatsapp:{phone}',  # WhatsApp format
            # Use a content template instead of freeform text
            content_sid='HX229f5a04fd0510ce1b071852155d3e92'  # Twilio's default OTP template
        )
        
        print(f"✅ Message sent successfully!")
        print(f"Message SID: {message.sid}")
        print(f"Status: {message.status}")
        print(f"Direction: {message.direction}")
        print(f"From: {message.from_}")
        
    except Exception as e:
        print(f"❌ Failed to send WhatsApp message: {e}")
        print("\nTroubleshooting:")
        print("1. Make sure your WhatsApp sender is approved")
        print("2. Verify the phone number has WhatsApp")
        print("3. Check if the messaging service has WhatsApp sender added")

if __name__ == "__main__":
    test_whatsapp_direct()

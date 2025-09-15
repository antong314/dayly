#!/usr/bin/env python3
"""
WhatsApp OTP test using Twilio Verify Service
This uses Twilio's Verify API which handles templates automatically
"""
import os
from twilio.rest import Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv('env.local')

# Get credentials from environment
ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID')
AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN')

def test_whatsapp_verify():
    print("\n🔐 Twilio Verify WhatsApp Test")
    print("=" * 50)
    
    client = Client(ACCOUNT_SID, AUTH_TOKEN)
    
    # Use the configured Verify Service
    verify_service_sid = os.getenv('TWILIO_VERIFY_SERVICE_SID', 'VA9061b6acc77a9ed1c6a06aa937da6ad7')
    print(f"\n✅ Using Verify Service: {verify_service_sid}")
    
    try:
        phone = "+16467338252"
        print(f"\n📱 Sending WhatsApp verification to {phone}...")
        
        # Send verification
        verification = client.verify.v2 \
            .services(verify_service_sid) \
            .verifications \
            .create(
                to=phone,  # Just the phone number, no prefix
                channel='whatsapp'
            )
        
        print(f"✅ Verification sent successfully!")
        print(f"   Status: {verification.status}")
        print(f"   Channel: {verification.channel}")
        
        # Wait for user to enter code
        code = input("\n📱 Enter the verification code you received: ")
        
        # Check verification
        print(f"\n4️⃣ Checking code: {code}")
        
        verification_check = client.verify.v2 \
            .services(verify_service_sid) \
            .verification_checks \
            .create(
                to=phone,  # Just the phone number, no prefix
                code=code
            )
        
        if verification_check.status == 'approved':
            print("\n✅ Verification successful! Code is valid.")
        else:
            print(f"\n❌ Verification failed. Status: {verification_check.status}")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nNote: Twilio Verify automatically uses pre-approved WhatsApp templates")
        print("for OTP messages, which avoids the 24-hour window restriction.")

if __name__ == "__main__":
    test_whatsapp_verify()

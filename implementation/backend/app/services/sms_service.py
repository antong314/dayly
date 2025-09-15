from app.core.config import settings
import os

# Initialize Twilio client if credentials are available
twilio_client = None

# Try to import Twilio, but don't fail if not installed
try:
    from twilio.rest import Client
    
    # Get credentials from environment or settings
    TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", getattr(settings, "TWILIO_ACCOUNT_SID", None))
    TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", getattr(settings, "TWILIO_AUTH_TOKEN", None))
    TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER", getattr(settings, "TWILIO_PHONE_NUMBER", None))
    
    if TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN:
        twilio_client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        print("✅ Twilio client initialized")
    else:
        print("⚠️  Twilio credentials not found - SMS sending disabled")
except ImportError:
    print("⚠️  Twilio not installed - SMS sending disabled")
    print("    Install with: pip install twilio")

async def send_invite_sms(phone_number: str, message: str):
    """Send SMS via Twilio"""
    if not twilio_client:
        # In development, just log the message
        print(f"\n📱 SMS to {phone_number}:")
        print(f"   {message}")
        print("   (Twilio not configured - SMS not sent)\n")
        return None
    
    if not TWILIO_PHONE_NUMBER:
        print(f"❌ TWILIO_PHONE_NUMBER not configured")
        return None
    
    try:
        # Send via Twilio
        message_response = twilio_client.messages.create(
            body=message,
            from_=TWILIO_PHONE_NUMBER,
            to=phone_number
        )
        
        print(f"✅ SMS sent to {phone_number} - SID: {message_response.sid}")
        return message_response.sid
        
    except Exception as e:
        print(f"❌ Failed to send SMS to {phone_number}: {str(e)}")
        raise Exception(f"Failed to send SMS: {str(e)}")

async def send_verification_code(phone_number: str, code: str):
    """Send verification code SMS"""
    message = f"Your Dayly verification code is: {code}\n\nThis code expires in 10 minutes."
    return await send_invite_sms(phone_number, message)

async def send_welcome_message(phone_number: str, first_name: str):
    """Send welcome SMS to new user"""
    message = (
        f"Welcome to Dayly, {first_name}! 📸\n\n"
        f"Share one meaningful photo per day with the people who matter most.\n\n"
        f"Create your first group to get started!"
    )
    return await send_invite_sms(phone_number, message)
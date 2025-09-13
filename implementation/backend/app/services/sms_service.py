from twilio.rest import Client
from typing import Optional
import random
import string
from app.core.config import get_settings

class SMSService:
    def __init__(self):
        # Twilio configuration will be added in Phase 1
        self.client = None
        
    def generate_otp(self, length: int = 6) -> str:
        """Generate a random OTP code"""
        return ''.join(random.choices(string.digits, k=length))
    
    async def send_otp(self, phone_number: str, otp_code: str) -> bool:
        """Send OTP via SMS"""
        # To be implemented in Phase 1
        print(f"Would send OTP {otp_code} to {phone_number}")
        return True
    
    async def send_invite(self, phone_number: str, invite_code: str, group_name: str, inviter_name: str) -> bool:
        """Send group invite via SMS"""
        # To be implemented in Phase 8
        message = f"{inviter_name} invited you to join '{group_name}' on Dayly. Use code: {invite_code}"
        print(f"Would send invite to {phone_number}: {message}")
        return True

# Singleton instance
sms_service = SMSService()
